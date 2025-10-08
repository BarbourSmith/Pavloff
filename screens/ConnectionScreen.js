import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, SafeAreaView, Button, ActivityIndicator, Alert } from 'react-native';
import bleService from '../services/bleService';
import { APP_CONFIG } from '../config/appConfig';

// Use the service UUID from config
const IMU_SERVICE_UUID = APP_CONFIG.UUIDS.IMU_SERVICE;

// Known characteristic UUIDs for better identification
const KNOWN_CHARACTERISTICS = {
  // Use UUIDs from config
  ACCEL: APP_CONFIG.UUIDS.ACCEL_CHARACTERISTIC,
  GYRO: APP_CONFIG.UUIDS.GYRO_CHARACTERISTIC,
  
  // Alternative UUIDs if some ESP32 uses different ones 
  ACCEL_ALT: 'beb5483e-36e1-4688-b7f5-ea07361b26a8', //needs hardocoding for fallback
  GYRO_ALT: 'beb5483e-36e1-4688-b7f5-ea07361b26a9', //needs hardocoding for fallback
};

const ConnectionScreen = ({ route, navigation }) => {
  const { devices } = route.params;
  const [connectionStatus, setConnectionStatus] = useState({});
  const [discoveredChars, setDiscoveredChars] = useState({});
  const [readyDevices, setReadyDevices] = useState([]);

  useEffect(() => {
    // This function connects to and processes devices one-by-one to avoid race conditions.
    const processDevicesSequentially = async () => {
      let successfullyConnected = [];
      let discoveredCharacteristics = {};

      for (const device of devices) {
        try {
          setConnectionStatus(prev => ({ ...prev, [device.id]: 'Connecting...' }));
          
          // Check BLE state before connecting
          const bleState = await bleService.getBleState();
          if (bleState !== 'PoweredOn') {
            throw new Error(`Bluetooth is ${bleState}. Please enable Bluetooth.`);
          }

          const connectedDevice = await bleService.connectToDevice(device.id);

          setConnectionStatus(prev => ({ ...prev, [device.id]: 'Discovering...' }));
          const services = await connectedDevice.services();
          const imuService = services.find(s => s.uuid.toLowerCase() === IMU_SERVICE_UUID.toLowerCase());

          if (!imuService) {
            throw new Error("IMU Service not found on this device.");
          }

          const characteristics = await imuService.characteristics();
          if (!characteristics || characteristics.length < 2) {
            throw new Error("Expected at least 2 characteristics for IMU service.");
          }

          // Improved characteristic identification
          const characteristicMapping = identifyCharacteristics(characteristics);
          
          if (!characteristicMapping.accel || !characteristicMapping.gyro) {
            throw new Error("Could not identify accelerometer and gyroscope characteristics.");
          }

          discoveredCharacteristics[device.id] = characteristicMapping;
          successfullyConnected.push(device);
          setConnectionStatus(prev => ({ ...prev, [device.id]: 'Connected' }));

        } catch (error) {
          console.error(`[CRITICAL] Failed to process device ${device.name}:`, error.message);
          setConnectionStatus(prev => ({ ...prev, [device.id]: `Failed: ${error.message}` }));
          
          // Clean up failed connection
          try {
            await bleService.disconnectFromDevice(device.id);
          } catch (disconnectError) {
            console.error(`Failed to disconnect from ${device.id}:`, disconnectError);
          }
        }
      }
      
      setReadyDevices(successfullyConnected);
      setDiscoveredChars(discoveredCharacteristics);

      // Show summary alert
      if (successfullyConnected.length === 0) {
        Alert.alert(
          'Connection Failed',
          'Failed to connect to any devices. Please check that your ESP32 devices are powered on and advertising the IMU service.',
          [{ text: 'OK' }]
        );
      } else if (successfullyConnected.length < devices.length) {
        Alert.alert(
          'Partial Success',
          `Connected to ${successfullyConnected.length} out of ${devices.length} devices.`,
          [{ text: 'OK' }]
        );
      }
    };

    processDevicesSequentially();
  }, [devices]);

  // Improved characteristic identification function
  const identifyCharacteristics = (characteristics) => {
    const result = { accel: null, gyro: null };
    
    console.log(`Found ${characteristics.length} characteristics:`);
    characteristics.forEach((char, index) => {
      console.log(`  [${index}] UUID: ${char.uuid}`);
    });
    
    // Method 1: Try to match known UUIDs
    characteristics.forEach(char => {
      const uuid = char.uuid.toLowerCase();
      if (uuid === KNOWN_CHARACTERISTICS.ACCEL.toLowerCase() || 
          uuid === KNOWN_CHARACTERISTICS.ACCEL_ALT.toLowerCase()) {
        result.accel = char.uuid;
        console.log(`✓ Accelerometer identified by UUID: ${char.uuid}`);
      } else if (uuid === KNOWN_CHARACTERISTICS.GYRO.toLowerCase() || 
                 uuid === KNOWN_CHARACTERISTICS.GYRO_ALT.toLowerCase()) {
        result.gyro = char.uuid;
        console.log(`✓ Gyroscope identified by UUID: ${char.uuid}`);
      }
    });
    
    // Method 2: If we found both using known UUIDs, return
    if (result.accel && result.gyro) {
      console.log('✓ Both characteristics identified using known UUIDs');
      return result;
    }
    
    // Method 3: Use positional assignment as last resort
    if (characteristics.length >= 2) {
      if (!result.accel) {
        result.accel = characteristics[0].uuid;
        console.log(`Using position [0] for accelerometer: ${characteristics[0].uuid}`);
      }
      if (!result.gyro) {
        result.gyro = characteristics[1].uuid;
        console.log(` Using position [1] for gyroscope: ${characteristics[1].uuid}`);
      }
    }
    
    // Method 4: If still missing, try reverse order
    if (characteristics.length >= 2 && (!result.accel || !result.gyro)) {
      console.log('Trying reverse order assignment');
      result.accel = characteristics[1].uuid;
      result.gyro = characteristics[0].uuid;
      console.log(`Reverse: accel=${characteristics[1].uuid}, gyro=${characteristics[0].uuid}`);
    }
    
    console.log(`Final assignment: accel=${result.accel}, gyro=${result.gyro}`);
    return result;
  };

  const handleShowData = () => {
    if (readyDevices.length > 0) {
        navigation.navigate('DataDisplay', { 
            devices: readyDevices,
            characteristics: discoveredChars 
        });
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Device Connection Status</Text>
      <View style={styles.statusContainer}>
        {devices.map(device => (
          <View key={device.id} style={styles.deviceStatus}>
            <Text style={styles.deviceName}>{device.name}</Text>
            <View style={styles.statusBox}>
                <Text style={[styles.statusText, connectionStatus[device.id] === 'Failed' && styles.failedText]}>
                    {connectionStatus[device.id] || 'Pending...'}
                </Text>
                {connectionStatus[device.id]?.includes('...') && <ActivityIndicator />}
            </View>
          </View>
        ))}
      </View>
      <View style={styles.footer}>
        <Button
          title={`Show Data for ${readyDevices.length} Device(s)`}
          onPress={handleShowData}
          disabled={readyDevices.length === 0}
        />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F8F9FA', padding: 20 },
  title: { fontSize: 24, fontWeight: 'bold', textAlign: 'center', marginVertical: 30 },
  statusContainer: { backgroundColor: '#FFFFFF', borderRadius: 8, padding: 10, marginBottom: 40 },
  deviceStatus: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 20, paddingHorizontal: 10, borderBottomWidth: 1, borderBottomColor: '#EEEEEE' },
  deviceName: { fontSize: 18, fontWeight: '500' },
  statusBox: { flexDirection: 'row', alignItems: 'center' },
  statusText: { fontSize: 16, color: 'gray', marginRight: 10, },
  failedText: { color: 'red', fontWeight: 'bold' },
  footer: { marginTop: 20 },
});

export default ConnectionScreen;
