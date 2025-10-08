// Application configuration constants
export const APP_CONFIG = {
  // BLE Configuration
  BLE: {
    SCAN_TIMEOUT: 10000,
    CONNECTION_TIMEOUT: 15000,
    MAX_RETRY_ATTEMPTS: 3,
    RETRY_DELAY: 1000,
    MONITORING_DELAY: 250,
  },
  
  // Device Configuration
  DEVICES: {
    MAX_SELECTABLE_DEVICES: 2,
    MIN_SELECTABLE_DEVICES: 1,
  },
  
  // Service and Characteristic UUIDs
  UUIDS: {
    IMU_SERVICE: '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
    ACCEL_CHARACTERISTIC: 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
    GYRO_CHARACTERISTIC: 'beb5483e-36e1-4688-b7f5-ea07361b26a9',
  },
  
  // UI Configuration
  UI: {
    COLORS: {
      PRIMARY: '#007BFF',
      SUCCESS: '#28A745',
      ERROR: '#F44336',
      WARNING: '#FF9800',
      BACKGROUND: '#F8F9FA',
      WHITE: '#FFFFFF',
    },
    TIMEOUTS: {
      ALERT_DISMISS: 5000,
      RETRY_DELAY: 3000,
    },
  },
  
  // Error Messages
  ERRORS: {
    BLUETOOTH_OFF: 'Bluetooth is turned off. Please enable Bluetooth and try again.',
    NO_DEVICES_FOUND: 'No devices found. Make sure your ESP32 devices are powered on and advertising.',
    CONNECTION_FAILED: 'Failed to connect to device. Please try again.',
    SERVICE_NOT_FOUND: 'IMU Service not found on this device.',
    CHARACTERISTICS_NOT_FOUND: 'Expected IMU characteristics not found.',
    PERMISSION_DENIED: 'Bluetooth permissions are required for this app to work.',
  },
};

export default APP_CONFIG;
