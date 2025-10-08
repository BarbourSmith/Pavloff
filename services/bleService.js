import { BleManager } from 'react-native-ble-plx';
import { Buffer } from 'buffer';

const bleManager = new BleManager();
const subscriptions = new Map();

// Configuration constants
const CONFIG = {
  SCAN_TIMEOUT: 10000,
  CONNECTION_TIMEOUT: 15000,
  MAX_RETRY_ATTEMPTS: 3,
  RETRY_DELAY: 1000,
  MONITORING_DELAY: 250,
};

// Utility function for delay
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Utility function for retry logic
const retryOperation = async (operation, maxAttempts = CONFIG.MAX_RETRY_ATTEMPTS) => {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      console.log(`Attempt ${attempt} failed:`, error.message);
      if (attempt === maxAttempts) {
        throw error;
      }
      await delay(CONFIG.RETRY_DELAY * attempt); // Exponential backoff only
    }
  }
};

const scanForDevices = (onDeviceFound, onError = null) => {
  console.log('Starting device scan...');
  
  // Clear any existing scan
  bleManager.stopDeviceScan();
  
  let scanTimeout;
  
  try {
    bleManager.startDeviceScan(null, null, (error, device) => {
      if (error) {
        console.error('Scan Error:', error);
        bleManager.stopDeviceScan();
        if (scanTimeout) clearTimeout(scanTimeout);
        if (onError) onError(error);
        return;
      }
      
      if (device && device.name && device.name.trim() !== '') {
        onDeviceFound(device);
      }
    });

    scanTimeout = setTimeout(() => {
      bleManager.stopDeviceScan();
      console.log('Scan stopped after timeout.');
    }, CONFIG.SCAN_TIMEOUT);
    
  } catch (error) {
    console.error('Failed to start scan:', error);
    if (onError) onError(error);
  }
};

// Add function to manually stop scanning
const stopScanning = () => {
  console.log('Manually stopping device scan...');
  try {
    bleManager.stopDeviceScan();
  } catch (error) {
    console.error('Error stopping scan:', error);
  }
};

const connectToDevice = async (deviceId) => {
  return retryOperation(async () => {
    console.log(`Connecting to device ${deviceId}...`);
    
    // Check if device is already connected
    const connectedDevices = await bleManager.connectedDevices([]);
    const alreadyConnected = connectedDevices.find(device => device.id === deviceId);
    
    if (alreadyConnected) {
      console.log(`Device ${deviceId} is already connected`);
      return alreadyConnected;
    }

    // Create a timeout promise
    const connectionPromise = bleManager.connectToDevice(deviceId);
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Connection timeout')), CONFIG.CONNECTION_TIMEOUT);
    });

    // Race between connection and timeout
    const device = await Promise.race([connectionPromise, timeoutPromise]);
    
    console.log(`Connected to ${device.name || 'Unknown Device'}, discovering services...`);
    
    // Discover services with timeout
    const discoveryPromise = device.discoverAllServicesAndCharacteristics();
    const discoveryTimeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Service discovery timeout')), CONFIG.CONNECTION_TIMEOUT);
    });
    
    await Promise.race([discoveryPromise, discoveryTimeoutPromise]);
    console.log(`Services and characteristics discovered for ${device.name || deviceId}.`);
    
    return device;
  });
};

const disconnectFromDevice = async (deviceId) => {
  try {
    // Stop all monitoring for this device first
    const deviceSubscriptions = Array.from(subscriptions.keys()).filter(key => 
      key.includes(deviceId)
    );
    
    deviceSubscriptions.forEach(key => {
      stopMonitoring(key);
    });

    // Then disconnect
    await bleManager.cancelDeviceConnection(deviceId);
    console.log(`Disconnected from device ${deviceId}`);
  } catch (error) {
    console.error(`Failed to disconnect from device ${deviceId}:`, error.message);
  }
};

const monitorCharacteristic = (subscriptionKey, deviceId, serviceUUID, characteristicUUID, onDataReceived, onError = null) => {
  if (subscriptions.has(subscriptionKey)) {
    console.log(`Subscription ${subscriptionKey} already exists, skipping...`);
    return;
  }
  
  console.log(`[MONITOR] Setting up monitor for ${subscriptionKey}`);
  console.log(`  Device: ${deviceId}`);
  console.log(`  Service: ${serviceUUID}`);
  console.log(`  Characteristic: ${characteristicUUID}`);
  
  try {
    const subscription = bleManager.monitorCharacteristicForDevice(
      deviceId,
      serviceUUID,
      characteristicUUID,
      (error, characteristic) => {
        if (error) {
          console.error(`[MONITOR ERROR] ${subscriptionKey}:`, error.message);
          stopMonitoring(subscriptionKey);
          
          if (onError) {
            onError(error);
          }
          return;
        }
        
        if (characteristic && characteristic.value) {
          try {
            const decodedValue = Buffer.from(characteristic.value, 'base64').toString('utf-8');
            console.log(`[DATA] ${subscriptionKey}: "${decodedValue}"`);
            
            // Validate the data before passing it on
            if (decodedValue && decodedValue.trim() !== '') {
              onDataReceived(decodedValue);
            } else {
              console.warn(`[DATA WARNING] Empty data received for ${subscriptionKey}`);
            }
          } catch (decodeError) {
            console.error(`[DECODE ERROR] ${subscriptionKey}:`, decodeError);
            if (onError) {
              onError(decodeError);
            }
          }
        } else {
          console.warn(`[DATA WARNING] No characteristic value for ${subscriptionKey}`);
        }
      }
    );
    
    if (subscription) {
      subscriptions.set(subscriptionKey, subscription);
      console.log(`[MONITOR SUCCESS] Successfully set up monitoring for ${subscriptionKey}`);
    } else {
      console.error(`[MONITOR FAILED] Failed to create subscription for ${subscriptionKey}`);
    }
  } catch (error) {
    console.error(`[MONITOR EXCEPTION] Failed to set up monitoring for ${subscriptionKey}:`, error);
    if (onError) {
      onError(error);
    }
  }
};

const stopMonitoring = (subscriptionKey) => {
  return new Promise((resolve) => {
    if (subscriptions.has(subscriptionKey)) {
      try {
        console.log(`Stopping monitor for: ${subscriptionKey}`);
        const subscription = subscriptions.get(subscriptionKey);
        if (subscription && typeof subscription.remove === 'function') {
          subscription.remove();
        }
        subscriptions.delete(subscriptionKey);
        console.log(`Successfully stopped monitoring for: ${subscriptionKey}`);
        resolve(true);
      } catch (error) {
        console.error(`Error stopping monitor for ${subscriptionKey}:`, error);
        // Still remove from map even if there was an error
        subscriptions.delete(subscriptionKey);
        resolve(false);
      }
    } else {
      console.log(`No subscription found for: ${subscriptionKey}`);
      resolve(true);
    }
  });
};

// Add a function to stop all monitoring
const stopAllMonitoring = async () => {
  console.log('Stopping all monitoring subscriptions...');
  const allKeys = Array.from(subscriptions.keys());
  
  if (allKeys.length === 0) {
    console.log('No active monitoring subscriptions to stop');
    return Promise.resolve();
  }
  
  try {
    const stopPromises = allKeys.map(key => stopMonitoring(key));
    await Promise.all(stopPromises);
    console.log(`Successfully stopped ${allKeys.length} monitoring subscriptions`);
  } catch (error) {
    console.error('Error stopping some monitoring subscriptions:', error);
    // Clear all subscriptions anyway
    subscriptions.clear();
  }
};

// Add a function to get BLE manager state
const getBleState = async () => {
  try {
    const state = await bleManager.state();
    return state;
  } catch (error) {
    console.error('Error getting BLE state:', error);
    return 'Unknown';
  }
};

export default {
  scanForDevices,
  stopScanning,
  connectToDevice,
  disconnectFromDevice,
  monitorCharacteristic,
  stopMonitoring,
  stopAllMonitoring,
  getBleState,
  CONFIG, // Export config for use in other components
};
