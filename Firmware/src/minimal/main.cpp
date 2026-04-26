/**
 * Pavloff Board — Minimal Code Example
 *
 * This file is a stripped-down starting point for re-using the Pavloff PCB
 * in a new project. All hardware pin definitions are preserved and two key
 * board-level features are demonstrated:
 *
 *   1. Battery voltage reading  — ADC on GPIO 7 through a 27 k / 68 k divider
 *   2. Wake-on-motion           — MPU-6050 motion interrupt wakes the ESP32-S3
 *                                 from deep sleep via GPIO 18 (EXT1 wake-up)
 *
 * Build with PlatformIO:
 *   pio run -e minimal -t upload
 */

#include <Arduino.h>
#include <Wire.h>
#include "MPU6050.h"
#include <Preferences.h>
#include <esp_sleep.h>

// ---------------------------------------------------------------------------
// Pin definitions  (must match PCB layout)
// ---------------------------------------------------------------------------
#define SDA_PIN       8   // I2C SDA — MPU-6050
#define SCL_PIN       9   // I2C SCL — MPU-6050
#define INT_PIN      18   // MPU-6050 INT → EXT1 wake-up source
#define BATTERY_PIN   7   // ADC input for battery voltage monitor
#define BLUE_LED_PIN 47   // Blue status LED (active HIGH)

// ---------------------------------------------------------------------------
// Battery voltage monitor
// Voltage divider: R1 = 27 kΩ (battery+ → pin), R2 = 68 kΩ (pin → GND)
// ---------------------------------------------------------------------------
const float BATTERY_R1             = 27000.0f;
const float BATTERY_R2             = 68000.0f;
const float BATTERY_DIVIDER_RATIO  = BATTERY_R2 / (BATTERY_R1 + BATTERY_R2);

#define BATTERY_VOLTAGE_FULL  4.20f  // 100 % — fully charged LiPo
#define BATTERY_VOLTAGE_EMPTY 3.00f  //   0 % — cut-off voltage

// How often to refresh the battery reading in the main loop (ms)
#define BATTERY_READ_INTERVAL_MS 5000

// ---------------------------------------------------------------------------
// Demo: how long to stay awake before entering deep sleep (ms)
// ---------------------------------------------------------------------------
#define AWAKE_DURATION_MS 15000

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
MPU6050    mpu;
Preferences preferences;

float batteryVoltage  = 0.0f;
int   batteryPercent  = 0;

// Whether to use the MPU-6050 motion interrupt as a wake source.
// Toggle via the `wakeOnMove` key in the "settings" Preferences namespace,
// or hard-code to `true` below.
bool wakeOnMovement = true;

// ---------------------------------------------------------------------------
// Battery reading
// ---------------------------------------------------------------------------
void readBatteryVoltage() {
    // analogReadMilliVolts() uses the ESP32's built-in ADC calibration for
    // better accuracy than raw analogRead().
    uint32_t pinMilliVolts = analogReadMilliVolts(BATTERY_PIN);

    // Recover full battery voltage from the divided-down reading.
    batteryVoltage = (pinMilliVolts / 1000.0f) / BATTERY_DIVIDER_RATIO;

    // Map to 0–100 % with a simple linear approximation.
    if (batteryVoltage >= BATTERY_VOLTAGE_FULL) {
        batteryPercent = 100;
    } else if (batteryVoltage <= BATTERY_VOLTAGE_EMPTY) {
        batteryPercent = 0;
    } else {
        batteryPercent = (int)(((batteryVoltage - BATTERY_VOLTAGE_EMPTY) /
                                (BATTERY_VOLTAGE_FULL - BATTERY_VOLTAGE_EMPTY)) * 100.0f);
    }

    Serial.printf("Battery: %.2f V  (%d %%)\n", batteryVoltage, batteryPercent);
}

// ---------------------------------------------------------------------------
// MPU-6050 — configure motion-detection interrupt
// Called just before deep sleep so the sensor can trigger a wake-up.
// ---------------------------------------------------------------------------
void configureMPUMotionInterrupt() {
    // Start from a clean interrupt state.
    mpu.setIntEnabled(0x00);
    mpu.setIntFreefallEnabled(false);
    mpu.setIntMotionEnabled(false);
    mpu.setIntZeroMotionEnabled(false);

    // Interrupt pin: active HIGH, push-pull, latched, cleared on any read.
    mpu.setInterruptMode(false);       // false = active HIGH
    mpu.setInterruptDrive(false);      // false = push-pull
    mpu.setInterruptLatch(true);       // hold until cleared
    mpu.setInterruptLatchClear(true);  // clear on any register read

    // Motion threshold: 1 LSB = 2 mg @ ±2 g range.
    // 16 → ~32 mg — sensitive enough to detect a light tap.
    mpu.setMotionDetectionThreshold(16);
    // Duration: motion must persist for at least 5 ms to avoid false triggers.
    mpu.setMotionDetectionDuration(5);

    // Reset the Digital High-Pass Filter to remove any DC bias, then switch
    // to a 5 Hz high-pass so only dynamic (motion) events pass through.
    mpu.setDHPFMode(MPU6050_DHPF_RESET);
    delay(10);
    mpu.setDHPFMode(MPU6050_DHPF_5);

    mpu.setIntMotionEnabled(true);
}

// ---------------------------------------------------------------------------
// Restore the MPU-6050 after waking from motion-interrupt sleep
// ---------------------------------------------------------------------------
void wakeupMPU() {
    mpu.getIntStatus();               // reading status register clears interrupt
    mpu.setIntMotionEnabled(false);
    mpu.setWakeCycleEnabled(false);
    mpu.setSleepEnabled(false);

    // Re-enable all axes (they may have been placed in standby before sleep).
    mpu.setStandbyXGyroEnabled(false);
    mpu.setStandbyYGyroEnabled(false);
    mpu.setStandbyZGyroEnabled(false);
    mpu.setStandbyXAccelEnabled(false);
    mpu.setStandbyYAccelEnabled(false);
    mpu.setStandbyZAccelEnabled(false);

    mpu.setTempSensorEnabled(true);
    delay(200);  // allow sensor to stabilise
}

// ---------------------------------------------------------------------------
// Enter deep sleep
// If wakeOnMovement is true, the MPU-6050 motion interrupt (INT_PIN / GPIO 18)
// is used as the EXT1 wake source.  Otherwise only a hardware reset wakes it.
// ---------------------------------------------------------------------------
void enterDeepSleep() {
    Serial.println("\nEntering deep sleep...");
    delay(10);  // flush serial

    // Drive LED low and hold the state so it stays off during sleep.
    pinMode(BLUE_LED_PIN, OUTPUT);
    digitalWrite(BLUE_LED_PIN, LOW);
    gpio_hold_en((gpio_num_t)BLUE_LED_PIN);
    gpio_deep_sleep_hold_en();

    if (wakeOnMovement) {
        Serial.println("Wake source: motion interrupt (GPIO 18)");

        // Configure the MPU-6050 for low-power motion detection:
        // keep the accelerometer running, put the gyroscope in standby.
        configureMPUMotionInterrupt();
        mpu.setTempSensorEnabled(false);
        mpu.setStandbyXGyroEnabled(true);
        mpu.setStandbyYGyroEnabled(true);
        mpu.setStandbyZGyroEnabled(true);
        mpu.setStandbyXAccelEnabled(false);
        mpu.setStandbyYAccelEnabled(false);
        mpu.setStandbyZAccelEnabled(false);
        mpu.setWakeCycleEnabled(false);
        mpu.setSleepEnabled(false);

        // Clear any stale interrupt before sleeping.
        mpu.getIntStatus();
        delay(200);

        // Configure ESP32-S3 EXT1 wake-up on GPIO 18 (HIGH = interrupt asserted).
        uint64_t wakeMask = (1ULL << INT_PIN);
        esp_sleep_enable_ext1_wakeup(wakeMask, ESP_EXT1_WAKEUP_ANY_HIGH);
        gpio_pulldown_en((gpio_num_t)INT_PIN);
        gpio_pullup_dis((gpio_num_t)INT_PIN);
    } else {
        Serial.println("Wake source: hardware reset only");
        mpu.setSleepEnabled(true);
    }

    delay(100);  // ensure serial output has flushed
    esp_deep_sleep_start();
    // Execution never reaches here — deep sleep triggers a full reset.
}

// ---------------------------------------------------------------------------
// setup()
// ---------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);

    // On ESP32-S3 with USB CDC, wait up to 3 s (30 × 100 ms) for the host
    // to enumerate the port before sending serial output.
#if ARDUINO_USB_CDC_ON_BOOT
    for (int i = 0; i < 30 && !Serial; i++) {
        delay(100);
    }
#else
    delay(500);
#endif

    Serial.println("\n=== Pavloff Minimal Example ===");

    // 12-bit ADC resolution for best battery reading accuracy.
    analogReadResolution(12);

    // Release any GPIO hold that was set before the previous deep sleep so
    // the LED pin can be driven normally.
    gpio_hold_dis((gpio_num_t)BLUE_LED_PIN);
    pinMode(BLUE_LED_PIN, OUTPUT);
    digitalWrite(BLUE_LED_PIN, HIGH);  // LED on — board is awake

    // ------------------------------------------------------------------
    // Load persisted settings
    // ------------------------------------------------------------------
    preferences.begin("settings", true);  // read-only
    wakeOnMovement = preferences.getBool("wakeOnMove", true);
    preferences.end();
    Serial.printf("Wake-on-movement: %s\n", wakeOnMovement ? "ENABLED" : "DISABLED");

    // ------------------------------------------------------------------
    // Check wake-up reason
    // ------------------------------------------------------------------
    esp_sleep_wakeup_cause_t wakeReason = esp_sleep_get_wakeup_cause();
    if (wakeReason == ESP_SLEEP_WAKEUP_EXT1) {
        Serial.println("Wake reason: MOTION INTERRUPT (GPIO 18)");
    } else {
        Serial.println("Wake reason: POWER-ON / RESET");
    }

    // ------------------------------------------------------------------
    // Initialise I2C and MPU-6050
    // ------------------------------------------------------------------
    Wire.begin(SDA_PIN, SCL_PIN);
    Serial.printf("I2C initialised — SDA: GPIO %d, SCL: GPIO %d\n", SDA_PIN, SCL_PIN);

    if (wakeReason == ESP_SLEEP_WAKEUP_EXT1) {
        // When waking from a motion interrupt the MPU-6050 is in its
        // low-power configuration.  Restore it before calling initialize().
        wakeupMPU();
    }

    mpu.initialize();
    if (mpu.testConnection()) {
        Serial.println("MPU-6050: OK");
    } else {
        Serial.println("MPU-6050: NOT FOUND — check wiring");
    }

    // Configure ±2 g / ±500 °/s ranges.
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_2);
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);

    // ------------------------------------------------------------------
    // Read initial battery level
    // ------------------------------------------------------------------
    readBatteryVoltage();

    // ------------------------------------------------------------------
    // Read a few IMU samples to verify the sensor is working
    // ------------------------------------------------------------------
    Serial.println("IMU sample readings:");
    for (int i = 0; i < 5; i++) {
        int16_t ax, ay, az, gx, gy, gz;
        mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
        Serial.printf("  Accel [raw]: %6d %6d %6d   Gyro [raw]: %6d %6d %6d\n",
                      ax, ay, az, gx, gy, gz);
        delay(100);
    }

    Serial.printf("\nWill enter deep sleep in %d s.\n", AWAKE_DURATION_MS / 1000);
}

// ---------------------------------------------------------------------------
// loop()
// ---------------------------------------------------------------------------
void loop() {
    static unsigned long startTime   = millis();
    static unsigned long lastBatTime = 0;

    unsigned long now = millis();

    // Slow LED blink to indicate the board is alive.
    digitalWrite(BLUE_LED_PIN, (now / 500) % 2 == 0 ? HIGH : LOW);

    // Refresh battery reading periodically.
    if (now - lastBatTime >= BATTERY_READ_INTERVAL_MS) {
        lastBatTime = now;
        readBatteryVoltage();
    }

    // Enter deep sleep after the demo awake period.
    if (now - startTime >= AWAKE_DURATION_MS) {
        enterDeepSleep();
    }
}
