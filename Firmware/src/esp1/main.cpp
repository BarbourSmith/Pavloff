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
#include <WiFi.h>
#include <WebServer.h>
#include <Update.h>

// Firmware version (bump this with each release)
#define FIRMWARE_VERSION "1.0.0"

// Debug configuration
// Set to 1 to enable serial debug output, 0 to disable
#define ENABLE_SERIAL_DEBUG 1

// Serial debug macros - all serial output can be disabled by setting ENABLE_SERIAL_DEBUG to 0
#if ENABLE_SERIAL_DEBUG
  #define DEBUG_PRINT(x) Serial.print(x)
  #define DEBUG_PRINTLN(x) Serial.println(x)
  #define DEBUG_PRINTF(x, y) Serial.print(x, y)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
  #define DEBUG_PRINTF(x, y)
#endif

// Pin configuration
#define SDA_PIN 8   // I2C SDA pin
#define SCL_PIN 9   // I2C SCL pin
#define INT_PIN 18  // MPU6050 INT pin connected to ESP32 GPIO 18

// Battery voltage monitor pin configuration
#define BATTERY_PIN 7    // GPIO 7 - ADC input for battery voltage
// Voltage divider: R1 = 27k (Battery to Pin), R2 = 68k (Pin to GND)
const float BATTERY_R1 = 27000.0f;
const float BATTERY_R2 = 68000.0f;
const float BATTERY_DIVIDER_RATIO = BATTERY_R2 / (BATTERY_R1 + BATTERY_R2);

// LiPo battery voltage thresholds
#define BATTERY_VOLTAGE_FULL 4.20f    // Fully charged
#define BATTERY_VOLTAGE_NOMINAL 3.70f // Nominal voltage
#define BATTERY_VOLTAGE_LOW 3.25f     // Low battery warning
#define BATTERY_VOLTAGE_EMPTY 3.00f   // Empty / cutoff

// Battery reading interval (read every 10 seconds to save power)
#define BATTERY_READ_INTERVAL_MS 10000

// Status LED pin configuration
#define BLUE_LED_PIN 47  // Blue status LED
#define LED_PWM_CHANNEL 0  // LEDC channel for LED PWM
#define LED_PWM_FREQ 5000  // 5 KHz PWM frequency
#define LED_PWM_RESOLUTION 8  // 8-bit resolution (0-255)

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

// Accelerometer offset values (in g's) for software calibration
// When flat, we expect (0, 0, 1g). Offsets are the deviation from that.
float accelXoffset = 0.0f;
float accelYoffset = 0.0f;
float accelZoffset = 0.0f;

// Preferences object for storing calibration data
Preferences preferences;

// BLE Server and Characteristic pointers
BLEServer* pServer = NULL;
BLECharacteristic* pAccelCharacteristic = NULL;
BLECharacteristic* pGyroCharacteristic = NULL;
BLECharacteristic* pRepCharacteristic = NULL;
BLECharacteristic* pDurationCharacteristic = NULL;
BLECharacteristic* pSensitivityCharacteristic = NULL;
BLECharacteristic* pBatteryCharacteristic = NULL;
BLECharacteristic* pVersionCharacteristic = NULL;
bool deviceConnected = false;

// Position and velocity tracking variables
float velocityX = 0.0, velocityY = 0.0, velocityZ = 0.0;
float positionX = 0.0, positionY = 0.0, positionZ = 0.0;
unsigned long lastUpdateTime = 0;
unsigned long lastReportTime = 0;
bool firstIteration = true;

// Duration tracking variables for duration-based activities
unsigned long durationStartTime = 0;
unsigned long totalDuration = 0; // Total duration in seconds
bool isActivityActive = false;
unsigned long lastVibrationTime = 0;

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

// Battery voltage monitoring variables
unsigned long lastBatteryReadTime = 0;  // Track last battery voltage read
float batteryVoltage = 0.0f;           // Current battery voltage
int batteryPercentage = 0;              // Current battery percentage (0-100)

// Wake on movement setting (persisted to Preferences)
bool wakeOnMovement = false;            // When false, deep sleep requires hardware reset to wake

// OTA update configuration
#define OTA_AP_SSID "Pavloff-Update"
#define OTA_AP_PASSWORD "pavloff123"
bool otaRequested = false;              // Flag set by BLE command to enter OTA mode
bool calibrationRequested = false;      // Flag set by BLE command to trigger calibration

// Blue LED heartbeat variables
unsigned long lastLedUpdate = 0;     // Track last LED update time
uint8_t ledBrightness = 0;           // Current LED brightness (0-255)
bool ledIncreasing = true;           // LED brightness direction

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
#define ACCEL_STATIONARY_THRESHOLD 0.1f   // Acceleration deviation from 1g (tight — accel is now calibrated)
#define GYRO_STATIONARY_THRESHOLD 0.15f   // Gyroscope threshold (rad/s) for stationary detection

// Rep detection parameters - now configurable via BLE
// Default values correspond to medium sensitivity (0.5)
float repAccelThreshold = 0.3f;           // Minimum acceleration magnitude (g's) to consider active motion
float repVelocityThreshold = 0.20f;       // Minimum velocity magnitude (m/s) to consider moving
#define REP_MIN_DURATION_MS 500           // Minimum duration for each phase (up/down) in milliseconds
#define REP_REST_TIMEOUT_MS 3000          // Time to reset rep counting if no motion detected

// Duration tracking parameters (for vibration-based activities like treadmill)
// Default value corresponds to medium sensitivity (0.5)
float vibrationAccelThreshold = 0.15f;    // Minimum acceleration magnitude (g's) to detect vibration
#define VIBRATION_TIMEOUT_MS 5000         // Time without vibration before stopping duration counter (5 seconds)

// Sensitivity scaling factors (map 0.0-1.0 sensitivity to threshold ranges)
// Higher sensitivity = lower thresholds (easier to detect)
#define REP_ACCEL_MIN 0.15f               // Most sensitive rep accel threshold
#define REP_ACCEL_MAX 0.5f                // Least sensitive rep accel threshold
#define REP_VELOCITY_MIN 0.10f            // Most sensitive rep velocity threshold
#define REP_VELOCITY_MAX 0.35f            // Least sensitive rep velocity threshold
#define VIBRATION_ACCEL_MIN 0.02f         // Most sensitive vibration threshold (ultra sensitive)
#define VIBRATION_ACCEL_MAX 0.25f         // Least sensitive vibration threshold

// See the following for generating new UUIDs:
// https://www.uuidgenerator.net/
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define ACCEL_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define GYRO_CHARACTERISTIC_UUID  "1c95d5e2-0a25-4233-8d6c-613d161c210a"
#define REP_CHARACTERISTIC_UUID   "8d3f7a9e-4b2c-11ef-9f27-0242ac120002"
#define DURATION_CHARACTERISTIC_UUID "7a8e6f9d-3c1b-42a8-9e7f-1234567890ab"
#define SENSITIVITY_CHARACTERISTIC_UUID "9c4a7f2e-5d3b-41a9-8f6e-2345678901bc"
#define BATTERY_CHARACTERISTIC_UUID "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
#define VERSION_CHARACTERISTIC_UUID "b2c3d4e5-f6a7-8901-bcde-f12345678901"

// Handles BLE connection and disconnection events
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      lastActivityTime = millis();  // Reset activity timer on connection
      DEBUG_PRINTLN("\n*** BLE CLIENT CONNECTED ***");
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      lastActivityTime = millis();  // Reset activity timer on disconnection
      DEBUG_PRINTLN("\n*** BLE CLIENT DISCONNECTED ***");
      // Restart advertising so a new client can connect
      DEBUG_PRINTLN("Restarting BLE advertising");
      pServer->getAdvertising()->start();
    }
};

// Handles write events to the rep characteristic
class RepCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        DEBUG_PRINT("BLE Write received: ");
        DEBUG_PRINTLN(value.c_str());
        
        // Reset activity timer on any BLE interaction
        lastActivityTime = millis();
        
        // Check for reset command
        if (value == "RESET" || value == "reset") {
          DEBUG_PRINTLN("Rep counter reset command received");
          repCount = 0;
          repState = REP_IDLE;
          phaseStartTime = millis();
          
          // Also reset duration tracking
          totalDuration = 0;
          isActivityActive = false;
          durationStartTime = millis();
          lastVibrationTime = millis();
          
          // Send immediate update with new count
          char repData[30];
          snprintf(repData, sizeof(repData), "Count:0,State:IDLE");
          pCharacteristic->setValue(repData);
          pCharacteristic->notify();
          DEBUG_PRINTLN("Rep counter reset to 0");
        }
        
        // Check for OTA update command
        if (value == "OTA" || value == "ota") {
          DEBUG_PRINTLN("OTA update mode requested via BLE");
          pCharacteristic->setValue("OTA:STARTING");
          pCharacteristic->notify();
          otaRequested = true;
        }
        
        // Check for calibration command
        if (value == "CALIBRATE" || value == "calibrate") {
          DEBUG_PRINTLN("Calibration requested via BLE");
          pCharacteristic->setValue("CAL:STARTING");
          pCharacteristic->notify();
          calibrationRequested = true;
        }
      }
    }
};

// Forward declarations
void saveWakeOnMovement(bool enabled);

// Handles write events to the sensitivity characteristic
class SensitivityCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        DEBUG_PRINT("BLE Sensitivity update received: ");
        DEBUG_PRINTLN(value.c_str());
        
        // Reset activity timer on any BLE interaction
        lastActivityTime = millis();
        
        // Parse format: "RepSens:value,VibSens:value,Wake:0or1"
        // Example: "RepSens:0.5,VibSens:0.7,Wake:1"
        float newRepSens = 0.5f;
        float newVibSens = 0.5f;
        bool repParsed = false;
        bool vibParsed = false;

        // Simple string parsing
        const char* str = value.c_str();
        char* repPos = strstr(str, "RepSens:");
        char* vibPos = strstr(str, "VibSens:");
        char* wakePos = strstr(str, "Wake:");
        
        if (repPos != NULL) {
          float parsedValue = atof(repPos + 8);  // Skip "RepSens:"
          if (parsedValue >= 0.0f && parsedValue <= 1.0f) {
            newRepSens = parsedValue;
            repParsed = true;
          }
        }
        
        if (vibPos != NULL) {
          float parsedValue = atof(vibPos + 8);  // Skip "VibSens:"
          if (parsedValue >= 0.0f && parsedValue <= 1.0f) {
            newVibSens = parsedValue;
            vibParsed = true;
          }
        }
        
        // Parse wake-on-movement setting
        if (wakePos != NULL) {
          int wakeValue = atoi(wakePos + 5);  // Skip "Wake:"
          bool newWake = (wakeValue != 0);
          if (newWake != wakeOnMovement) {
            wakeOnMovement = newWake;
            saveWakeOnMovement(wakeOnMovement);
          }
          DEBUG_PRINT("Wake on movement: ");
          DEBUG_PRINTLN(wakeOnMovement ? "ENABLED" : "DISABLED");
        }

        if (repParsed || vibParsed) {
          // Update thresholds based on sensitivity
          // Higher sensitivity (closer to 1.0) = lower thresholds (easier to detect)
          // Lower sensitivity (closer to 0.0) = higher thresholds (harder to detect)
          
          if (repParsed) {
            // Invert sensitivity: 1.0 sensitivity = minimum threshold, 0.0 = maximum threshold
            repAccelThreshold = REP_ACCEL_MAX - (newRepSens * (REP_ACCEL_MAX - REP_ACCEL_MIN));
            repVelocityThreshold = REP_VELOCITY_MAX - (newRepSens * (REP_VELOCITY_MAX - REP_VELOCITY_MIN));
            DEBUG_PRINT("Updated rep thresholds - Accel: ");
            DEBUG_PRINT(repAccelThreshold);
            DEBUG_PRINT("g, Velocity: ");
            DEBUG_PRINT(repVelocityThreshold);
            DEBUG_PRINTLN("m/s");
          }
          
          if (vibParsed) {
            vibrationAccelThreshold = VIBRATION_ACCEL_MAX - (newVibSens * (VIBRATION_ACCEL_MAX - VIBRATION_ACCEL_MIN));
            DEBUG_PRINT("Updated vibration threshold - Accel: ");
            DEBUG_PRINT(vibrationAccelThreshold);
            DEBUG_PRINTLN("g");
          }
          
          DEBUG_PRINTLN("Sensitivity update applied");
        } else {
          DEBUG_PRINTLN("Failed to parse sensitivity values");
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

// Save calibration offsets to persistent storage
void saveCalibrationOffsets(float gOffX, float gOffY, float gOffZ, float aOffX, float aOffY, float aOffZ) {
  preferences.begin("mpu6050", false);  // Open in read-write mode
  preferences.putFloat("gyroOffsetX", gOffX);
  preferences.putFloat("gyroOffsetY", gOffY);
  preferences.putFloat("gyroOffsetZ", gOffZ);
  preferences.putFloat("accelOffsetX", aOffX);
  preferences.putFloat("accelOffsetY", aOffY);
  preferences.putFloat("accelOffsetZ", aOffZ);
  preferences.putBool("hasOffsets", true);
  preferences.putInt("calVersion", 3);  // Version 3 = gyro + accel offsets
  preferences.end();
}

// Legacy save for backwards compatibility
void saveGyroOffsets(float offsetX, float offsetY, float offsetZ) {
  saveCalibrationOffsets(offsetX, offsetY, offsetZ, accelXoffset, accelYoffset, accelZoffset);
}

// Load calibration offsets from persistent storage
bool loadCalibrationOffsets(float* gOffX, float* gOffY, float* gOffZ, float* aOffX, float* aOffY, float* aOffZ) {
  preferences.begin("mpu6050", true);  // Open in read-only mode
  
  int calVersion = preferences.getInt("calVersion", 0);
  bool hasOffsets = preferences.getBool("hasOffsets", false);
  
  if (hasOffsets && calVersion >= 2) {
    *gOffX = preferences.getFloat("gyroOffsetX", 0.0f);
    *gOffY = preferences.getFloat("gyroOffsetY", 0.0f);
    *gOffZ = preferences.getFloat("gyroOffsetZ", 0.0f);
    
    if (calVersion >= 3) {
      // Version 3+: has accel offsets too
      *aOffX = preferences.getFloat("accelOffsetX", 0.0f);
      *aOffY = preferences.getFloat("accelOffsetY", 0.0f);
      *aOffZ = preferences.getFloat("accelOffsetZ", 0.0f);
    } else {
      // Version 2: gyro only, zero accel offsets
      *aOffX = 0.0f;
      *aOffY = 0.0f;
      *aOffZ = 0.0f;
    }
    
    preferences.end();
    return true;
  }
  
  preferences.end();
  return false;
}

// Legacy wrapper
bool loadGyroOffsets(float* offsetX, float* offsetY, float* offsetZ) {
  float aX, aY, aZ;
  return loadCalibrationOffsets(offsetX, offsetY, offsetZ, &aX, &aY, &aZ);
}

// Save wake-on-movement setting to persistent storage
void saveWakeOnMovement(bool enabled) {
  preferences.begin("settings", false);
  preferences.putBool("wakeOnMove", enabled);
  preferences.end();
  DEBUG_PRINT("Wake on movement saved: ");
  DEBUG_PRINTLN(enabled ? "ENABLED" : "DISABLED");
}

// Load wake-on-movement setting from persistent storage
void loadWakeOnMovement() {
  preferences.begin("settings", true);
  wakeOnMovement = preferences.getBool("wakeOnMove", false);  // Default: disabled
  preferences.end();
  DEBUG_PRINT("Wake on movement loaded: ");
  DEBUG_PRINTLN(wakeOnMovement ? "ENABLED" : "DISABLED");
}

// Perform gyro calibration and save results (matches tockn library behavior)
// Flash blue LED rapidly (for calibration visual feedback)
void flashLedCalibration() {
  static unsigned long lastFlash = 0;
  static bool ledOn = false;
  unsigned long now = millis();
  if (now - lastFlash >= 150) {  // Toggle every 150ms
    lastFlash = now;
    ledOn = !ledOn;
    ledcWrite(LED_PWM_CHANNEL, ledOn ? 200 : 0);
  }
}

void performCalibration() {
  DEBUG_PRINTLN("\n=== Starting Gyro + Accel Calibration ===");
  DEBUG_PRINTLN("Collecting 3000 samples...");
  DEBUG_PRINTLN("Keep device FLAT and STATIONARY!");
  
  // Accumulate both gyro and accel readings
  float gx = 0.0f, gy = 0.0f, gz = 0.0f;
  float ax_sum = 0.0f, ay_sum = 0.0f, az_sum = 0.0f;
  int16_t rx, ry, rz;
  int16_t acx, acy, acz;
  
  delay(1000);  // Wait for device to settle
  
  for (int i = 0; i < 3000; i++) {
    if (i % 1000 == 0) {
      DEBUG_PRINT("  Sample ");
      DEBUG_PRINT(i);
      DEBUG_PRINTLN("...");
    }
    mpu.getMotion6(&acx, &acy, &acz, &rx, &ry, &rz);
    
    // Flash LED during calibration
    flashLedCalibration();
    
    // Accumulate gyro (degrees/s)
    gx += ((float)rx) * GYRO_SCALE;
    gy += ((float)ry) * GYRO_SCALE;
    gz += ((float)rz) * GYRO_SCALE;
    
    // Accumulate accel (g's)
    ax_sum += ((float)acx) * ACCEL_SCALE;
    ay_sum += ((float)acy) * ACCEL_SCALE;
    az_sum += ((float)acz) * ACCEL_SCALE;
  }
  
  // Turn LED off when done
  ledcWrite(LED_PWM_CHANNEL, 0);
  
  // Calculate average gyro offsets (in degrees/s)
  gyroXoffset = gx / 3000.0f;
  gyroYoffset = gy / 3000.0f;
  gyroZoffset = gz / 3000.0f;
  
  // Calculate average accel offsets (in g's)
  // When flat and stationary, expected reading is (0, 0, 1g)
  accelXoffset = ax_sum / 3000.0f;         // Expected ~0, offset = actual
  accelYoffset = ay_sum / 3000.0f;         // Expected ~0, offset = actual
  accelZoffset = (az_sum / 3000.0f) - 1.0f; // Expected ~1g, offset = actual - 1.0
  
  DEBUG_PRINTLN("\nCalibration complete!");
  DEBUG_PRINTLN("Gyro offsets:");
  DEBUG_PRINT("  X: "); DEBUG_PRINT(gyroXoffset); DEBUG_PRINTLN(" deg/s");
  DEBUG_PRINT("  Y: "); DEBUG_PRINT(gyroYoffset); DEBUG_PRINTLN(" deg/s");
  DEBUG_PRINT("  Z: "); DEBUG_PRINT(gyroZoffset); DEBUG_PRINTLN(" deg/s");
  DEBUG_PRINTLN("Accel offsets:");
  DEBUG_PRINT("  X: "); DEBUG_PRINT(accelXoffset); DEBUG_PRINTLN(" g");
  DEBUG_PRINT("  Y: "); DEBUG_PRINT(accelYoffset); DEBUG_PRINTLN(" g");
  DEBUG_PRINT("  Z: "); DEBUG_PRINT(accelZoffset); DEBUG_PRINTLN(" g");
  
  saveCalibrationOffsets(gyroXoffset, gyroYoffset, gyroZoffset, accelXoffset, accelYoffset, accelZoffset);
  DEBUG_PRINTLN("Offsets saved to persistent storage");
  calibrationComplete = true;
  
  DEBUG_PRINTLN("Resuming normal operation in 3 seconds...");
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
  DEBUG_PRINTLN("  Configuring motion detection interrupt");
  
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
  DEBUG_PRINTLN("  Motion detection interrupt enabled");
  
  // Verify interrupt is configured
    uint8_t intStatus = mpu.getIntStatus();
  DEBUG_PRINT("  Interrupt status: 0x");
  DEBUG_PRINTF(intStatus, HEX);
  DEBUG_PRINTLN("");
  
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
  bool isMoving = (velocityMag > repVelocityThreshold) && (linearAccelMag > repAccelThreshold);
  
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
      if (isMoving && velocityMag > repVelocityThreshold * 1.5f) {
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
      if (isMoving && dominantAxisVelocity < -repVelocityThreshold * 1.2f && phaseDuration > REP_MIN_DURATION_MS) {
        repState = REP_MOVING_DOWN;
        repCount++;
        phaseStartTime = currentTime;
      }
      break;
      
    case REP_MOVING_DOWN:
      // Check for direction change to upward motion
      if (isMoving && dominantAxisVelocity > repVelocityThreshold * 1.2f && phaseDuration > REP_MIN_DURATION_MS) {
        repState = REP_MOVING_UP;
        phaseStartTime = currentTime;
      }
      break;
      
    case REP_TRANSITION:
      // Not used in current implementation
      break;
  }
}

// Duration tracking based on vibration detection (for activities like treadmill)
void trackDuration(float linearAccelMag, unsigned long currentTime) {
  // Check if vibration is detected (acceleration above threshold)
  bool vibrationDetected = (linearAccelMag > vibrationAccelThreshold);
  
  if (vibrationDetected) {
    lastVibrationTime = currentTime;
    
    // Start tracking if not already active
    if (!isActivityActive) {
      isActivityActive = true;
      durationStartTime = currentTime - (totalDuration * 1000); // Adjust start time to account for previous duration
      DEBUG_PRINTLN("Duration tracking started");
    }
    // Note: Duration is calculated only when reporting (in main loop) to avoid flickering
  } else {
    // Check for timeout (no vibration detected)
    if (isActivityActive && (currentTime - lastVibrationTime > VIBRATION_TIMEOUT_MS)) {
      // Activity stopped - calculate final duration before pausing
      totalDuration = (currentTime - durationStartTime) / 1000;
      isActivityActive = false;
      DEBUG_PRINT("Duration tracking paused at: ");
      DEBUG_PRINT(totalDuration);
      DEBUG_PRINTLN(" seconds");
    }
  }
}

// Put MPU-6050 into low power mode for sleep
void putMPUToSleep() {
  DEBUG_PRINTLN("Putting MPU into low power mode");
  
  // Configure motion detection interrupt for wake-up
  configureMPUMotionInterrupt();
  
  // Disable temperature sensor to save power
  DEBUG_PRINTLN("  Disabling temperature sensor");
  mpu.setTempSensorEnabled(false);
  
  // Disable gyroscope to save power, keep accelerometer enabled for motion detection
  DEBUG_PRINTLN("  Disabling gyroscope, keeping accelerometer active");
  mpu.setStandbyXGyroEnabled(true);
  mpu.setStandbyYGyroEnabled(true);
  mpu.setStandbyZGyroEnabled(true);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  
  // NOTE: Cycle mode disabled - testing showed it interferes with interrupt generation
  // Keep MPU6050 in normal mode with motion detection interrupt enabled
  // This uses more power (~3.6mA vs ~500μA in cycle mode) but interrupts work reliably
  DEBUG_PRINTLN("  Keeping MPU in normal mode (cycle mode disabled)");
  mpu.setWakeCycleEnabled(false);
  mpu.setSleepEnabled(false);
  
  // Wait for power mode changes to settle
  delay(100);
  DEBUG_PRINTLN("MPU low power mode configured");
  
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
  
  // Reset duration tracking state
  totalDuration = 0;
  isActivityActive = false;
  durationStartTime = millis();
  lastVibrationTime = millis();
  
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
  DEBUG_PRINTLN("Waking MPU from low power mode");
  
  // Clear any pending motion interrupt
  uint8_t intStatus = mpu.getIntStatus();
  if (intStatus & 0x40) {
    DEBUG_PRINTLN("  Motion interrupt was active");
  }
  
  // Disable cycle mode and wake up MPU-6050
  DEBUG_PRINTLN("  Disabling sleep/cycle modes");
  mpu.setWakeCycleEnabled(false);
  mpu.setSleepEnabled(false);
  
  // Enable all sensors (gyroscope and accelerometer)
  DEBUG_PRINTLN("  Enabling all sensors");
  mpu.setStandbyXGyroEnabled(false);
  mpu.setStandbyYGyroEnabled(false);
  mpu.setStandbyZGyroEnabled(false);
  mpu.setStandbyXAccelEnabled(false);
  mpu.setStandbyYAccelEnabled(false);
  mpu.setStandbyZAccelEnabled(false);
  
  // Disable motion detection interrupt during normal operation
  DEBUG_PRINTLN("  Disabling motion interrupt");
  mpu.setIntMotionEnabled(false);
  
  delay(100);  // Wait for sensor to stabilize
  DEBUG_PRINTLN("MPU wake complete");
  
}

// Update blue LED with heartbeat pattern
void updateLedHeartbeat() {
  unsigned long currentTime = millis();
  
  // Update LED every 20ms for smooth fading
  if (currentTime - lastLedUpdate >= 20) {
    lastLedUpdate = currentTime;
    
    // Heartbeat pattern: slow fade in/out
    if (ledIncreasing) {
      ledBrightness += 2;
      if (ledBrightness >= 254) {
        ledBrightness = 255;
        ledIncreasing = false;
      }
    } else {
      if (ledBrightness >= 2) {
        ledBrightness -= 2;
      } else {
        ledBrightness = 0;
        ledIncreasing = true;
      }
    }
    
    // Use LEDC to set LED brightness
    ledcWrite(LED_PWM_CHANNEL, ledBrightness);
  }
}

// Read battery voltage from ADC and calculate percentage
void readBatteryVoltage() {
  // Read calibrated millivolts directly from the pin (more accurate than analogRead on ESP32)
  uint32_t pinMilliVolts = analogReadMilliVolts(BATTERY_PIN);

  // Calculate battery voltage: V_bat = V_pin / divider_ratio
  batteryVoltage = (pinMilliVolts / 1000.0f) / BATTERY_DIVIDER_RATIO;

  // Calculate battery percentage using LiPo discharge curve approximation
  if (batteryVoltage >= BATTERY_VOLTAGE_FULL) {
    batteryPercentage = 100;
  } else if (batteryVoltage <= BATTERY_VOLTAGE_EMPTY) {
    batteryPercentage = 0;
  } else {
    // Linear interpolation between empty and full
    batteryPercentage = (int)(((batteryVoltage - BATTERY_VOLTAGE_EMPTY) / (BATTERY_VOLTAGE_FULL - BATTERY_VOLTAGE_EMPTY)) * 100.0f);
  }

  DEBUG_PRINT("Battery: ");
  DEBUG_PRINT(batteryVoltage);
  DEBUG_PRINT("V (");
  DEBUG_PRINT(batteryPercentage);
  DEBUG_PRINTLN("%)");
}

// HTML page served during OTA update mode
static const char OTA_PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pavloff Firmware Update</title>
<style>
body{font-family:sans-serif;max-width:480px;margin:40px auto;padding:0 20px;background:#1a1a2e;color:#e0e0e0}
h1{color:#0ff;font-size:1.4em}
.box{background:#16213e;border-radius:8px;padding:20px;margin:20px 0}
input[type=file]{margin:10px 0;color:#e0e0e0}
input[type=submit]{background:#0ff;color:#1a1a2e;border:none;padding:12px 24px;border-radius:4px;font-size:1em;cursor:pointer;font-weight:bold}
input[type=submit]:hover{background:#00cccc}
#progress{display:none;margin-top:15px}
.bar{background:#333;border-radius:4px;overflow:hidden;height:24px}
.bar div{background:#0ff;height:100%;width:0%;transition:width 0.3s}
.msg{margin-top:10px;padding:10px;border-radius:4px;display:none}
.ok{background:#0a3d0a;color:#4f4}.err{background:#3d0a0a;color:#f44}
</style>
</head>
<body>
<h1>Pavloff Firmware Update</h1>
<div class="box">
<p>Select a firmware .bin file to upload:</p>
<form id="f" method="POST" action="/update" enctype="multipart/form-data">
<input type="file" name="firmware" accept=".bin" required><br>
<input type="submit" value="Upload &amp; Install">
</form>
<div id="progress"><div class="bar"><div id="pbar"></div></div><span id="ptxt">0%</span></div>
<div id="ok" class="msg ok">Update successful! Rebooting...</div>
<div id="err" class="msg err">Update failed. Please try again.</div>
</div>
<script>
document.getElementById('f').addEventListener('submit',function(e){
  e.preventDefault();
  var f=new FormData(this);
  var x=new XMLHttpRequest();
  document.getElementById('progress').style.display='block';
  x.upload.addEventListener('progress',function(e){
    if(e.lengthComputable){
      var p=Math.round(e.loaded/e.total*100);
      document.getElementById('pbar').style.width=p+'%';
      document.getElementById('ptxt').textContent=p+'%';
    }
  });
  x.onreadystatechange=function(){
    if(x.readyState==4){
      if(x.status==200){
        document.getElementById('ok').style.display='block';
      }else{
        document.getElementById('err').style.display='block';
      }
    }
  };
  x.open('POST','/update',true);
  x.send(f);
});
</script>
</body>
</html>
)rawliteral";

// Enter OTA update mode: start WiFi AP and web server, handle firmware upload
void enterOTAMode() {
  DEBUG_PRINTLN("\n=== Entering OTA Update Mode ===");

  // Shut down BLE to free memory for WiFi
  DEBUG_PRINTLN("Shutting down BLE...");
  BLEDevice::deinit(true);
  delay(500);

  // Start WiFi Access Point
  DEBUG_PRINTLN("Starting WiFi AP...");
  WiFi.mode(WIFI_AP);
  WiFi.softAP(OTA_AP_SSID, OTA_AP_PASSWORD);
  delay(500);
  DEBUG_PRINT("AP IP address: ");
  DEBUG_PRINTLN(WiFi.softAPIP());

  // Create web server on port 80
  WebServer server(80);

  // Enable CORS for all responses
  server.enableCORS(true);

  // Serve the upload page
  server.on("/", HTTP_GET, [&server]() {
    server.send_P(200, "text/html", OTA_PAGE);
  });

  // Serve firmware version as JSON
  server.on("/version", HTTP_GET, [&server]() {
    char json[64];
    snprintf(json, sizeof(json), "{\"version\":\"%s\"}", FIRMWARE_VERSION);
    server.send(200, "application/json", json);
  });

  // Handle firmware upload
  server.on("/update", HTTP_POST,
    // Response handler (called after upload completes)
    [&server]() {
      if (Update.hasError()) {
        server.send(500, "text/plain", "Update failed");
      } else {
        server.send(200, "text/plain", "Update successful");
        delay(1000);
        ESP.restart();
      }
    },
    // Upload handler (called for each chunk)
    [&server]() {
      HTTPUpload& upload = server.upload();
      if (upload.status == UPLOAD_FILE_START) {
        DEBUG_PRINT("OTA file: ");
        DEBUG_PRINTLN(upload.filename.c_str());
        if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
          DEBUG_PRINTLN("Update.begin() failed");
        }
      } else if (upload.status == UPLOAD_FILE_WRITE) {
        if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
          DEBUG_PRINTLN("Update.write() failed");
        }
      } else if (upload.status == UPLOAD_FILE_END) {
        if (Update.end(true)) {
          DEBUG_PRINT("Update success, total size: ");
          DEBUG_PRINTLN(upload.totalSize);
        } else {
          DEBUG_PRINTLN("Update.end() failed");
        }
      }
    }
  );

  server.begin();
  DEBUG_PRINTLN("OTA web server started");
  DEBUG_PRINT("Connect to WiFi: ");
  DEBUG_PRINTLN(OTA_AP_SSID);
  DEBUG_PRINT("Then visit: http://");
  DEBUG_PRINTLN(WiFi.softAPIP());

  // Rapid LED blink to indicate OTA mode
  unsigned long lastBlink = 0;
  bool ledOn = false;

  // Run the server until update completes or device is reset
  while (true) {
    server.handleClient();

    // Fast blink LED to indicate OTA mode
    unsigned long now = millis();
    if (now - lastBlink >= 200) {
      lastBlink = now;
      ledOn = !ledOn;
      ledcWrite(LED_PWM_CHANNEL, ledOn ? 128 : 0);
    }

    delay(2);
  }
}

// Enter deep sleep mode
void enterDeepSleep() {
  DEBUG_PRINTLN("\n=== Entering Deep Sleep ===");

  // Turn off blue LED before sleep
  // Must detach from LEDC and drive LOW as regular GPIO, then hold the state,
  // otherwise the pin floats when the digital domain powers down and the LED stays on.
  ledcWrite(LED_PWM_CHANNEL, 0);
  ledcDetachPin(BLUE_LED_PIN);
  pinMode(BLUE_LED_PIN, OUTPUT);
  digitalWrite(BLUE_LED_PIN, LOW);
  gpio_hold_en((gpio_num_t)BLUE_LED_PIN);
  gpio_deep_sleep_hold_en();

  if (wakeOnMovement) {
    // Put MPU-6050 into low power mode with motion interrupt configured
    DEBUG_PRINTLN("Configuring MPU for motion wake-up");
    putMPUToSleep();

    // Clear any pending interrupt status before sleep
    uint8_t intStatus = mpu.getIntStatus();
    DEBUG_PRINT("MPU interrupt status before sleep: 0x");
    DEBUG_PRINTF(intStatus, HEX);
    DEBUG_PRINTLN("");

    // Wait for MPU-6050 to enter low power mode and interrupt to be ready
    delay(200);

    // Check GPIO 18 level before sleep
    DEBUG_PRINT("GPIO 18 level before sleep: ");
    DEBUG_PRINTLN(digitalRead(INT_PIN));
  } else {
    // Put MPU fully to sleep to minimize power consumption
    DEBUG_PRINTLN("Wake on movement DISABLED - putting MPU to full sleep");
    mpu.setSleepEnabled(true);
    delay(100);
  }

  // Disable BLE and wait for clean shutdown
  DEBUG_PRINTLN("Shutting down BLE");
  BLEDevice::deinit(true);
  delay(100);  // Allow time for BLE to fully power down

  // Explicitly disable WiFi radio to save power (can consume 20-100mA if left on)
  // Note: These may fail if WiFi was never started, which is expected and harmless
  DEBUG_PRINTLN("Shutting down WiFi (if active)");
  esp_err_t wifi_err = esp_wifi_stop();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    DEBUG_PRINT("WiFi stop error: ");
    DEBUG_PRINTLN(wifi_err);
  }

  wifi_err = esp_wifi_deinit();
  if (wifi_err != ESP_OK && wifi_err != ESP_ERR_WIFI_NOT_INIT) {
    DEBUG_PRINT("WiFi deinit error: ");
    DEBUG_PRINTLN(wifi_err);
  }

  // Wait for all radio shutdowns to complete
  delay(200);

  // Disable unused peripherals to minimize power consumption
  DEBUG_PRINTLN("Disabling unused peripherals");
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_SLOW_MEM, ESP_PD_OPTION_OFF);
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_FAST_MEM, ESP_PD_OPTION_OFF);

  if (wakeOnMovement) {
    // Configure GPIO interrupt wake-up on INT_PIN (GPIO 18) for ESP32-S3 deep sleep
    // Motion interrupt from MPU6050 will wake the ESP32
    uint64_t gpio_mask = (1ULL << INT_PIN);

    // Enable ext1 wakeup on GPIO 18 with ANY_HIGH mode
    DEBUG_PRINT("Configuring wake on GPIO ");
    DEBUG_PRINT(INT_PIN);
    DEBUG_PRINTLN(" (motion interrupt)");
    esp_sleep_enable_ext1_wakeup(gpio_mask, ESP_EXT1_WAKEUP_ANY_HIGH);

    // Configure internal pull-down on the GPIO
    gpio_pulldown_en((gpio_num_t)INT_PIN);
    gpio_pullup_dis((gpio_num_t)INT_PIN);

    DEBUG_PRINTLN("*** ENTERING DEEP SLEEP NOW ***");
    DEBUG_PRINTLN("Device will wake on motion detection");
  } else {
    // No wake source configured - only hardware reset will wake the device
    DEBUG_PRINTLN("*** ENTERING DEEP SLEEP NOW ***");
    DEBUG_PRINTLN("Wake on movement DISABLED - only hardware reset will wake device");
  }

  delay(100);  // Ensure serial output completes

  // Enter deep sleep
  esp_deep_sleep_start();
}

void setup() {
  // Initialize battery voltage ADC
  analogReadResolution(12);  // 12-bit resolution (0-4095)

  // Release GPIO hold from deep sleep so LED pin can be reused by LEDC
  gpio_hold_dis((gpio_num_t)BLUE_LED_PIN);

  // Initialize blue LED with LEDC PWM and turn on immediately to signal wake
  ledcSetup(LED_PWM_CHANNEL, LED_PWM_FREQ, LED_PWM_RESOLUTION);
  ledcAttachPin(BLUE_LED_PIN, LED_PWM_CHANNEL);
  ledcWrite(LED_PWM_CHANNEL, 200);  // LED on immediately to show board is awake
  
  #if ENABLE_SERIAL_DEBUG
  // Initialize Serial communication for debugging
  Serial.begin(115200);
  
  // For ESP32-S3 with USB CDC, we need to wait for USB connection
  // This ensures serial output is actually sent and visible
  // Wait up to 3 seconds for USB CDC connection
  #if ARDUINO_USB_CDC_ON_BOOT
  for(int i = 0; i < 30 && !Serial; i++) {
    delay(100);  // Wait for USB CDC connection
  }
  #else
  delay(1000);  // Wait for hardware UART to initialize
  #endif
  #endif  // ENABLE_SERIAL_DEBUG
  
  DEBUG_PRINTLN("\n\n=== Pavloff Workout Sensor Starting ===");
  DEBUG_PRINTLN("Firmware: ESP32-S3 Motion Tracking");
  DEBUG_PRINT("CPU Frequency: ");
  DEBUG_PRINT(getCpuFrequencyMhz());
  DEBUG_PRINTLN(" MHz");
  
  // Disable WiFi radio immediately to save power (not needed for BLE-only operation)
  // WiFi can consume 20-100mA even when not actively used
  // Note: esp_wifi_stop() may fail if WiFi was never started, which is expected and harmless
  DEBUG_PRINTLN("\n--- Disabling WiFi ---");
  esp_err_t err = esp_wifi_stop();
  if (err == ESP_OK) {
    DEBUG_PRINTLN("WiFi stopped successfully");
  } else if (err == ESP_ERR_WIFI_NOT_INIT) {
    DEBUG_PRINTLN("WiFi was not initialized (expected)");
  } else {
    DEBUG_PRINT("WiFi stop failed with error: ");
    DEBUG_PRINTLN(err);
  }
  
  // Configure power optimizations
  DEBUG_PRINTLN("\n--- Configuring Power Optimizations ---");
  configurePowerOptimizations();
  DEBUG_PRINT("CPU Frequency after optimization: ");
  DEBUG_PRINT(getCpuFrequencyMhz());
  DEBUG_PRINTLN(" MHz");
  
  // Check wake-up reason
  DEBUG_PRINTLN("\n--- Checking Wake-Up Reason ---");
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    DEBUG_PRINTLN("Wake-up source: MOTION INTERRUPT (GPIO 18)");
    // Motion detected - continue with normal startup
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    DEBUG_PRINTLN("Wake-up source: POWER ON or RESET");
  } else {
    DEBUG_PRINT("Wake-up source: ");
    DEBUG_PRINTLN(wakeup_reason);
  }

  // --- MPU-6050 Setup ---
  DEBUG_PRINTLN("\n--- Initializing MPU-6050 ---");
  DEBUG_PRINT("I2C SDA Pin: ");
  DEBUG_PRINTLN(SDA_PIN);
  DEBUG_PRINT("I2C SCL Pin: ");
  DEBUG_PRINTLN(SCL_PIN);
  DEBUG_PRINT("INT Pin: ");
  DEBUG_PRINTLN(INT_PIN);
  
  Wire.begin(SDA_PIN, SCL_PIN); // SDA, SCL
  DEBUG_PRINTLN("I2C bus initialized");
  
  // If waking from deep sleep, restore MPU from low power mode FIRST
  // This must be done before initialize() to ensure proper state
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    DEBUG_PRINTLN("Restoring MPU from low power mode...");
    
    // Clear any pending motion interrupt
    uint8_t intStatus = mpu.getIntStatus();
    if (intStatus & 0x40) {
      DEBUG_PRINTLN("Motion interrupt was pending");
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
    DEBUG_PRINTLN("MPU restored from low power mode");
  }
  
  // Initialize MPU-6050 (now that it's in proper state)
  DEBUG_PRINTLN("Calling mpu.initialize()...");
  mpu.initialize();
  DEBUG_PRINTLN("MPU-6050 initialization complete");
  
  // Test connection
  DEBUG_PRINT("Testing MPU-6050 connection... ");
  if (mpu.testConnection()) {
    DEBUG_PRINTLN("SUCCESS! MPU-6050 connection verified");
  } else {
    DEBUG_PRINTLN("FAILED! MPU-6050 not responding");
    DEBUG_PRINTLN("Check I2C connections and power supply");
  }
  
  // Set ranges: ±2g for accelerometer, ±500°/s for gyroscope (matching tockn library)
  DEBUG_PRINTLN("Configuring MPU-6050 ranges...");
  mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_2);
  DEBUG_PRINTLN("  Accelerometer: ±2g");
  mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);
  DEBUG_PRINTLN("  Gyroscope: ±500°/s");
  
  // Ensure all interrupts are disabled for normal operation
  DEBUG_PRINTLN("Disabling interrupts for normal operation");
  mpu.setIntEnabled(0x00);
  mpu.setIntFreefallEnabled(false);
  mpu.setIntMotionEnabled(false);
  mpu.setIntZeroMotionEnabled(false);
  
  // Reset DHPF to ensure clean accelerometer readings
  mpu.setDHPFMode(MPU6050_DHPF_RESET);
  delay(10);
  mpu.setDHPFMode(MPU6050_DHPF_HOLD);  // Hold mode for normal operation (no high-pass filtering)
  DEBUG_PRINTLN("DHPF configured to HOLD mode");
  
  
  // Try to load stored calibration offsets
  DEBUG_PRINTLN("\n--- Loading Calibration ---");
  if (loadCalibrationOffsets(&gyroXoffset, &gyroYoffset, &gyroZoffset, &accelXoffset, &accelYoffset, &accelZoffset)) {
    DEBUG_PRINTLN("Loaded stored calibration offsets:");
    DEBUG_PRINT("  Gyro X: "); DEBUG_PRINT(gyroXoffset); DEBUG_PRINTLN(" deg/s");
    DEBUG_PRINT("  Gyro Y: "); DEBUG_PRINT(gyroYoffset); DEBUG_PRINTLN(" deg/s");
    DEBUG_PRINT("  Gyro Z: "); DEBUG_PRINT(gyroZoffset); DEBUG_PRINTLN(" deg/s");
    DEBUG_PRINT("  Accel X: "); DEBUG_PRINT(accelXoffset); DEBUG_PRINTLN(" g");
    DEBUG_PRINT("  Accel Y: "); DEBUG_PRINT(accelYoffset); DEBUG_PRINTLN(" g");
    DEBUG_PRINT("  Accel Z: "); DEBUG_PRINT(accelZoffset); DEBUG_PRINTLN(" g");
    calibrationComplete = true;
  } else {
    // No stored offsets - perform calibration immediately on startup
    DEBUG_PRINTLN("No stored calibration found");
    DEBUG_PRINTLN("Starting calibration in 2 seconds...");
    DEBUG_PRINTLN("*** KEEP DEVICE FLAT AND STATIONARY ***");
    calibrationComplete = false;
    gyroXoffset = 0.0f;
    gyroYoffset = 0.0f;
    gyroZoffset = 0.0f;
    accelXoffset = 0.0f;
    accelYoffset = 0.0f;
    accelZoffset = 0.0f;
    delay(2000);  // Give user time to read message and stabilize device
    performCalibration();
  }
  

  // Load wake-on-movement setting from persistent storage
  DEBUG_PRINTLN("\n--- Loading Wake on Movement Setting ---");
  loadWakeOnMovement();

  // Reset all state variables (critical after wake from sleep)
  DEBUG_PRINTLN("\n--- Resetting State Variables ---");
  resetStateVariables();
  DEBUG_PRINTLN("State variables reset");
  
  // Initialize activity timer
  lastActivityTime = millis();
  DEBUG_PRINT("Activity timer initialized: ");
  DEBUG_PRINT(lastActivityTime);
  DEBUG_PRINTLN(" ms");


  // --- BLE Setup ---
  DEBUG_PRINTLN("\n--- Initializing BLE ---");
  // Create the BLE Device
  DEBUG_PRINTLN("Creating BLE device: 'Pavloff Workout Sensor'");
  BLEDevice::init("Pavloff Workout Sensor");
  
  // Set BLE power to minimum (can increase if needed for range)
  // ESP_PWR_LVL_N12 to ESP_PWR_LVL_P9 (lower = less power)
  DEBUG_PRINTLN("Setting BLE power level to 0 dBm");
  BLEDevice::setPower(ESP_PWR_LVL_N0, ESP_BLE_PWR_TYPE_DEFAULT);

  // Create the BLE Server
  DEBUG_PRINTLN("Creating BLE server");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  DEBUG_PRINTLN("BLE server callbacks configured");

  // Create the BLE Service
  DEBUG_PRINT("Creating BLE service with UUID: ");
  DEBUG_PRINTLN(SERVICE_UUID);
  // Allocate enough handles for all characteristics + descriptors
  // Each characteristic needs 3 handles (declaration + value + BLE2902 descriptor)
  // 7 characteristics × 3 = 21 handles + 1 service declaration = 22 minimum
  // Using 30 for headroom
  BLEService *pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);

  // Create a BLE Characteristic for Accelerometer Data
  DEBUG_PRINTLN("Creating Accelerometer characteristic");
  pAccelCharacteristic = pService->createCharacteristic(
                      ACCEL_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pAccelCharacteristic->addDescriptor(new BLE2902());
  DEBUG_PRINTLN("  Accelerometer characteristic configured");

  // Create a BLE Characteristic for Gyroscope Data
  DEBUG_PRINTLN("Creating Gyroscope characteristic");
  pGyroCharacteristic = pService->createCharacteristic(
                      GYRO_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pGyroCharacteristic->addDescriptor(new BLE2902());
  DEBUG_PRINTLN("  Gyroscope characteristic configured");

  // Create a BLE Characteristic for Rep Count
  DEBUG_PRINTLN("Creating Rep Counter characteristic");
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
  DEBUG_PRINTLN("  Rep Counter characteristic configured");

  // Create a BLE Characteristic for Duration Tracking
  DEBUG_PRINTLN("Creating Duration characteristic");
  pDurationCharacteristic = pService->createCharacteristic(
                      DURATION_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pDurationCharacteristic->addDescriptor(new BLE2902());
  pDurationCharacteristic->setCallbacks(new RepCharacteristicCallbacks()); // Reuse same callbacks for RESET
  // Set initial value before starting service
  pDurationCharacteristic->setValue("Duration:0,State:IDLE");
  DEBUG_PRINTLN("  Duration characteristic configured");

  // Create a BLE Characteristic for Sensitivity Settings
  DEBUG_PRINTLN("Creating Sensitivity characteristic");
  pSensitivityCharacteristic = pService->createCharacteristic(
                      SENSITIVITY_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE
                    );
  pSensitivityCharacteristic->addDescriptor(new BLE2902());
  pSensitivityCharacteristic->setCallbacks(new SensitivityCharacteristicCallbacks());
  // Set initial value before starting service
  pSensitivityCharacteristic->setValue("RepSens:0.5,VibSens:0.5");
  DEBUG_PRINTLN("  Sensitivity characteristic configured");

  // Create a BLE Characteristic for Battery Voltage
  DEBUG_PRINTLN("Creating Battery characteristic");
  pBatteryCharacteristic = pService->createCharacteristic(
                      BATTERY_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pBatteryCharacteristic->addDescriptor(new BLE2902());
  // Read initial battery voltage and set value
  readBatteryVoltage();
  char batteryData[40];
  snprintf(batteryData, sizeof(batteryData), "Voltage:%.2f,Percent:%d", batteryVoltage, batteryPercentage);
  pBatteryCharacteristic->setValue(batteryData);
  DEBUG_PRINTLN("  Battery characteristic configured");

  // Create a BLE Characteristic for Firmware Version (read-only)
  DEBUG_PRINTLN("Creating Version characteristic");
  pVersionCharacteristic = pService->createCharacteristic(
                      VERSION_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ
                    );
  pVersionCharacteristic->setValue(FIRMWARE_VERSION);
  DEBUG_PRINTLN("  Version characteristic configured");

  // Start the service
  DEBUG_PRINTLN("Starting BLE service");
  pService->start();

  // Start advertising
  DEBUG_PRINTLN("Starting BLE advertising");
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  pAdvertising->start();
  DEBUG_PRINTLN("BLE advertising started");
  
  DEBUG_PRINTLN("\n=== Setup Complete ===");
  DEBUG_PRINTLN("Device is ready and advertising");
  DEBUG_PRINTLN("Entering main loop...\n");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Update blue LED heartbeat pattern
  updateLedHeartbeat();
  
  // Periodic diagnostic output every 2 seconds
  static unsigned long lastDiagnosticTime = 0;
  if (currentTime - lastDiagnosticTime >= 2000) {
    lastDiagnosticTime = currentTime;
    DEBUG_PRINTLN("\n--- Status Update ---");
    DEBUG_PRINT("Uptime: ");
    DEBUG_PRINT(currentTime / 1000);
    DEBUG_PRINTLN(" seconds");
    DEBUG_PRINT("BLE Connected: ");
    DEBUG_PRINTLN(deviceConnected ? "YES" : "NO");
    DEBUG_PRINT("Rep Count: ");
    DEBUG_PRINTLN(repCount);
    DEBUG_PRINT("Rep State: ");
    switch(repState) {
      case REP_IDLE: DEBUG_PRINTLN("IDLE"); break;
      case REP_MOVING_UP: DEBUG_PRINTLN("MOVING_UP"); break;
      case REP_MOVING_DOWN: DEBUG_PRINTLN("MOVING_DOWN"); break;
      case REP_TRANSITION: DEBUG_PRINTLN("TRANSITION"); break;
      default: DEBUG_PRINTLN("UNKNOWN"); break;
    }
    DEBUG_PRINT("Time until sleep: ");
    DEBUG_PRINT((IDLE_TIMEOUT_MS - (currentTime - lastActivityTime)) / 1000);
    DEBUG_PRINTLN(" seconds");
  }
  
  // Check if OTA mode was requested via BLE
  if (otaRequested) {
    otaRequested = false;
    enterOTAMode();
    // enterOTAMode() never returns (runs server loop until reboot)
  }
  
  // Check if calibration was requested via BLE
  if (calibrationRequested) {
    calibrationRequested = false;
    DEBUG_PRINTLN("Starting BLE-requested calibration...");
    performCalibration();
    lastActivityTime = millis();  // Reset sleep timer after calibration
  }
  
  // Check for idle timeout and enter deep sleep
  if (currentTime - lastActivityTime > IDLE_TIMEOUT_MS) {
    DEBUG_PRINTLN("\n*** IDLE TIMEOUT - ENTERING DEEP SLEEP ***");
    enterDeepSleep();
    // This line will never be reached as deep sleep resets the device
  }
  
  // Warn when approaching sleep (5 seconds before)
  static bool warningPrinted = false;
  if (currentTime - lastActivityTime > (IDLE_TIMEOUT_MS - 5000) && !warningPrinted) {
    DEBUG_PRINTLN("\n*** WARNING: Deep sleep in 5 seconds ***");
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
  float rawAccelX = ax * ACCEL_SCALE - accelXoffset;  // in g's, offset-corrected
  float rawAccelY = ay * ACCEL_SCALE - accelYoffset;
  float rawAccelZ = az * ACCEL_SCALE - accelZoffset;
  
  // Compute raw magnitude for stationary detection (before filtering distorts it)
  float rawAccelMagForSleep = sqrt(rawAccelX*rawAccelX + rawAccelY*rawAccelY + rawAccelZ*rawAccelZ);
  
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
    // Use raw (pre-filter) accel magnitude — the EMA filter starts at 0 and
    // takes many iterations to converge to 1g, causing false "not stationary"
    float gyroMag = sqrt(rawGyroX*rawGyroX + rawGyroY*rawGyroY + rawGyroZ*rawGyroZ);
    bool isStationary = (abs(rawAccelMagForSleep - 1.0f) < ACCEL_STATIONARY_THRESHOLD) && (gyroMag < GYRO_STATIONARY_THRESHOLD);

    // Debug: Print stationary detection values every 2 seconds
    static unsigned long lastStationaryDebug = 0;
    if (currentTime - lastStationaryDebug >= 2000) {
      lastStationaryDebug = currentTime;
      DEBUG_PRINT("SLEEP DEBUG | rawAccelMag=");
      DEBUG_PRINTF(rawAccelMagForSleep, 4);
      DEBUG_PRINT(" dev=");
      DEBUG_PRINTF(abs(rawAccelMagForSleep - 1.0f), 4);
      DEBUG_PRINT(" gyroMag=");
      DEBUG_PRINTF(gyroMag, 4);
      DEBUG_PRINT(" isStationary=");
      DEBUG_PRINT(isStationary ? "YES" : "NO");
      DEBUG_PRINT(" calibDone=");
      DEBUG_PRINTLN(calibrationComplete ? "YES" : "NO");
    }

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
    
    // Track duration for vibration-based activities (like treadmill)
    trackDuration(linearAccelMag, currentTime);
    
    // Update activity timer if there's motion (not stationary)
    // Note: BLE connection state does not prevent sleep - only motion does
    if (!isStationary) {
      lastActivityTime = currentTime;
    }
    
    // Also update activity timer if stationary and waiting for initial calibration
    // This prevents sleep while accumulating stillness time for calibration
    // Cap at 60 seconds to avoid blocking sleep indefinitely
    if (isStationary && !calibrationComplete && wasStationary
        && (currentTime - lastStillTime < 60000)) {
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
    
    // --- Prepare and Send Duration Data ---
    // Calculate current duration if activity is active (only when reporting to avoid flickering)
    unsigned long currentDuration = totalDuration;
    if (isActivityActive) {
      currentDuration = (currentTime - durationStartTime) / 1000;
    }
    
    char durationData[40];
    const char* durationStateStr = isActivityActive ? "ACTIVE" : "IDLE";
    snprintf(durationData, sizeof(durationData), "Duration:%lu,State:%s", currentDuration, durationStateStr);
    
    // Set the characteristic value and notify the client
    pDurationCharacteristic->setValue(durationData);
    pDurationCharacteristic->notify();

    // --- Read and Send Battery Voltage Data ---
    if (currentTime - lastBatteryReadTime >= BATTERY_READ_INTERVAL_MS) {
      lastBatteryReadTime = currentTime;
      readBatteryVoltage();
    }

    char batteryData[40];
    snprintf(batteryData, sizeof(batteryData), "Voltage:%.2f,Percent:%d", batteryVoltage, batteryPercentage);
    pBatteryCharacteristic->setValue(batteryData);
    pBatteryCharacteristic->notify();
  }

  // Short delay for high-frequency position calculation
  delay(INTEGRATION_INTERVAL_MS);
}
