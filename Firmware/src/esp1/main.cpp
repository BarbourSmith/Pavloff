#include <Arduino.h>
#include <Wire.h>
#include "I2Cdev.h"
#include "MPU6050.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <esp_pm.h>
#include <esp_sleep.h>
#include <esp_wifi.h>
#include <Preferences.h>

// Pin configuration - defined via PlatformIO build flags
#ifndef SDA_PIN
#error "SDA_PIN must be defined in platformio.ini build_flags"
#endif
#ifndef SCL_PIN
#error "SCL_PIN must be defined in platformio.ini build_flags"
#endif

// Power management constants
#define IDLE_TIMEOUT_MS 20000  // 20 seconds in milliseconds (for testing)
#define CALIBRATION_STILLNESS_MS 240000  // 4 minutes in milliseconds
#define POLL_INTERVAL_SECONDS 2  // Wake up every 2 seconds to check for motion

// Power optimization settings
void configurePowerOptimizations() {
  // Reduce CPU frequency to save power (80 MHz is sufficient for this application)
  // ESP32-S3 supports 240MHz, 160MHz, 80MHz, 40MHz, 20MHz, 10MHz
  setCpuFrequencyMhz(80);
  Serial.print("CPU frequency set to: ");
  Serial.print(getCpuFrequencyMhz());
  Serial.println(" MHz");
  
  // Enable automatic light sleep when idle
  // This allows the CPU to enter light sleep between tasks
  esp_pm_config_esp32s3_t pm_config;
  pm_config.max_freq_mhz = 80;
  pm_config.min_freq_mhz = 10;
  pm_config.light_sleep_enable = true;
  esp_pm_configure(&pm_config);
  
  Serial.println("Power optimizations configured");
}

// Create an MPU6050 object
MPU6050 mpu;

// Conversion factors for MPU6050 raw values
// Accelerometer: ±2g range -> 16384 LSB/g
// Gyroscope: ±500°/s range -> 65.5 LSB/(°/s)
#define ACCEL_SCALE (1.0f / 16384.0f)  // Convert to g's
#define GYRO_SCALE (1.0f / 65.5f)      // Convert to degrees/s

// Gyroscope offset values (in degrees/s) for software calibration
float gyroXoffset = 0.0f;
float gyroYoffset = 0.0f;
float gyroZoffset = 0.0f;

// Preferences object for storing calibration data
Preferences preferences;

// BLE Server and Characteristic pointers
BLEServer* pServer = NULL;
BLECharacteristic* pAccelCharacteristic = NULL;
BLECharacteristic* pGyroCharacteristic = NULL;
BLECharacteristic* pRepCharacteristic = NULL;
bool deviceConnected = false;

// Position and velocity tracking variables
float velocityX = 0.0, velocityY = 0.0, velocityZ = 0.0;
float positionX = 0.0, positionY = 0.0, positionZ = 0.0;
unsigned long lastUpdateTime = 0;
unsigned long lastReportTime = 0;
bool firstIteration = true;

// Low-pass filter state variables for accelerometer
float filteredAccelX = 0.0f;
float filteredAccelY = 0.0f;
float filteredAccelZ = 0.0f;

// Mahony AHRS algorithm variables
float q0 = 1.0f, q1 = 0.0f, q2 = 0.0f, q3 = 0.0f;  // Quaternion elements (w, x, y, z)
float integralFBx = 0.0f, integralFBy = 0.0f, integralFBz = 0.0f;  // Integral error for AHRS

// Rep detection state machine
enum RepState {
  REP_IDLE,           // No motion detected
  REP_MOVING_UP,      // Detected upward motion
  REP_MOVING_DOWN,    // Detected downward motion
  REP_TRANSITION      // Brief transition state
};

RepState repState = REP_IDLE;
int repCount = 0;
unsigned long lastMotionTime = 0;
unsigned long phaseStartTime = 0;
float dominantAxisVelocity = 0.0f;  // Velocity along dominant motion axis

// Power management variables
unsigned long lastActivityTime = 0;  // Track last time there was activity
unsigned long lastStillTime = 0;     // Track when device became stationary
bool wasStationary = false;          // Track if device was stationary in previous iteration
bool calibrationComplete = false;    // Track if calibration has been done

// Timing constants
#define INTEGRATION_INTERVAL_MS 10  // Calculate position every 10ms for accuracy
#define REPORT_INTERVAL_MS 500       // Report data every 500ms

// AHRS algorithm gains
#define MAHONY_KP 1.0f               // Proportional gain
#define MAHONY_KI 0.0f               // Integral gain

// Drift correction constants (for real-time processing)
#define VELOCITY_DAMPING 0.95f       // Damping factor for velocity (reduces drift)
#define POSITION_DAMPING 0.99f       // Damping factor for position (pulls toward zero)
#define VELOCITY_THRESHOLD 0.01f     // Velocity threshold to zero out noise (m/s)

// Low-pass filter for accelerometer data
#define ACCEL_FILTER_ALPHA 0.2f      // Filter coefficient (0.0-1.0, lower = more filtering)
#define ACCEL_MAX_G 2.0f             // Maximum acceleration clamp (in g's)

// Stationary detection thresholds
#define ACCEL_STATIONARY_THRESHOLD 0.1f   // Acceleration deviation threshold (g's) for stationary detection
#define GYRO_STATIONARY_THRESHOLD 0.1f    // Gyroscope threshold (rad/s) for stationary detection

// Rep detection parameters
#define REP_ACCEL_THRESHOLD 0.3f          // Minimum acceleration magnitude (g's) to consider active motion
#define REP_VELOCITY_THRESHOLD 0.20f      // Minimum velocity magnitude (m/s) to consider moving
#define REP_MIN_DURATION_MS 500           // Minimum duration for each phase (up/down) in milliseconds
#define REP_REST_TIMEOUT_MS 3000          // Time to reset rep counting if no motion detected

// See the following for generating new UUIDs:
// https://www.uuidgenerator.net/
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define ACCEL_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define GYRO_CHARACTERISTIC_UUID  "1c95d5e2-0a25-4233-8d6c-613d161c210a"
#define REP_CHARACTERISTIC_UUID   "8d3f7a9e-4b2c-11ef-9f27-0242ac120002"

// Handles BLE connection and disconnection events
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      lastActivityTime = millis();  // Reset activity timer on connection
      Serial.println("Device connected");
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      lastActivityTime = millis();  // Reset activity timer on disconnection
      Serial.println("Device disconnected");
      // Restart advertising so a new client can connect
      pServer->getAdvertising()->start();
    }
};

// Handles write events to the rep characteristic
class RepCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        Serial.print("Received command: ");
        Serial.println(value.c_str());
        
        // Reset activity timer on any BLE interaction
        lastActivityTime = millis();
        
        // Check for reset command
        if (value == "RESET" || value == "reset") {
          repCount = 0;
          repState = REP_IDLE;
          phaseStartTime = millis();
          Serial.println("Rep count reset to 0");
          
          // Send immediate update with new count
          char repData[30];
          snprintf(repData, sizeof(repData), "Count:0,State:IDLE");
          pCharacteristic->setValue(repData);
          pCharacteristic->notify();
        }
      }
    }
};

// Fast inverse square root for quaternion normalization
float invSqrt(float x) {
  float halfx = 0.5f * x;
  float y = x;
  long i = *(long*)&y;
  i = 0x5f3759df - (i>>1);
  y = *(float*)&i;
  y = y * (1.5f - (halfx * y * y));
  return y;
}

// Save gyro calibration offsets to persistent storage
void saveGyroOffsets(float offsetX, float offsetY, float offsetZ) {
  preferences.begin("mpu6050", false);  // Open in read-write mode
  preferences.putFloat("gyroOffsetX", offsetX);
  preferences.putFloat("gyroOffsetY", offsetY);
  preferences.putFloat("gyroOffsetZ", offsetZ);
  preferences.putBool("hasOffsets", true);
  preferences.end();
  Serial.println("Gyro offsets saved to persistent storage");
  Serial.print("Offsets: X=");
  Serial.print(offsetX, 4);
  Serial.print(", Y=");
  Serial.print(offsetY, 4);
  Serial.print(", Z=");
  Serial.println(offsetZ, 4);
}

// Load gyro calibration offsets from persistent storage
bool loadGyroOffsets(float* offsetX, float* offsetY, float* offsetZ) {
  preferences.begin("mpu6050", true);  // Open in read-only mode
  bool hasOffsets = preferences.getBool("hasOffsets", false);
  
  if (hasOffsets) {
    *offsetX = preferences.getFloat("gyroOffsetX", 0.0f);
    *offsetY = preferences.getFloat("gyroOffsetY", 0.0f);
    *offsetZ = preferences.getFloat("gyroOffsetZ", 0.0f);
    preferences.end();
    Serial.println("Loaded gyro offsets from persistent storage");
    Serial.print("Offsets: X=");
    Serial.print(*offsetX, 4);
    Serial.print(", Y=");
    Serial.print(*offsetY, 4);
    Serial.print(", Z=");
    Serial.println(*offsetZ, 4);
    return true;
  }
  
  preferences.end();
  Serial.println("No stored gyro offsets found");
  return false;
}

// Perform gyro calibration and save results (matches tockn library behavior)
void performCalibration() {
  Serial.println();
  Serial.println("========================================");
  Serial.println("Starting gyroscope calibration...");
  Serial.println("DO NOT MOVE MPU6050");
  
  // Calculate gyro offsets by averaging readings (same as tockn library: 3000 samples)
  float x = 0.0f, y = 0.0f, z = 0.0f;
  int16_t rx, ry, rz;
  
  delay(1000);  // Wait for device to settle
  
  for (int i = 0; i < 3000; i++) {
    if (i % 1000 == 0) {
      Serial.print(".");
    }
    mpu.getRotation(&rx, &ry, &rz);
    
    // Convert to degrees/s and accumulate (matching tockn library)
    x += ((float)rx) * GYRO_SCALE;
    y += ((float)ry) * GYRO_SCALE;
    z += ((float)rz) * GYRO_SCALE;
  }
  
  // Calculate average offsets (in degrees/s)
  gyroXoffset = x / 3000.0f;
  gyroYoffset = y / 3000.0f;
  gyroZoffset = z / 3000.0f;
  
  Serial.println();
  Serial.println("Done!");
  Serial.print("X : "); Serial.println(gyroXoffset);
  Serial.print("Y : "); Serial.println(gyroYoffset);
  Serial.print("Z : "); Serial.println(gyroZoffset);
  
  saveGyroOffsets(gyroXoffset, gyroYoffset, gyroZoffset);
  calibrationComplete = true;
  
  Serial.println("Program will start after 3 seconds");
  Serial.println("========================================");
  delay(3000);
}

// Mahony AHRS algorithm update (IMU version without magnetometer)
void MahonyAHRSupdateIMU(float gx, float gy, float gz, float ax, float ay, float az, float dt) {
  float recipNorm;
  float halfvx, halfvy, halfvz;
  float halfex, halfey, halfez;
  float qa, qb, qc;

  // Compute feedback only if accelerometer measurement valid (avoids NaN in accelerometer normalisation)
  if(!((ax == 0.0f) && (ay == 0.0f) && (az == 0.0f))) {
    // Normalise accelerometer measurement
    recipNorm = invSqrt(ax * ax + ay * ay + az * az);
    ax *= recipNorm;
    ay *= recipNorm;
    az *= recipNorm;

    // Estimated direction of gravity
    halfvx = q1 * q3 - q0 * q2;
    halfvy = q0 * q1 + q2 * q3;
    halfvz = q0 * q0 - 0.5f + q3 * q3;

    // Error is cross product between estimated and measured direction of gravity
    halfex = (ay * halfvz - az * halfvy);
    halfey = (az * halfvx - ax * halfvz);
    halfez = (ax * halfvy - ay * halfvx);

    // Compute and apply integral feedback if enabled
    if(MAHONY_KI > 0.0f) {
      integralFBx += MAHONY_KI * halfex * dt;
      integralFBy += MAHONY_KI * halfey * dt;
      integralFBz += MAHONY_KI * halfez * dt;
      gx += integralFBx;
      gy += integralFBy;
      gz += integralFBz;
    } else {
      integralFBx = 0.0f;
      integralFBy = 0.0f;
      integralFBz = 0.0f;
    }

    // Apply proportional feedback
    gx += MAHONY_KP * halfex;
    gy += MAHONY_KP * halfey;
    gz += MAHONY_KP * halfez;
  }

  // Integrate rate of change of quaternion
  gx *= (0.5f * dt);
  gy *= (0.5f * dt);
  gz *= (0.5f * dt);
  qa = q0;
  qb = q1;
  qc = q2;
  q0 += (-qb * gx - qc * gy - q3 * gz);
  q1 += (qa * gx + qc * gz - q3 * gy);
  q2 += (qa * gy - qb * gz + q3 * gx);
  q3 += (qa * gz + qb * gy - qc * gx);

  // Normalise quaternion
  recipNorm = invSqrt(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3);
  q0 *= recipNorm;
  q1 *= recipNorm;
  q2 *= recipNorm;
  q3 *= recipNorm;
}

// Rotate vector by quaternion (sensor frame to Earth frame)
void rotateVector(float vx, float vy, float vz, float* rx, float* ry, float* rz) {
  // Compute rotation matrix elements from quaternion
  float r11 = q0*q0 + q1*q1 - q2*q2 - q3*q3;
  float r12 = 2*(q1*q2 - q0*q3);
  float r13 = 2*(q1*q3 + q0*q2);
  float r21 = 2*(q1*q2 + q0*q3);
  float r22 = q0*q0 - q1*q1 + q2*q2 - q3*q3;
  float r23 = 2*(q2*q3 - q0*q1);
  float r31 = 2*(q1*q3 - q0*q2);
  float r32 = 2*(q2*q3 + q0*q1);
  float r33 = q0*q0 - q1*q1 - q2*q2 + q3*q3;
  
  // Apply rotation
  *rx = r11*vx + r12*vy + r13*vz;
  *ry = r21*vx + r22*vy + r23*vz;
  *rz = r31*vx + r32*vy + r33*vz;
}

// Apply low-pass filter to accelerometer data and clamp to max value
void filterAndClampAccel(float rawX, float rawY, float rawZ, float* outX, float* outY, float* outZ) {
  // Clamp raw values to ±2G
  rawX = constrain(rawX, -ACCEL_MAX_G, ACCEL_MAX_G);
  rawY = constrain(rawY, -ACCEL_MAX_G, ACCEL_MAX_G);
  rawZ = constrain(rawZ, -ACCEL_MAX_G, ACCEL_MAX_G);
  
  // Apply exponential moving average (low-pass filter)
  filteredAccelX = ACCEL_FILTER_ALPHA * rawX + (1.0f - ACCEL_FILTER_ALPHA) * filteredAccelX;
  filteredAccelY = ACCEL_FILTER_ALPHA * rawY + (1.0f - ACCEL_FILTER_ALPHA) * filteredAccelY;
  filteredAccelZ = ACCEL_FILTER_ALPHA * rawZ + (1.0f - ACCEL_FILTER_ALPHA) * filteredAccelZ;
  
  *outX = filteredAccelX;
  *outY = filteredAccelY;
  *outZ = filteredAccelZ;
}

// Rep detection using velocity magnitude and direction changes
void detectRep(float velX, float velY, float velZ, float linearAccelMag, unsigned long currentTime) {
  // Calculate total velocity magnitude
  float velocityMag = sqrt(velX*velX + velY*velY + velZ*velZ);
  
  // Find dominant motion axis (axis with highest velocity magnitude)
  float absVelX = abs(velX);
  float absVelY = abs(velY);
  float absVelZ = abs(velZ);
  
  if (absVelX >= absVelY && absVelX >= absVelZ) {
    dominantAxisVelocity = velX;
  } else if (absVelY >= absVelX && absVelY >= absVelZ) {
    dominantAxisVelocity = velY;
  } else {
    dominantAxisVelocity = velZ;
  }
  
  // Check if there's significant motion
  bool isMoving = (velocityMag > REP_VELOCITY_THRESHOLD) && (linearAccelMag > REP_ACCEL_THRESHOLD);
  
  // Reset if no motion detected for too long
  if (!isMoving && (currentTime - lastMotionTime > REP_REST_TIMEOUT_MS)) {
    if (repState != REP_IDLE) {
      Serial.println("REP: Reset - No motion timeout");
      repState = REP_IDLE;
      phaseStartTime = currentTime;
    }
    return;
  }
  
  // Update last motion time if moving
  if (isMoving) {
    lastMotionTime = currentTime;
  }
  
  // State machine for rep detection
  unsigned long phaseDuration = currentTime - phaseStartTime;
  
  switch (repState) {
    case REP_IDLE:
      // Wait for initial motion to start tracking
      if (isMoving && velocityMag > REP_VELOCITY_THRESHOLD * 1.5f) {
        // Determine initial direction based on dominant axis
        if (dominantAxisVelocity > 0) {
          repState = REP_MOVING_UP;
          Serial.println("REP: Started - Moving UP");
        } else {
          repState = REP_MOVING_DOWN;
          Serial.println("REP: Started - Moving DOWN");
        }
        phaseStartTime = currentTime;
      }
      break;
      
    case REP_MOVING_UP:
      // Check for direction change to downward motion
      if (isMoving && dominantAxisVelocity < -REP_VELOCITY_THRESHOLD * 1.2f && phaseDuration > REP_MIN_DURATION_MS) {
        repState = REP_MOVING_DOWN;
        repCount++;
        phaseStartTime = currentTime;
        Serial.print("REP: Direction change UP->DOWN | Total Reps: ");
        Serial.println(repCount);
      }
      break;
      
    case REP_MOVING_DOWN:
      // Check for direction change to upward motion
      if (isMoving && dominantAxisVelocity > REP_VELOCITY_THRESHOLD * 1.2f && phaseDuration > REP_MIN_DURATION_MS) {
        repState = REP_MOVING_UP;
        phaseStartTime = currentTime;
        Serial.print("REP: Direction change DOWN->UP | Total Reps: ");
        Serial.println(repCount);
      }
      break;
      
    case REP_TRANSITION:
      // Not used in current implementation
      break;
  }
}

// Check if MPU-6050 detects motion by reading accelerometer
bool checkForMotion() {
  // Read accelerometer values
  int16_t ax, ay, az;
  mpu.getAcceleration(&ax, &ay, &az);
  
  // Convert to g's
  float accelX = ax * ACCEL_SCALE;
  float accelY = ay * ACCEL_SCALE;
  float accelZ = az * ACCEL_SCALE;
  
  // Calculate acceleration magnitude
  float accelMag = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ);
  
  // Check if deviation from 1g (gravity) exceeds threshold
  // Motion threshold: 0.15g deviation from rest
  bool motionDetected = abs(accelMag - 1.0f) > 0.15f;
  
  Serial.print("Motion check - Accel magnitude: ");
  Serial.print(accelMag, 3);
  Serial.print("g, Motion: ");
  Serial.println(motionDetected ? "YES" : "NO");
  
  return motionDetected;
}

// Put MPU-6050 into low power mode for sleep
void putMPUToSleep() {
  Serial.println("Preparing MPU-6050 for sleep mode...");
  
  // Step 1: Keep device awake but disable temp sensor for power savings
  mpu.setSleepEnabled(false);
  mpu.setWakeCycleEnabled(false);
  mpu.setTempSensorEnabled(false);
  Serial.println("  - Set to normal mode with temp disabled");
  
  // Step 2: Disable gyroscope to save power, keep accelerometer enabled for motion check
  mpu.setStandbyXGyroEnabled(true);
  mpu.setStandbyYGyroEnabled(true);
  mpu.setStandbyZGyroEnabled(true);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  Serial.println("  - Disabled gyroscope, kept accelerometer enabled");
  
  // Wait for power mode changes to fully settle
  delay(100);
  Serial.println("  - Sensor stabilized after power changes");
  
  Serial.println("MPU-6050 ready for low power operation (accel only)");
}

// Reset all state variables to prepare for motion tracking
void resetStateVariables() {
  // Reset velocity and position tracking
  velocityX = 0.0f;
  velocityY = 0.0f;
  velocityZ = 0.0f;
  positionX = 0.0f;
  positionY = 0.0f;
  positionZ = 0.0f;
  
  // Reset filter states
  filteredAccelX = 0.0f;
  filteredAccelY = 0.0f;
  filteredAccelZ = 0.0f;
  
  // Reset AHRS quaternion to identity (no rotation)
  q0 = 1.0f;
  q1 = 0.0f;
  q2 = 0.0f;
  q3 = 0.0f;
  integralFBx = 0.0f;
  integralFBy = 0.0f;
  integralFBz = 0.0f;
  
  // Reset rep detection state
  repState = REP_IDLE;
  repCount = 0;  // Explicitly reset rep count (deep sleep causes full device reset)
  // Note: To preserve rep count across sleep, it would need to be stored in persistent storage
  lastMotionTime = millis();
  phaseStartTime = millis();
  dominantAxisVelocity = 0.0f;
  
  // Reset timing variables
  lastUpdateTime = millis();
  lastReportTime = millis();
  firstIteration = true;
  
  // Reset stationary tracking
  wasStationary = false;
  lastStillTime = millis();
  
  Serial.println("State variables reset");
}

// Wake up MPU-6050 from low power mode
void wakeMPUFromSleep() {
  Serial.println("Waking MPU-6050 from low power mode...");
  
  // Wake up MPU-6050 by enabling sleep mode off
  mpu.setSleepEnabled(false);
  mpu.setWakeCycleEnabled(false);
  Serial.println("  - Set to normal mode");
  
  // Enable all sensors (gyroscope and accelerometer)
  mpu.setStandbyXGyroEnabled(false);
  mpu.setStandbyYGyroEnabled(false);
  mpu.setStandbyZGyroEnabled(false);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  Serial.println("  - Enabled all sensors");
  
  delay(100);  // Wait for sensor to stabilize
  
  Serial.println("MPU-6050 woken up and ready for normal operation");
}

// Enter deep sleep mode with timer wake
void enterDeepSleep() {
  Serial.println("=====================================");
  Serial.println("ENTERING DEEP SLEEP MODE");
  Serial.print("Device will wake every ");
  Serial.print(POLL_INTERVAL_SECONDS);
  Serial.println(" seconds to check for motion");
  Serial.print("Current uptime: ");
  Serial.print(millis() / 1000);
  Serial.println(" seconds");
  Serial.println("=====================================");
  Serial.flush();  // Ensure all serial data is sent
  
  // Put MPU-6050 into low power mode before sleeping
  putMPUToSleep();
  
  // Wait for MPU-6050 to enter low power mode
  delay(200);
  
  // Disable BLE and wait for clean shutdown
  BLEDevice::deinit(true);
  delay(100);  // Allow time for BLE to fully power down
  
  // Explicitly disable WiFi radio to save power (can consume 20-100mA if left on)
  // Note: These may fail if WiFi was never started, which is expected and harmless
  esp_err_t wifi_err = esp_wifi_stop();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    Serial.print("WiFi stop warning: ");
    Serial.println(wifi_err);
  }
  
  wifi_err = esp_wifi_deinit();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    Serial.print("WiFi deinit warning: ");
    Serial.println(wifi_err);
  }
  
  // Wait for all radio shutdowns to complete
  delay(200);
  Serial.println("BLE and WiFi shut down");
  Serial.flush();
  
  // Disable unused peripherals to minimize power consumption
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_SLOW_MEM, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_FAST_MEM, ESP_PD_OPTION_OFF);
  
  // Configure timer wake-up
  uint64_t sleep_time_us = POLL_INTERVAL_SECONDS * 1000000ULL;
  esp_sleep_enable_timer_wakeup(sleep_time_us);
  
  Serial.print("Timer wake configured for ");
  Serial.print(POLL_INTERVAL_SECONDS);
  Serial.println(" seconds");
  Serial.println("Entering deep sleep NOW...");
  Serial.flush();
  delay(100);  // Ensure serial output completes
  
  // Enter deep sleep
  esp_deep_sleep_start();
}

void setup() {
  // Initialize Serial communication
  Serial.begin(115200);
  
  // Disable WiFi radio immediately to save power (not needed for BLE-only operation)
  // WiFi can consume 20-100mA even when not actively used
  // Note: esp_wifi_stop() may fail if WiFi was never started, which is expected and harmless
  esp_err_t err = esp_wifi_stop();
  if (err == ESP_OK) {
    Serial.println("WiFi stopped successfully");
  } else if (err == ESP_ERR_WIFI_NOT_INIT) {
    Serial.println("WiFi was not initialized (expected for BLE-only mode)");
  }
  
  // Configure power optimizations
  configurePowerOptimizations();
  
  // Check wake-up reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
    Serial.println("=====================================");
    Serial.println("WOKE UP FROM DEEP SLEEP");
    Serial.println("Reason: Timer wake (motion polling)");
    Serial.println("=====================================");
    
    // Initialize I2C and MPU for motion check
    Wire.begin(SDA_PIN, SCL_PIN);
    wakeMPUFromSleep();
    mpu.initialize();
    
    // Check for motion
    bool motionDetected = checkForMotion();
    
    if (!motionDetected) {
      // No motion detected - go back to sleep
      Serial.println("No motion detected - returning to sleep");
      enterDeepSleep();
      // Never reaches here as enterDeepSleep() resets the device
    }
    
    // Motion detected - continue with normal startup
    Serial.println("Motion detected - resuming normal operation...");
    Serial.println("=====================================");
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    Serial.println("=====================================");
    Serial.println("DEVICE STARTING");
    Serial.println("Reason: Power-on or hard reset");
    Serial.println("=====================================");
  } else {
    Serial.println("=====================================");
    Serial.println("DEVICE STARTING");
    Serial.print("Wake-up reason: ");
    Serial.println(wakeup_reason);
    Serial.println("=====================================");
  }

  // --- MPU-6050 Setup ---
  Wire.begin(SDA_PIN, SCL_PIN); // SDA, SCL
  
  // If waking from timer (and motion was detected), MPU is already initialized
  // Otherwise, initialize it now
  if (wakeup_reason != ESP_SLEEP_WAKEUP_TIMER) {
    mpu.initialize();
    
    // Test connection
    if (mpu.testConnection()) {
      Serial.println("MPU-6050 connection successful");
    } else {
      Serial.println("MPU-6050 connection failed");
    }
    
    // Set ranges: ±2g for accelerometer, ±500°/s for gyroscope (matching tockn library)
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_2);
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);
    
    Serial.println("MPU-6050 initialized");
  }
  
  // Try to load stored calibration offsets (software offsets in degrees/s)
  if (loadGyroOffsets(&gyroXoffset, &gyroYoffset, &gyroZoffset)) {
    calibrationComplete = true;
    Serial.println("Using stored calibration offsets");
    Serial.print("X : "); Serial.println(gyroXoffset);
    Serial.print("Y : "); Serial.println(gyroYoffset);
    Serial.print("Z : "); Serial.println(gyroZoffset);
  } else {
    // No stored offsets - calibration will happen when device is still for 4 minutes
    calibrationComplete = false;
    gyroXoffset = 0.0f;
    gyroYoffset = 0.0f;
    gyroZoffset = 0.0f;
    Serial.println("No stored calibration - will calibrate when device is still for 4 minutes");
  }
  
  Serial.println("------------------------------------");

  // Reset all state variables (critical after wake from sleep)
  resetStateVariables();
  
  // Initialize activity timer
  lastActivityTime = millis();


  // --- BLE Setup ---
  // Create the BLE Device
  BLEDevice::init("Pavloff Workout Sensor");
  
  // Set BLE power to minimum (can increase if needed for range)
  // ESP_PWR_LVL_N12 to ESP_PWR_LVL_P9 (lower = less power)
  BLEDevice::setPower(ESP_PWR_LVL_N0, ESP_BLE_PWR_TYPE_DEFAULT);
  Serial.println("BLE power set to minimum for energy efficiency");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic for Accelerometer Data
  pAccelCharacteristic = pService->createCharacteristic(
                      ACCEL_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pAccelCharacteristic->addDescriptor(new BLE2902());

  // Create a BLE Characteristic for Gyroscope Data
  pGyroCharacteristic = pService->createCharacteristic(
                      GYRO_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pGyroCharacteristic->addDescriptor(new BLE2902());

  // Create a BLE Characteristic for Rep Count
  pRepCharacteristic = pService->createCharacteristic(
                      REP_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pRepCharacteristic->addDescriptor(new BLE2902());
  pRepCharacteristic->setCallbacks(new RepCharacteristicCallbacks());
  // Set initial value before starting service
  pRepCharacteristic->setValue("Count:0,State:IDLE");

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->start();
  Serial.println("Waiting for a client connection to notify...");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Periodic diagnostic output every 2 seconds
  static unsigned long lastDiagnosticTime = 0;
  if (currentTime - lastDiagnosticTime >= 2000) {
    lastDiagnosticTime = currentTime;
    Serial.println("======== STATE DIAGNOSTIC ========");
    Serial.print("Uptime: "); Serial.print(currentTime / 1000); Serial.println(" seconds");
    Serial.print("BLE Connected: "); Serial.println(deviceConnected ? "YES" : "NO");
    Serial.print("Rep Count: "); Serial.print(repCount);
    Serial.print(" | State: ");
    switch(repState) {
      case REP_IDLE: Serial.println("IDLE"); break;
      case REP_MOVING_UP: Serial.println("MOVING_UP"); break;
      case REP_MOVING_DOWN: Serial.println("MOVING_DOWN"); break;
      case REP_TRANSITION: Serial.println("TRANSITION"); break;
      default: Serial.println("UNKNOWN"); break;
    }
    Serial.print("Position (m): X="); Serial.print(positionX, 3);
    Serial.print(", Y="); Serial.print(positionY, 3);
    Serial.print(", Z="); Serial.print(positionZ, 3); Serial.println();
    Serial.print("Velocity (m/s): X="); Serial.print(velocityX, 3);
    Serial.print(", Y="); Serial.print(velocityY, 3);
    Serial.print(", Z="); Serial.print(velocityZ, 3); Serial.println();
    Serial.print("Idle timer: "); Serial.print((currentTime - lastActivityTime) / 1000); 
    Serial.print(" / "); Serial.print(IDLE_TIMEOUT_MS / 1000); Serial.println(" seconds");
    Serial.println("==================================");
  }
  
  // Check for idle timeout and enter deep sleep
  if (currentTime - lastActivityTime > IDLE_TIMEOUT_MS) {
    Serial.println("Idle timeout reached - entering deep sleep");
    enterDeepSleep();
    // This line will never be reached as deep sleep resets the device
  }
  
  // Warn when approaching sleep (5 seconds before)
  static bool warningPrinted = false;
  if (currentTime - lastActivityTime > (IDLE_TIMEOUT_MS - 5000) && !warningPrinted) {
    Serial.println("WARNING: Device will enter sleep in 5 seconds if no activity detected");
    warningPrinted = true;
  }
  
  // Reset warning flag when there's activity
  static unsigned long lastWarningResetTime = 0;
  if (currentTime - lastActivityTime < (IDLE_TIMEOUT_MS - 5000) && warningPrinted) {
    if (currentTime - lastWarningResetTime > 1000) {  // Debounce reset
      warningPrinted = false;
      lastWarningResetTime = currentTime;
    }
  }
  
  // Calculate delta time in seconds
  float dt = (currentTime - lastUpdateTime) / 1000.0;
  lastUpdateTime = currentTime;

  // Read sensor data
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
  
  // Convert to physical units
  float rawAccelX = ax * ACCEL_SCALE;  // in g's
  float rawAccelY = ay * ACCEL_SCALE;
  float rawAccelZ = az * ACCEL_SCALE;
  
  // Apply low-pass filter and clamp acceleration
  float filteredX, filteredY, filteredZ;
  filterAndClampAccel(rawAccelX, rawAccelY, rawAccelZ, &filteredX, &filteredY, &filteredZ);
  
  // Use filtered values for motion tracking
  rawAccelX = filteredX;
  rawAccelY = filteredY;
  rawAccelZ = filteredZ;
  
  // Convert gyro to degrees/s and subtract software offsets (matching tockn library)
  float gyroXdeg = gx * GYRO_SCALE - gyroXoffset;
  float gyroYdeg = gy * GYRO_SCALE - gyroYoffset;
  float gyroZdeg = gz * GYRO_SCALE - gyroZoffset;
  
  // Convert to radians/s for AHRS algorithm
  float rawGyroX = gyroXdeg * (PI / 180.0f);
  float rawGyroY = gyroYdeg * (PI / 180.0f);
  float rawGyroZ = gyroZdeg * (PI / 180.0f);

  // Debug: Print raw sensor values every 100ms
  static unsigned long lastDebugTime = 0;
  // if (currentTime - lastDebugTime >= 100) {
  //   lastDebugTime = currentTime;
  //   Serial.print("RAW: Accel(g): ");
  //   Serial.print(rawAccelX, 3); Serial.print(", ");
  //   Serial.print(rawAccelY, 3); Serial.print(", ");
  //   Serial.print(rawAccelZ, 3);
  //   Serial.print(" | Gyro(rad/s): ");
  //   Serial.print(rawGyroX, 3); Serial.print(", ");
  //   Serial.print(rawGyroY, 3); Serial.print(", ");
  //   Serial.println(rawGyroZ, 3);
  // }

  // Skip integration on first iteration to avoid large dt error
  if (firstIteration) {
    firstIteration = false;
  } else {
    // Update AHRS algorithm to get orientation
    MahonyAHRSupdateIMU(rawGyroX, rawGyroY, rawGyroZ, rawAccelX, rawAccelY, rawAccelZ, dt);

    // Debug: Print quaternion orientation
    // if (currentTime - lastDebugTime < 10) {
    //   Serial.print("QUAT: q0=");
    //   Serial.print(q0, 4); Serial.print(", q1=");
    //   Serial.print(q1, 4); Serial.print(", q2=");
    //   Serial.print(q2, 4); Serial.print(", q3=");
    //   Serial.println(q3, 4);
    // }

    // Rotate acceleration to Earth frame (tilt-compensated)
    float earthAccelX, earthAccelY, earthAccelZ;
    rotateVector(rawAccelX, rawAccelY, rawAccelZ, &earthAccelX, &earthAccelY, &earthAccelZ);

    // Detect if board is stationary (acceleration magnitude ≈ 1g and gyro ≈ 0)
    float accelMag = sqrt(earthAccelX*earthAccelX + earthAccelY*earthAccelY + earthAccelZ*earthAccelZ);
    float gyroMag = sqrt(rawGyroX*rawGyroX + rawGyroY*rawGyroY + rawGyroZ*rawGyroZ);
    bool isStationary = (abs(accelMag - 1.0f) < ACCEL_STATIONARY_THRESHOLD) && (gyroMag < GYRO_STATIONARY_THRESHOLD);

    // Debug: Print Earth-frame acceleration
    // if (currentTime - lastDebugTime < 10) {
    //   Serial.print("EARTH: Accel(g): ");
    //   Serial.print(earthAccelX, 3); Serial.print(", ");
    //   Serial.print(earthAccelY, 3); Serial.print(", ");
    //   Serial.print(earthAccelZ, 3);
    //   Serial.print(" | Mag: ");
    //   Serial.print(accelMag, 3);
    //   Serial.print(" | GyroMag: ");
    //   Serial.print(gyroMag, 3);
    //   if (isStationary) Serial.print(" [STATIONARY]");
    //   Serial.println();
    // }

    // Remove gravity (0, 0, 1g) to get linear acceleration in Earth frame
    float linearAccelX = earthAccelX * 9.81f;
    float linearAccelY = earthAccelY * 9.81f;
    float linearAccelZ = (earthAccelZ - 1.0f) * 9.81f;

    // Zero out linear acceleration when stationary to prevent drift
    if (isStationary) {
      linearAccelX = 0.0f;
      linearAccelY = 0.0f;
      linearAccelZ = 0.0f;
      
      // Track stillness duration for calibration
      if (!wasStationary) {
        // Device just became stationary
        lastStillTime = currentTime;
        wasStationary = true;
      } else {
        // Device has been stationary - check if 4 minutes have passed
        unsigned long stillDuration = currentTime - lastStillTime;
        if (!calibrationComplete && stillDuration >= CALIBRATION_STILLNESS_MS) {
          // Device has been still for 4 minutes and not yet calibrated - perform calibration
          performCalibration();
          lastStillTime = currentTime;  // Reset still time to avoid immediate recalibration
        } else if (calibrationComplete && stillDuration >= CALIBRATION_STILLNESS_MS) {
          // Recalibrate periodically when device is still for 4 minutes
          performCalibration();
          lastStillTime = currentTime;  // Reset still time
        }
      }
    } else {
      // Device is moving - reset stillness tracking
      wasStationary = false;
    }

    // Debug: Print linear acceleration
    // if (currentTime - lastDebugTime < 10) {
    //   Serial.print("LINEAR: Accel(m/s²): ");
    //   Serial.print(linearAccelX, 3); Serial.print(", ");
    //   Serial.print(linearAccelY, 3); Serial.print(", ");
    //   Serial.print(linearAccelZ, 3);
    //   if (isStationary) Serial.print(" [STATIONARY]");
    //   Serial.println();
    // }

    // Integrate acceleration to get velocity (v = v0 + a*dt)
    velocityX += linearAccelX * dt;
    velocityY += linearAccelY * dt;
    velocityZ += linearAccelZ * dt;

    // Apply velocity damping to reduce drift (for real-time processing)
    velocityX *= VELOCITY_DAMPING;
    velocityY *= VELOCITY_DAMPING;
    velocityZ *= VELOCITY_DAMPING;

    // Zero out very small velocities (noise threshold)
    if (abs(velocityX) < VELOCITY_THRESHOLD) velocityX = 0.0f;
    if (abs(velocityY) < VELOCITY_THRESHOLD) velocityY = 0.0f;
    if (abs(velocityZ) < VELOCITY_THRESHOLD) velocityZ = 0.0f;

    // Debug: Print velocity
    // if (currentTime - lastDebugTime < 10) {
    //   Serial.print("VEL: (m/s): ");
    //   Serial.print(velocityX, 4); Serial.print(", ");
    //   Serial.print(velocityY, 4); Serial.print(", ");
    //   Serial.print(velocityZ, 4);
    //   Serial.print(" | dt: ");
    //   Serial.println(dt, 4);
    // }

    // Integrate velocity to get position (p = p0 + v*dt)
    positionX += velocityX * dt;
    positionY += velocityY * dt;
    positionZ += velocityZ * dt;

    // Apply position damping to pull toward zero (corrects long-term drift)
    positionX *= POSITION_DAMPING;
    positionY *= POSITION_DAMPING;
    positionZ *= POSITION_DAMPING;

    // Debug: Print position
    // if (currentTime - lastDebugTime < 10) {
    //   Serial.print("POS: (m): ");
    //   Serial.print(positionX, 4); Serial.print(", ");
    //   Serial.print(positionY, 4); Serial.print(", ");
    //   Serial.println(positionZ, 4);
    //   
    //   // Calculate and print total distance from starting point
    //   float totalDistance = sqrt(positionX*positionX + positionY*positionY + positionZ*positionZ);
    //   Serial.print("DIST: (m): ");
    //   Serial.print(totalDistance, 4);
    //   Serial.print(" | (mm): ");
    //   Serial.println(totalDistance * 1000.0, 2);
    //   Serial.println("---");
    // }

    // Detect workout reps based on velocity and acceleration patterns
    float linearAccelMag = sqrt(linearAccelX*linearAccelX + linearAccelY*linearAccelY + linearAccelZ*linearAccelZ) / 9.81f;
    detectRep(velocityX, velocityY, velocityZ, linearAccelMag, currentTime);
    
    // Update activity timer if there's motion (not stationary)
    // Note: BLE connection state does not prevent sleep - only motion does
    if (!isStationary) {
      lastActivityTime = currentTime;
    }
    
    // Also update activity timer if stationary and waiting for calibration
    // This prevents sleep while accumulating stillness time for calibration
    if (isStationary && !calibrationComplete && wasStationary) {
      lastActivityTime = currentTime;
    }
  }

  // Only send data if a client is connected and report interval has elapsed
  if (deviceConnected && (currentTime - lastReportTime >= REPORT_INTERVAL_MS)) {
    lastReportTime = currentTime;

    // --- Prepare and Send Rep Count Data ---
    char repData[30];
    const char* stateStr;
    switch(repState) {
      case REP_IDLE: stateStr = "IDLE"; break;
      case REP_MOVING_UP: stateStr = "UP"; break;
      case REP_MOVING_DOWN: stateStr = "DOWN"; break;
      case REP_TRANSITION: stateStr = "TRANS"; break;
      default: stateStr = "UNKNOWN"; break;
    }
    snprintf(repData, sizeof(repData), "Count:%d,State:%s", repCount, stateStr);

    // Set the characteristic value and notify the client
    pRepCharacteristic->setValue(repData);
    pRepCharacteristic->notify();
    Serial.print("Sent Reps:  ");
    Serial.print(repData);
    Serial.print(" (repCount=");
    Serial.print(repCount);
    Serial.println(")");
  }

  // Short delay for high-frequency position calculation
  delay(INTEGRATION_INTERVAL_MS);
}
