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

// Pin configuration
#define SDA_PIN 8   // I2C SDA pin
#define SCL_PIN 9   // I2C SCL pin
#define INT_PIN 18  // MPU6050 INT pin connected to ESP32 GPIO 18

// Power management constants
#define IDLE_TIMEOUT_MS 20000  // 20 seconds in milliseconds (for testing)
#define CALIBRATION_STILLNESS_MS 240000  // 4 minutes in milliseconds

// Power optimization settings
void configurePowerOptimizations() {
  // Reduce CPU frequency to save power (80 MHz is sufficient for this application)
  // ESP32-S3 supports 240MHz, 160MHz, 80MHz, 40MHz, 20MHz, 10MHz
  setCpuFrequencyMhz(80);
  
  // Enable automatic light sleep when idle
  // This allows the CPU to enter light sleep between tasks
  esp_pm_config_esp32s3_t pm_config;
  pm_config.max_freq_mhz = 80;
  pm_config.min_freq_mhz = 10;
  pm_config.light_sleep_enable = true;
  esp_pm_configure(&pm_config);
  
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

// Interrupt debugging variables
volatile bool interruptTriggered = false;
volatile unsigned long interruptCount = 0;

// ISR for MPU6050 interrupt pin (for testing)
void IRAM_ATTR mpuInterruptISR() {
  interruptTriggered = true;
  interruptCount++;
}

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
      Serial.println("\n*** BLE CLIENT CONNECTED ***");
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      lastActivityTime = millis();  // Reset activity timer on disconnection
      Serial.println("\n*** BLE CLIENT DISCONNECTED ***");
      // Restart advertising so a new client can connect
      Serial.println("Restarting BLE advertising");
      pServer->getAdvertising()->start();
    }
};

// Handles write events to the rep characteristic
class RepCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        Serial.print("BLE Write received: ");
        Serial.println(value.c_str());
        
        // Reset activity timer on any BLE interaction
        lastActivityTime = millis();
        
        // Check for reset command
        if (value == "RESET" || value == "reset") {
          Serial.println("Rep counter reset command received");
          repCount = 0;
          repState = REP_IDLE;
          phaseStartTime = millis();
          
          // Send immediate update with new count
          char repData[30];
          snprintf(repData, sizeof(repData), "Count:0,State:IDLE");
          pCharacteristic->setValue(repData);
          pCharacteristic->notify();
          Serial.println("Rep counter reset to 0");
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
  preferences.putInt("calVersion", 2);  // Version 2 = ElectronicCats library with software offsets
  preferences.end();
}

// Load gyro calibration offsets from persistent storage
bool loadGyroOffsets(float* offsetX, float* offsetY, float* offsetZ) {
  preferences.begin("mpu6050", true);  // Open in read-only mode
  
  // Check calibration version to ensure compatibility
  // Version 2 = ElectronicCats library with software offsets
  int calVersion = preferences.getInt("calVersion", 0);
  bool hasOffsets = preferences.getBool("hasOffsets", false);
  
  if (hasOffsets && calVersion == 2) {
    *offsetX = preferences.getFloat("gyroOffsetX", 0.0f);
    *offsetY = preferences.getFloat("gyroOffsetY", 0.0f);
    *offsetZ = preferences.getFloat("gyroOffsetZ", 0.0f);
    preferences.end();
    return true;
  }
  
  preferences.end();
  if (hasOffsets && calVersion != 2) {
  } else {
  }
  return false;
}

// Perform gyro calibration and save results (matches tockn library behavior)
void performCalibration() {
  Serial.println("\n=== Starting Gyro Calibration ===");
  Serial.println("Collecting 3000 samples...");
  
  // Calculate gyro offsets by averaging readings (same as tockn library: 3000 samples)
  float x = 0.0f, y = 0.0f, z = 0.0f;
  int16_t rx, ry, rz;
  
  delay(1000);  // Wait for device to settle
  
  for (int i = 0; i < 3000; i++) {
    if (i % 1000 == 0) {
      Serial.print("  Sample ");
      Serial.print(i);
      Serial.println("...");
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
  
  Serial.println("\nCalibration complete!");
  Serial.println("Gyro offsets calculated:");
  Serial.print("  X: ");
  Serial.print(gyroXoffset);
  Serial.println(" °/s");
  Serial.print("  Y: ");
  Serial.print(gyroYoffset);
  Serial.println(" °/s");
  Serial.print("  Z: ");
  Serial.print(gyroZoffset);
  Serial.println(" °/s");
  
  saveGyroOffsets(gyroXoffset, gyroYoffset, gyroZoffset);
  Serial.println("Offsets saved to persistent storage");
  calibrationComplete = true;
  
  Serial.println("Resuming normal operation in 3 seconds...");
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

// Configure MPU6050 motion detection interrupt for wake-up
void configureMPUMotionInterrupt() {
  Serial.println("  Configuring motion detection interrupt");
  
  // Reset all interrupt registers to known state
  mpu.setIntEnabled(0x00);  // Disable all interrupts
  mpu.setIntFreefallEnabled(false);
  mpu.setIntMotionEnabled(false);
  mpu.setIntZeroMotionEnabled(false);
  
  // Configure interrupt pin behavior
  // Active HIGH, push-pull, held until interrupt is cleared, cleared on any read
  mpu.setInterruptMode(false);      // false = active high
  mpu.setInterruptDrive(false);     // false = push-pull
  mpu.setInterruptLatch(true);      // true = held until cleared
  mpu.setInterruptLatchClear(true); // true = cleared on any read
  
  // Configure motion detection
  // Motion threshold: 1-255 (1 LSB = 2mg @ 2g range, so value of 32 = 64mg = 0.064g)
  // For sensitive wake: 16 = 32mg = 0.032g
  // For normal wake: 32 = 64mg = 0.064g  
  // For less sensitive: 64 = 128mg = 0.128g
  mpu.setMotionDetectionThreshold(16);  // 32mg threshold - more sensitive for easier wake-up
  
  // Motion duration: 0-255 (1 LSB = 1ms @ 1kHz ODR)
  // Setting to 5ms to avoid false triggers from vibration
  mpu.setMotionDetectionDuration(5);  // 5ms duration
  
  // Configure Digital High Pass Filter (DHPF) for motion detection
  // DHPF reset to remove DC bias from accelerometer
  mpu.setDHPFMode(MPU6050_DHPF_RESET);
  delay(10);  // Allow DHPF to reset
  mpu.setDHPFMode(MPU6050_DHPF_5);  // Use 5Hz high-pass filter
  
  // Enable motion detection interrupt
  mpu.setIntMotionEnabled(true);
  Serial.println("  Motion detection interrupt enabled");
  
  // Verify interrupt is configured
  uint8_t intStatus = mpu.getIntStatus();
  Serial.print("  Interrupt status: 0x");
  Serial.println(intStatus, HEX);
  
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
        } else {
          repState = REP_MOVING_DOWN;
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
      }
      break;
      
    case REP_MOVING_DOWN:
      // Check for direction change to upward motion
      if (isMoving && dominantAxisVelocity > REP_VELOCITY_THRESHOLD * 1.2f && phaseDuration > REP_MIN_DURATION_MS) {
        repState = REP_MOVING_UP;
        phaseStartTime = currentTime;
      }
      break;
      
    case REP_TRANSITION:
      // Not used in current implementation
      break;
  }
}

// Put MPU-6050 into low power mode for sleep
void putMPUToSleep() {
  Serial.println("Putting MPU into low power mode");
  
  // Configure motion detection interrupt for wake-up
  configureMPUMotionInterrupt();
  
  // Disable temperature sensor to save power
  Serial.println("  Disabling temperature sensor");
  mpu.setTempSensorEnabled(false);
  
  // Disable gyroscope to save power, keep accelerometer enabled for motion detection
  Serial.println("  Disabling gyroscope, keeping accelerometer active");
  mpu.setStandbyXGyroEnabled(true);
  mpu.setStandbyYGyroEnabled(true);
  mpu.setStandbyZGyroEnabled(true);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  
  // NOTE: Cycle mode disabled - testing showed it interferes with interrupt generation
  // Keep MPU6050 in normal mode with motion detection interrupt enabled
  // This uses more power (~3.6mA vs ~500μA in cycle mode) but interrupts work reliably
  Serial.println("  Keeping MPU in normal mode (cycle mode disabled)");
  mpu.setWakeCycleEnabled(false);
  mpu.setSleepEnabled(false);
  
  // Wait for power mode changes to settle
  delay(100);
  Serial.println("MPU low power mode configured");
  
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
  
}

// Wake up MPU-6050 from low power mode
void wakeMPUFromSleep() {
  Serial.println("Waking MPU from low power mode");
  
  // Clear any pending motion interrupt
  uint8_t intStatus = mpu.getIntStatus();
  if (intStatus & 0x40) {
    Serial.println("  Motion interrupt was active");
  }
  
  // Disable cycle mode and wake up MPU-6050
  Serial.println("  Disabling sleep/cycle modes");
  mpu.setWakeCycleEnabled(false);
  mpu.setSleepEnabled(false);
  
  // Enable all sensors (gyroscope and accelerometer)
  Serial.println("  Enabling all sensors");
  mpu.setStandbyXGyroEnabled(false);
  mpu.setStandbyYGyroEnabled(false);
  mpu.setStandbyZGyroEnabled(false);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  
  // Disable motion detection interrupt during normal operation
  Serial.println("  Disabling motion interrupt");
  mpu.setIntMotionEnabled(false);
  
  delay(100);  // Wait for sensor to stabilize
  Serial.println("MPU wake complete");
  
}

// Enter deep sleep mode with interrupt wake
void enterDeepSleep() {
  Serial.println("\n=== Entering Deep Sleep ===");
  
  // Put MPU-6050 into low power mode with motion interrupt configured
  Serial.println("Configuring MPU for motion wake-up");
  putMPUToSleep();
  
  // Clear any pending interrupt status before sleep
  uint8_t intStatus = mpu.getIntStatus();
  Serial.print("MPU interrupt status before sleep: 0x");
  Serial.println(intStatus, HEX);
  
  // Wait for MPU-6050 to enter low power mode and interrupt to be ready
  delay(200);
  
  // Check GPIO 18 level before sleep
  Serial.print("GPIO 18 level before sleep: ");
  Serial.println(digitalRead(INT_PIN));
  
  // Disable BLE and wait for clean shutdown
  Serial.println("Shutting down BLE");
  BLEDevice::deinit(true);
  delay(100);  // Allow time for BLE to fully power down
  
  // Explicitly disable WiFi radio to save power (can consume 20-100mA if left on)
  // Note: These may fail if WiFi was never started, which is expected and harmless
  Serial.println("Shutting down WiFi (if active)");
  esp_err_t wifi_err = esp_wifi_stop();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    Serial.print("WiFi stop error: ");
    Serial.println(wifi_err);
  }
  
  wifi_err = esp_wifi_deinit();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    Serial.print("WiFi deinit error: ");
    Serial.println(wifi_err);
  }
  
  // Wait for all radio shutdowns to complete
  delay(200);
  
  // Disable unused peripherals to minimize power consumption
  Serial.println("Disabling unused peripherals");
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_SLOW_MEM, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_FAST_MEM, ESP_PD_OPTION_OFF);
  
  // Configure GPIO interrupt wake-up on INT_PIN (GPIO 18) for ESP32-S3 deep sleep
  // Motion interrupt from MPU6050 will wake the ESP32
  // For deep sleep, ESP32-S3 uses ext1 wakeup for RTC GPIOs
  
  // GPIO 18 is RTC_GPIO 18 on ESP32-S3
  // Use ext1 wakeup with single GPIO and HIGH level trigger
  uint64_t gpio_mask = (1ULL << INT_PIN);
  
  // Enable ext1 wakeup on GPIO 18 with ANY_HIGH mode (wakes when any selected GPIO is HIGH)
  Serial.print("Configuring wake on GPIO ");
  Serial.print(INT_PIN);
  Serial.println(" (motion interrupt)");
  esp_sleep_enable_ext1_wakeup(gpio_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
  
  // Configure internal pull-down on the GPIO
  gpio_pulldown_en((gpio_num_t)INT_PIN);
  gpio_pullup_dis((gpio_num_t)INT_PIN);
  
  Serial.println("*** ENTERING DEEP SLEEP NOW ***");
  Serial.println("Device will wake on motion detection");
  delay(100);  // Ensure serial output completes
  
  // Enter deep sleep
  esp_deep_sleep_start();
}

void setup() {
  // Initialize Serial communication for debugging
  Serial.begin(115200);
  delay(1000);  // Wait for serial port to initialize
  Serial.println("\n\n=== Pavloff Workout Sensor Starting ===");
  Serial.println("Firmware: ESP32-S3 Motion Tracking");
  Serial.print("CPU Frequency: ");
  Serial.print(getCpuFrequencyMhz());
  Serial.println(" MHz");
  
  // Disable WiFi radio immediately to save power (not needed for BLE-only operation)
  // WiFi can consume 20-100mA even when not actively used
  // Note: esp_wifi_stop() may fail if WiFi was never started, which is expected and harmless
  Serial.println("\n--- Disabling WiFi ---");
  esp_err_t err = esp_wifi_stop();
  if (err == ESP_OK) {
    Serial.println("WiFi stopped successfully");
  } else if (err == ESP_ERR_WIFI_NOT_INIT) {
    Serial.println("WiFi was not initialized (expected)");
  } else {
    Serial.print("WiFi stop failed with error: ");
    Serial.println(err);
  }
  
  // Configure power optimizations
  Serial.println("\n--- Configuring Power Optimizations ---");
  configurePowerOptimizations();
  Serial.print("CPU Frequency after optimization: ");
  Serial.print(getCpuFrequencyMhz());
  Serial.println(" MHz");
  
  // Check wake-up reason
  Serial.println("\n--- Checking Wake-Up Reason ---");
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    Serial.println("Wake-up source: MOTION INTERRUPT (GPIO 18)");
    // Motion detected - continue with normal startup
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    Serial.println("Wake-up source: POWER ON or RESET");
  } else {
    Serial.print("Wake-up source: ");
    Serial.println(wakeup_reason);
  }

  // --- MPU-6050 Setup ---
  Serial.println("\n--- Initializing MPU-6050 ---");
  Serial.print("I2C SDA Pin: ");
  Serial.println(SDA_PIN);
  Serial.print("I2C SCL Pin: ");
  Serial.println(SCL_PIN);
  Serial.print("INT Pin: ");
  Serial.println(INT_PIN);
  
  Wire.begin(SDA_PIN, SCL_PIN); // SDA, SCL
  Serial.println("I2C bus initialized");
  
  // If waking from deep sleep, restore MPU from low power mode FIRST
  // This must be done before initialize() to ensure proper state
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    Serial.println("Restoring MPU from low power mode...");
    
    // Clear any pending motion interrupt
    uint8_t intStatus = mpu.getIntStatus();
    if (intStatus & 0x40) {
      Serial.println("Motion interrupt was pending");
    }
    
    // Disable motion detection interrupt immediately
    mpu.setIntMotionEnabled(false);
    
    // Disable cycle mode and ensure device is awake
    mpu.setWakeCycleEnabled(false);
    mpu.setSleepEnabled(false);
    
    // Enable all sensors that may have been disabled for sleep
    mpu.setStandbyXGyroEnabled(false);
    mpu.setStandbyYGyroEnabled(false);
    mpu.setStandbyZGyroEnabled(false);
    mpu.setStandbyXAccelEnabled(false);
    mpu.setStandbyYAccelEnabled(false);
    mpu.setStandbyZAccelEnabled(false);
    
    // Re-enable temperature sensor
    mpu.setTempSensorEnabled(true);
    
    // Wait for sensor to fully stabilize after wake
    delay(200);
    Serial.println("MPU restored from low power mode");
  }
  
  // Initialize MPU-6050 (now that it's in proper state)
  Serial.println("Calling mpu.initialize()...");
  mpu.initialize();
  Serial.println("MPU-6050 initialization complete");
  
  // Test connection
  Serial.print("Testing MPU-6050 connection... ");
  if (mpu.testConnection()) {
    Serial.println("SUCCESS! MPU-6050 connection verified");
  } else {
    Serial.println("FAILED! MPU-6050 not responding");
    Serial.println("Check I2C connections and power supply");
  }
  
  // Set ranges: ±2g for accelerometer, ±500°/s for gyroscope (matching tockn library)
  Serial.println("Configuring MPU-6050 ranges...");
  mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_2);
  Serial.println("  Accelerometer: ±2g");
  mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);
  Serial.println("  Gyroscope: ±500°/s");
  
  // Ensure all interrupts are disabled for normal operation
  Serial.println("Disabling interrupts for normal operation");
  mpu.setIntEnabled(0x00);
  mpu.setIntFreefallEnabled(false);
  mpu.setIntMotionEnabled(false);
  mpu.setIntZeroMotionEnabled(false);
  
  // Reset DHPF to ensure clean accelerometer readings
  mpu.setDHPFMode(MPU6050_DHPF_RESET);
  delay(10);
  mpu.setDHPFMode(MPU6050_DHPF_HOLD);  // Hold mode for normal operation (no high-pass filtering)
  Serial.println("DHPF configured to HOLD mode");
  
  
  // Try to load stored calibration offsets (software offsets in degrees/s)
  Serial.println("\n--- Loading Gyro Calibration ---");
  if (loadGyroOffsets(&gyroXoffset, &gyroYoffset, &gyroZoffset)) {
    Serial.println("Loaded stored calibration offsets:");
    Serial.print("  X offset: ");
    Serial.print(gyroXoffset);
    Serial.println(" °/s");
    Serial.print("  Y offset: ");
    Serial.print(gyroYoffset);
    Serial.println(" °/s");
    Serial.print("  Z offset: ");
    Serial.print(gyroZoffset);
    Serial.println(" °/s");
    calibrationComplete = true;
  } else {
    // No stored offsets - perform calibration immediately on startup
    Serial.println("No stored calibration found");
    Serial.println("Starting calibration in 2 seconds...");
    Serial.println("*** KEEP DEVICE STATIONARY ***");
    calibrationComplete = false;
    gyroXoffset = 0.0f;
    gyroYoffset = 0.0f;
    gyroZoffset = 0.0f;
    delay(2000);  // Give user time to read message and stabilize device
    performCalibration();
  }
  

  // Reset all state variables (critical after wake from sleep)
  Serial.println("\n--- Resetting State Variables ---");
  resetStateVariables();
  Serial.println("State variables reset");
  
  // Initialize activity timer
  lastActivityTime = millis();
  Serial.print("Activity timer initialized: ");
  Serial.print(lastActivityTime);
  Serial.println(" ms");


  // --- BLE Setup ---
  Serial.println("\n--- Initializing BLE ---");
  // Create the BLE Device
  Serial.println("Creating BLE device: 'Pavloff Workout Sensor'");
  BLEDevice::init("Pavloff Workout Sensor");
  
  // Set BLE power to minimum (can increase if needed for range)
  // ESP_PWR_LVL_N12 to ESP_PWR_LVL_P9 (lower = less power)
  Serial.println("Setting BLE power level to 0 dBm");
  BLEDevice::setPower(ESP_PWR_LVL_N0, ESP_BLE_PWR_TYPE_DEFAULT);

  // Create the BLE Server
  Serial.println("Creating BLE server");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  Serial.println("BLE server callbacks configured");

  // Create the BLE Service
  Serial.print("Creating BLE service with UUID: ");
  Serial.println(SERVICE_UUID);
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic for Accelerometer Data
  Serial.println("Creating Accelerometer characteristic");
  pAccelCharacteristic = pService->createCharacteristic(
                      ACCEL_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pAccelCharacteristic->addDescriptor(new BLE2902());
  Serial.println("  Accelerometer characteristic configured");

  // Create a BLE Characteristic for Gyroscope Data
  Serial.println("Creating Gyroscope characteristic");
  pGyroCharacteristic = pService->createCharacteristic(
                      GYRO_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pGyroCharacteristic->addDescriptor(new BLE2902());
  Serial.println("  Gyroscope characteristic configured");

  // Create a BLE Characteristic for Rep Count
  Serial.println("Creating Rep Counter characteristic");
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
  Serial.println("  Rep Counter characteristic configured");

  // Start the service
  Serial.println("Starting BLE service");
  pService->start();

  // Start advertising
  Serial.println("Starting BLE advertising");
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->start();
  Serial.println("BLE advertising started");
  
  Serial.println("\n=== Setup Complete ===");
  Serial.println("Device is ready and advertising");
  Serial.println("Entering main loop...\n");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Periodic diagnostic output every 2 seconds
  static unsigned long lastDiagnosticTime = 0;
  if (currentTime - lastDiagnosticTime >= 2000) {
    lastDiagnosticTime = currentTime;
    Serial.println("\n--- Status Update ---");
    Serial.print("Uptime: ");
    Serial.print(currentTime / 1000);
    Serial.println(" seconds");
    Serial.print("BLE Connected: ");
    Serial.println(deviceConnected ? "YES" : "NO");
    Serial.print("Rep Count: ");
    Serial.println(repCount);
    Serial.print("Rep State: ");
    switch(repState) {
      case REP_IDLE: Serial.println("IDLE"); break;
      case REP_MOVING_UP: Serial.println("MOVING_UP"); break;
      case REP_MOVING_DOWN: Serial.println("MOVING_DOWN"); break;
      case REP_TRANSITION: Serial.println("TRANSITION"); break;
      default: Serial.println("UNKNOWN"); break;
    }
    Serial.print("Time until sleep: ");
    Serial.print((IDLE_TIMEOUT_MS - (currentTime - lastActivityTime)) / 1000);
    Serial.println(" seconds");
  }
  
  // Check for idle timeout and enter deep sleep
  if (currentTime - lastActivityTime > IDLE_TIMEOUT_MS) {
    Serial.println("\n*** IDLE TIMEOUT - ENTERING DEEP SLEEP ***");
    enterDeepSleep();
    // This line will never be reached as deep sleep resets the device
  }
  
  // Warn when approaching sleep (5 seconds before)
  static bool warningPrinted = false;
  if (currentTime - lastActivityTime > (IDLE_TIMEOUT_MS - 5000) && !warningPrinted) {
    Serial.println("\n*** WARNING: Deep sleep in 5 seconds ***");
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
  // }

  // Skip integration on first iteration to avoid large dt error
  if (firstIteration) {
    firstIteration = false;
  } else {
    // Update AHRS algorithm to get orientation
    MahonyAHRSupdateIMU(rawGyroX, rawGyroY, rawGyroZ, rawAccelX, rawAccelY, rawAccelZ, dt);

    // Debug: Print quaternion orientation
    // if (currentTime - lastDebugTime < 10) {
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
    //   
    //   // Calculate and print total distance from starting point
    //   float totalDistance = sqrt(positionX*positionX + positionY*positionY + positionZ*positionZ);
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
  }

  // Short delay for high-frequency position calculation
  delay(INTEGRATION_INTERVAL_MS);
}
