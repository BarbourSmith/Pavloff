import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, ActivityIndicator, Alert, TouchableOpacity } from 'react-native';
import bleService from '../services/bleService';
import { APP_CONFIG } from '../config/appConfig';

// The Service UUID is known, so we define it here
const IMU_SERVICE_UUID = APP_CONFIG.UUIDS.IMU_SERVICE;
const TARGET_DEVICE_NAME = 'ESP32_IMU_Stream';
const SCAN_INTERVAL = 5000; // Scan every 5 seconds when not connected

const DataView = ({ deviceData, deviceName, onReset, isResetting }) => {
  const accelData = deviceData?.accel ?? null;
  const lastUpdate = deviceData?.lastUpdate;

  const parseRepData = (dataString) => {
    if (!dataString) {
      return { count: '0', state: 'IDLE', raw: 'No data', timestamp: 'Never' };
    }
    
    const values = {};
    try {
      // Parse Count:value,State:value format
      // Example: "Count:5,State:UP" or "Count:12,State:DOWN"
      dataString.split(',').forEach(part => {
        const [key, value] = part.split(':');
        if (key && value) {
          values[key.toLowerCase().trim()] = value.trim();
        }
      });
    } catch (error) {
      console.error(`[PARSE ERROR] ${deviceName} Rep Data:`, error);
      return { count: 'Error', state: 'Error', raw: dataString, timestamp: 'Error' };
    }
    
    const result = {
        count: values.count || '0',
        state: values.state || 'IDLE',
        raw: dataString,
        timestamp: lastUpdate ? new Date(lastUpdate).toLocaleTimeString() : 'Unknown'
    };
    
    return result;
  };

  // Parse rep count data
  const repData = parseRepData(accelData);

  // Determine state color
  const getStateColor = (state) => {
    switch(state.toUpperCase()) {
      case 'UP': return '#4CAF50';    // Green
      case 'DOWN': return '#2196F3';  // Blue
      case 'IDLE': return '#9E9E9E';  // Gray
      default: return '#FF9800';      // Orange for unknown
    }
  };

  return (
    <View style={styles.dataContainer}>
      <View style={styles.repDisplayContainer}>
        <Text style={styles.repCountLabel}>REPS</Text>
        <Text style={styles.repCountValue}>{repData.count}</Text>
        <View style={[styles.stateIndicator, { backgroundColor: getStateColor(repData.state) }]}>
          <Text style={styles.stateText}>{repData.state}</Text>
        </View>
        <Text style={styles.timestampText}>Last Update: {repData.timestamp}</Text>
        
        <TouchableOpacity 
          style={[styles.resetButton, isResetting && styles.resetButtonDisabled]}
          onPress={onReset}
          disabled={isResetting}
        >
          <Text style={styles.resetButtonText}>
            {isResetting ? 'Resetting...' : 'Reset Count'}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const DataDisplayScreen = () => {
  const [connectionStatus, setConnectionStatus] = useState('Scanning for device...');
  const [isConnected, setIsConnected] = useState(false);
  const [connectedDevice, setConnectedDevice] = useState(null);
  const [deviceCharacteristics, setDeviceCharacteristics] = useState(null);
  const [deviceData, setDeviceData] = useState({});
  const [scanInterval, setScanInterval] = useState(null);
  const [isResetting, setIsResetting] = useState(false);

  // Update device data callback
  const updateDeviceData = useCallback((deviceId, dataType, data) => {
    setDeviceData(prevData => {
      const currentDeviceData = prevData[deviceId] || {};
      return {
        ...prevData,
        [deviceId]: {
          ...currentDeviceData,
          [dataType]: data,
          lastUpdate: Date.now()
        }
      };
    });
  }, []);

  const handleMonitoringError = useCallback((deviceId, dataType, error) => {
    console.error(`[MONITORING ERROR] ${deviceId} ${dataType}:`, error);
    // If monitoring error, disconnect and retry
    setConnectionStatus('Connection lost. Retrying...');
    setIsConnected(false);
    if (connectedDevice) {
      bleService.disconnectFromDevice(connectedDevice.id).catch(err => {
        console.error('Error disconnecting:', err);
      });
    }
    setConnectedDevice(null);
  }, [connectedDevice]);

  // Function to identify characteristics
  const identifyCharacteristics = (characteristics) => {
    const result = { accel: null, gyro: null };
    
    console.log(`Found ${characteristics.length} characteristics:`);
    characteristics.forEach((char, index) => {
      console.log(`  [${index}] UUID: ${char.uuid}`);
    });
    
    // Use the first characteristic for rep counting
    if (characteristics.length >= 1) {
      result.accel = characteristics[0].uuid;
      console.log(`Using characteristic [0] for rep counter: ${characteristics[0].uuid}`);
    }
    
    if (characteristics.length >= 2) {
      result.gyro = characteristics[1].uuid;
      console.log(`Using characteristic [1] for gyro: ${characteristics[1].uuid}`);
    }
    
    console.log(`Final assignment: accel=${result.accel}, gyro=${result.gyro}`);
    return result;
  };

  // Function to connect to a device
  const connectToTargetDevice = async (device) => {
    try {
      console.log(`[AUTO-CONNECT] Attempting to connect to ${device.name}...`);
      setConnectionStatus(`Connecting to ${device.name}...`);

      // Stop scanning while connecting
      bleService.stopScanning();

      const connectedDevice = await bleService.connectToDevice(device.id);
      console.log(`[AUTO-CONNECT] Connected, discovering services...`);
      setConnectionStatus('Discovering services...');

      const services = await connectedDevice.services();
      const imuService = services.find(s => s.uuid.toLowerCase() === IMU_SERVICE_UUID.toLowerCase());

      if (!imuService) {
        throw new Error("IMU Service not found on this device.");
      }

      const characteristics = await imuService.characteristics();
      if (!characteristics || characteristics.length < 1) {
        throw new Error("Expected at least 1 characteristic for IMU service.");
      }

      const characteristicMapping = identifyCharacteristics(characteristics);
      
      if (!characteristicMapping.accel) {
        throw new Error("Could not identify rep counter characteristic.");
      }

      setDeviceCharacteristics(characteristicMapping);
      setConnectedDevice(device);
      setIsConnected(true);
      setConnectionStatus(`Connected to ${device.name}`);

      console.log(`[AUTO-CONNECT] Successfully connected and configured`);

      // Start monitoring
      setTimeout(() => {
        console.log(`[MONITORING] Starting monitoring for ${device.name}`);
        bleService.monitorCharacteristic(
          `${device.id}_accel`,
          device.id,
          IMU_SERVICE_UUID,
          characteristicMapping.accel,
          (data) => {
            updateDeviceData(device.id, 'accel', data);
          },
          (error) => {
            console.error(`[ERROR] ${device.name}:`, error);
            handleMonitoringError(device.id, 'accel', error);
          }
        );
      }, bleService.CONFIG.MONITORING_DELAY);

    } catch (error) {
      console.error(`[AUTO-CONNECT] Failed to connect:`, error);
      setConnectionStatus(`Connection failed: ${error.message}`);
      setIsConnected(false);
      setConnectedDevice(null);
      
      // Disconnect if partially connected
      try {
        await bleService.disconnectFromDevice(device.id);
      } catch (disconnectError) {
        console.error('Error during cleanup disconnect:', disconnectError);
      }
    }
  };

  // Function to scan for target device
  const scanForTargetDevice = useCallback(async () => {
    if (isConnected) {
      console.log('[AUTO-SCAN] Already connected, skipping scan');
      return;
    }

    try {
      // Check BLE state before scanning
      const bleState = await bleService.getBleState();
      if (bleState !== 'PoweredOn') {
        console.log(`[AUTO-SCAN] Bluetooth is ${bleState}`);
        setConnectionStatus(`Bluetooth is ${bleState}. Please enable Bluetooth.`);
        return;
      }

      console.log(`[AUTO-SCAN] Scanning for ${TARGET_DEVICE_NAME}...`);
      setConnectionStatus(`Scanning for ${TARGET_DEVICE_NAME}...`);

      let foundDevice = null;

      bleService.scanForDevices(
        (device) => {
          console.log(`[AUTO-SCAN] Found device: ${device.name} (${device.id})`);
          if (device.name === TARGET_DEVICE_NAME && !foundDevice) {
            console.log(`[AUTO-SCAN] Target device found!`);
            foundDevice = device;
            bleService.stopScanning();
            // Connect to the device
            connectToTargetDevice(device);
          }
        },
        (error) => {
          console.error('[AUTO-SCAN] Scan error:', error);
          setConnectionStatus(`Scan error: ${error.message}`);
        }
      );

      // Stop scan after timeout if device not found
      setTimeout(() => {
        if (!foundDevice && !isConnected) {
          bleService.stopScanning();
          console.log(`[AUTO-SCAN] Timeout reached, device not found`);
          setConnectionStatus(`${TARGET_DEVICE_NAME} not found. Will retry...`);
        }
      }, bleService.CONFIG.SCAN_TIMEOUT);

    } catch (error) {
      console.error('[AUTO-SCAN] Error during scan:', error);
      setConnectionStatus(`Scan error: ${error.message}`);
    }
  }, [isConnected]);

  // Function to reset rep count on the device
  const handleResetRepCount = async () => {
    if (!isConnected || !connectedDevice || !deviceCharacteristics) {
      Alert.alert('Error', 'No device connected');
      return;
    }

    try {
      setIsResetting(true);
      console.log('[RESET] Sending reset command to device...');
      
      await bleService.writeCharacteristic(
        connectedDevice.id,
        IMU_SERVICE_UUID,
        deviceCharacteristics.accel,
        'RESET'
      );
      
      console.log('[RESET] Reset command sent successfully');
      Alert.alert('Success', 'Rep count reset successfully');
    } catch (error) {
      console.error('[RESET] Failed to reset rep count:', error);
      Alert.alert('Error', `Failed to reset rep count: ${error.message}`);
    } finally {
      setIsResetting(false);
    }
  };

  // Set up periodic scanning when not connected
  useEffect(() => {
    // Initial scan
    scanForTargetDevice();

    // Set up periodic scanning
    const interval = setInterval(() => {
      if (!isConnected) {
        console.log('[AUTO-SCAN] Periodic scan triggered');
        scanForTargetDevice();
      }
    }, SCAN_INTERVAL);

    setScanInterval(interval);

    // Cleanup on unmount
    return () => {
      console.log('[CLEANUP] Stopping all monitoring and disconnecting...');
      if (interval) {
        clearInterval(interval);
      }
      bleService.stopScanning();
      bleService.stopAllMonitoring();
      if (connectedDevice) {
        bleService.disconnectFromDevice(connectedDevice.id).catch(err => {
          console.error('Error disconnecting on cleanup:', err);
        });
      }
    };
  }, []);

  // Re-trigger scanning when connection is lost
  useEffect(() => {
    if (!isConnected && !scanInterval) {
      const interval = setInterval(() => {
        console.log('[AUTO-SCAN] Periodic scan triggered (reconnect)');
        scanForTargetDevice();
      }, SCAN_INTERVAL);
      setScanInterval(interval);
    } else if (isConnected && scanInterval) {
      // Clear interval when connected
      clearInterval(scanInterval);
      setScanInterval(null);
    }
  }, [isConnected, scanInterval, scanForTargetDevice]);

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        <View style={styles.header}>
          <Text style={styles.title}>Exercise Rep Counter</Text>
          <View style={styles.statusContainer}>
            {!isConnected && (
              <ActivityIndicator size="small" color="#007BFF" style={styles.loader} />
            )}
            <Text style={[
              styles.statusText,
              isConnected ? styles.connectedText : styles.disconnectedText
            ]}>
              {connectionStatus}
            </Text>
          </View>
        </View>
        
        {isConnected && connectedDevice ? (
          <View style={styles.deviceSection}>
            <Text style={styles.deviceNameTitle}>
              {connectedDevice.name}
            </Text>
            
            <DataView 
              deviceData={deviceData[connectedDevice.id]} 
              deviceName={connectedDevice.name}
              onReset={handleResetRepCount}
              isResetting={isResetting}
            />
          </View>
        ) : (
          <View style={styles.waitingContainer}>
            <ActivityIndicator size="large" color="#007BFF" />
            <Text style={styles.waitingText}>
              Waiting for {TARGET_DEVICE_NAME} to be available...
            </Text>
            <Text style={styles.instructionText}>
              Make sure your device is powered on and in range.
            </Text>
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFFFF' },
  header: {
    padding: 20,
    backgroundColor: '#007BFF',
    borderBottomWidth: 1,
    borderBottomColor: '#0056b3',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    textAlign: 'center',
    marginBottom: 10,
  },
  statusContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 10,
  },
  loader: {
    marginRight: 10,
  },
  statusText: {
    fontSize: 14,
    textAlign: 'center',
  },
  connectedText: {
    color: '#E8F5E9',
    fontWeight: '600',
  },
  disconnectedText: {
    color: '#FFEBEE',
    fontStyle: 'italic',
  },
  waitingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
    marginTop: 60,
  },
  waitingText: {
    fontSize: 18,
    color: '#666666',
    textAlign: 'center',
    marginTop: 20,
    marginBottom: 10,
  },
  instructionText: {
    fontSize: 14,
    color: '#999999',
    textAlign: 'center',
    marginTop: 10,
  },
  deviceSection: { padding: 25, borderBottomWidth: 1, borderBottomColor: '#EEEEEE' },
  deviceNameTitle: { fontSize: 20, fontWeight: 'bold', marginBottom: 20, color: '#333333', textAlign: 'center' },
  dataContainer: { flexDirection: 'row', justifyContent: 'center', paddingVertical: 20 },
  repDisplayContainer: {
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
    borderRadius: 20,
    padding: 30,
    minWidth: 280,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 8,
  },
  repCountLabel: {
    fontSize: 20,
    fontWeight: '600',
    color: '#666',
    letterSpacing: 2,
    marginBottom: 10,
  },
  repCountValue: {
    fontSize: 120,
    fontWeight: 'bold',
    color: '#007BFF',
    marginVertical: 20,
    textShadowColor: 'rgba(0, 123, 255, 0.2)',
    textShadowOffset: { width: 0, height: 4 },
    textShadowRadius: 10,
  },
  stateIndicator: {
    paddingHorizontal: 30,
    paddingVertical: 12,
    borderRadius: 25,
    marginTop: 15,
    marginBottom: 10,
    minWidth: 150,
  },
  stateText: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#FFFFFF',
    textAlign: 'center',
    letterSpacing: 1,
  },
  timestampText: {
    fontSize: 12,
    color: '#999',
    marginTop: 15,
    fontStyle: 'italic',
  },
  resetButton: {
    backgroundColor: '#FF5722',
    paddingHorizontal: 40,
    paddingVertical: 15,
    borderRadius: 25,
    marginTop: 25,
    minWidth: 200,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  resetButtonDisabled: {
    backgroundColor: '#BDBDBD',
    opacity: 0.6,
  },
  resetButtonText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    textAlign: 'center',
    letterSpacing: 0.5,
  },
});

export default DataDisplayScreen;
