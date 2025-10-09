import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, SafeAreaView, ScrollView, Button, Alert } from 'react-native';
import bleService from '../services/bleService';
import { APP_CONFIG } from '../config/appConfig';

// The Service UUID is known, so we defined here to pass to monitor .
const IMU_SERVICE_UUID = APP_CONFIG.UUIDS.IMU_SERVICE;

const DataView = ({ deviceData, deviceId, deviceName }) => {
  const accelData = deviceData?.accel ?? null;
  const gyroData = deviceData?.gyro ?? null;
  const lastUpdate = deviceData?.lastUpdate;

  const parsePositionData = (dataString) => {
    if (!dataString) {
      return { x: '0.00', y: '0.00', z: '0.00', raw: 'No data', timestamp: 'Never' };
    }
    
    const values = {};
    try {
      // Check if data contains "Position:" prefix and extract the position part
      let positionString = dataString;
      if (dataString.includes('Position:')) {
        // Extract everything after "Position:"
        positionString = dataString.split('Position:')[1].trim();
      }
      
      // Parse X:value,Y:value,Z:value format
      positionString.split(',').forEach(part => {
        const [key, value] = part.split(':');
        if (key && value) {
          values[key.toLowerCase().trim()] = parseFloat(value).toFixed(2);
        }
      });
    } catch (error) {
      console.error(`[PARSE ERROR] ${deviceName} Position:`, error);
      return { x: 'Error', y: 'Error', z: 'Error', raw: dataString, timestamp: 'Error' };
    }
    
    const result = {
        x: values.x || '0.00',
        y: values.y || '0.00',
        z: values.z || '0.00',
        raw: dataString,
        timestamp: lastUpdate ? new Date(lastUpdate).toLocaleTimeString() : 'Unknown'
    };
    
    return result;
  };

  // Use accel data for position (assuming the characteristic is being reused)
  const position = parsePositionData(accelData);

  return (
    <View style={styles.dataContainer}>
      <View style={styles.dataColumn}>
        <Text style={styles.sensorTitle}>Position</Text>
        <Text style={styles.dataRow}><Text style={styles.axisLabel}>X:</Text> {position.x} m</Text>
        <Text style={styles.dataRow}><Text style={styles.axisLabel}>Y:</Text> {position.y} m</Text>
        <Text style={styles.dataRow}><Text style={styles.axisLabel}>Z:</Text> {position.z} m</Text>
      </View>
    </View>
  );
};

const DataDisplayScreen = ({ route, navigation }) => {
  // Receive devices with characteristics
  const { devices, characteristics } = route.params;
  
  const [deviceData, setDeviceData] = useState({});
  const [isMonitoring, setIsMonitoring] = useState(true);
  const [connectionErrors, setConnectionErrors] = useState({});

  // Use useCallback to prevent recreating functions on every render
  const updateDeviceData = useCallback((deviceId, dataType, data) => {
    setDeviceData(prevData => {
      const currentDeviceData = prevData[deviceId] || {};
      return {
        ...prevData,
        [deviceId]: {
          ...currentDeviceData,
          [dataType]: data,
          lastUpdate: Date.now() // Add timestamp for debugging // remove in PROD
        }
      };
    });
  }, []);

  const handleMonitoringError = useCallback((deviceId, dataType, error) => {
    // Don't handle errors if monitoring has been stopped
    if (!isMonitoring) {
      console.log(`[ERROR IGNORED] Monitoring stopped, ignoring error for ${deviceId} ${dataType}:`, error.message);
      return;
    }
    
    console.error(`[MONITORING ERROR] ${deviceId} ${dataType}:`, error);
    setConnectionErrors(prev => ({
      ...prev,
      [`${deviceId}_${dataType}`]: error.message
    }));
    
    // Optionally try to reconnect after a delay, but only if still monitoring
    setTimeout(() => {
      setConnectionErrors(prev => {
        // Check if monitoring is still active before clearing errors
        if (isMonitoring) {
          const newErrors = { ...prev };
          delete newErrors[`${deviceId}_${dataType}`];
          return newErrors;
        }
        return prev;
      });
    }, 5000);
  }, [isMonitoring]);

  useEffect(() => {
    const startMonitoringWithDelay = () => {
        console.log(`[MONITORING] Starting monitoring for ${devices.length} devices`);
        
        devices.forEach((device, deviceIndex) => {
            const deviceChars = characteristics[device.id];
            
            console.log(`[MONITORING] Device ${deviceIndex + 1}: ${device.name} (${device.id})`);
            
            if (!deviceChars) {
              console.error(`[MONITORING ERROR] No characteristics found for device ${device.name}`);
              return;
            }

            // Validate characteristics exist
            if (!deviceChars.accel || !deviceChars.gyro) {
              console.error(`[MONITORING ERROR] Missing characteristics for device ${device.name}:`, deviceChars);
              return;
            }

            console.log(`[MONITORING] Setting up position monitor for ${device.name}`);
            console.log(`  - Position UUID: ${deviceChars.accel}`);
            
            // Monitor position data using the first characteristic (accel UUID)
            bleService.monitorCharacteristic(
              `${device.id}_accel`,
              device.id,
              IMU_SERVICE_UUID,
              deviceChars.accel,
              (data) => {
                // Only process data if monitoring is still active
                if (isMonitoring) {
                  console.log(`[POSITION DATA] ${device.name}: "${data}"`);
                  updateDeviceData(device.id, 'accel', data);
                }
              },
              (error) => {
                // Only handle errors if monitoring is still active
                if (isMonitoring) {
                  console.error(`[POSITION ERROR] ${device.name}:`, error);
                  handleMonitoringError(device.id, 'accel', error);
                }
              }
            );
            
            console.log(`[MONITORING] Completed setup for ${device.name}`);
        });
        
        console.log(`[MONITORING] All devices configured for monitoring`);
    }

    if (isMonitoring) {
      console.log(`[MONITORING] Starting monitoring in ${bleService.CONFIG.MONITORING_DELAY}ms`);
      // Use the configured delay from bleService
      const timerId = setTimeout(startMonitoringWithDelay, bleService.CONFIG.MONITORING_DELAY);
      return () => {
        console.log(`[MONITORING] Cleaning up timer`);
        clearTimeout(timerId);
      };
    } else {
      console.log(`[MONITORING] Monitoring is disabled - stopping all monitoring`);
      devices.forEach(device => {
        console.log(`[MONITORING] Stopping monitoring for ${device.name}`);
        bleService.stopMonitoring(`${device.id}_accel`);
      });
    }
  }, [devices, characteristics, isMonitoring, updateDeviceData, handleMonitoringError]);

  // This effect handles cleanup when the screen is unmounted.
  useEffect(() => {
    return () => {
      console.log('Leaving data screen. Cleaning up...');
      
      // Update monitoring state to prevent error handling
      setIsMonitoring(false);
      
      try {
        // Stop all monitoring using the centralized function
        console.log('Stopping all monitoring subscriptions...');
        bleService.stopAllMonitoring();
        
        // Also manually stop device-specific monitoring to be thorough
        devices.forEach(device => {
          try {
            bleService.stopMonitoring(`${device.id}_accel`);
          } catch (error) {
            console.error(`Error stopping monitoring for ${device.id}:`, error);
          }
        });
        
        // Then disconnect from all devices
        devices.forEach(device => {
          bleService.disconnectFromDevice(device.id).catch(error => {
            console.error(`Error disconnecting from ${device.id}:`, error);
            // Don't throw, just log the error
          });
        });
        
      } catch (error) {
        console.error('Error during cleanup:', error);
      }
      
      console.log('Cleanup completed.');
    };
  }, [devices]);

  const handleStopMonitoring = async () => {
      console.log('[MONITORING] User requested to stop monitoring');
      
      // Update state first to prevent further error handling
      setIsMonitoring(false);
      
      // Clear any existing error states immediately
      setConnectionErrors({});
      
      try {
        // Stopping monitoring
        console.log('[MONITORING] Stopping all device monitoring...');
        
        // Use the stopAllMonitoring function for cleaner shutdown
        await bleService.stopAllMonitoring();
        
        // Also manually stop device-specific monitoring to be thorough
        const stopPromises = [];
        devices.forEach(device => {
          console.log(`[MONITORING] Ensuring monitoring stopped for ${device.name}`);
          stopPromises.push(
            Promise.resolve(bleService.stopMonitoring(`${device.id}_accel`))
          );
        });
        
        // Wait for all monitoring to stop
        await Promise.all(stopPromises);
        console.log('[MONITORING] All monitoring stopped successfully');
        
        // Disconnect from all devices
        const disconnectPromises = devices.map(device => 
          bleService.disconnectFromDevice(device.id).catch(error => {
            console.error(`Error disconnecting from ${device.id}:`, error);
            // Don't throw, just log the error
          })
        );
        
        await Promise.all(disconnectPromises);
        console.log('[MONITORING] All devices disconnected');
        
      } catch (error) {
        console.error('[MONITORING] Error during stop monitoring:', error);
        // Continue with navigation even if there were errors
      }
      
      // Show alert and navigate back to scan screen when OK is pressed
      Alert.alert(
        'Monitoring Stopped', 
        'Data monitoring has been stopped for all devices.',
        [
          {
            text: 'OK',
            onPress: () => {
              console.log('[NAVIGATION] Navigating back to Home screen');
              navigation.navigate('Home');
            }
          }
        ]
      );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        <View style={styles.controlPanel}>
            <Button 
                title="Stop Monitoring"
                onPress={handleStopMonitoring}
                color='#F44336'
            />
            <Text style={[styles.statusText, { color: '#4CAF50' }]}>
              Status: Monitoring Active
            </Text>
            <Text style={styles.statusText}>
              Connected to {devices.length} device{devices.length !== 1 ? 's' : ''}
            </Text>
        </View>
        
        {/* Show connection errors if any */}
        {Object.keys(connectionErrors).length > 0 && (
          <View style={styles.errorPanel}>
            <Text style={styles.errorTitle}>Connection Issues:</Text>
            {Object.entries(connectionErrors).map(([key, error]) => (
              <Text key={key} style={styles.errorText}>
                {key}: {error}
              </Text>
            ))}
          </View>
        )}
        
        {devices.map((device, index) => {
          return (
            <View key={device.id} style={styles.deviceSection}>
              <Text style={styles.deviceNameTitle}>
                Device {index + 1}: {device.name}
              </Text>
              
              <DataView 
                deviceData={deviceData[device.id]} 
                deviceId={device.id}
                deviceName={device.name}
              />
            </View>
          );
        })}
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFFFF' },
  controlPanel: { padding: 20, borderBottomWidth: 1, borderBottomColor: '#EEEEEE' },
  statusText: { fontSize: 14, color: '#666666', textAlign: 'center', marginTop: 10 },
  errorPanel: { 
    backgroundColor: '#FFEBEE', 
    padding: 15, 
    margin: 15, 
    borderRadius: 8, 
    borderLeftWidth: 4, 
    borderLeftColor: '#F44336' 
  },
  errorTitle: { fontSize: 16, fontWeight: 'bold', color: '#C62828', marginBottom: 8 },
  errorText: { fontSize: 14, color: '#D32F2F', marginBottom: 4 },
  deviceSection: { padding: 25, borderBottomWidth: 1, borderBottomColor: '#EEEEEE' },
  deviceNameTitle: { fontSize: 20, fontWeight: 'bold', marginBottom: 20, color: '#333333', textAlign: 'center' },
  dataContainer: { flexDirection: 'row', justifyContent: 'center', paddingVertical: 10 },
  dataColumn: { alignItems: 'center', minWidth: 200 },
  sensorTitle: { fontSize: 18, fontWeight: '600', color: '#007BFF', marginBottom: 15 },
  dataRow: { fontSize: 16, color: '#333333', marginBottom: 8 },
  axisLabel: { fontWeight: 'bold', color: '#555555' },
});

export default DataDisplayScreen;
