import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, SafeAreaView, Button, ActivityIndicator } from 'react-native';
import bleService from '../services/bleService';

// These UUIDs should match the ESP32 firmware if you revert to this screen.
const SERVICE_UUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const CHARACTERISTIC_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

const DeviceDataScreen = ({ route, navigation }) => {
  // Safely access the device from route params.
  const device = route.params?.device;

  const [deviceData, setDeviceData] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('Initializing...');

  useEffect(() => {
    // Only proceed if a valid device object was passed.
    if (!device) {
      setConnectionStatus('Error: No device provided.');
      return;
    }

    const connectAndMonitor = async () => {
      try {
        setConnectionStatus('Connecting...');
        await bleService.connectToDevice(device.id);
        setConnectionStatus('Connection Successful!');

        // Start monitoring after a brief delay.
        setTimeout(() => {
            setConnectionStatus('Monitoring...');
            bleService.monitorCharacteristic(
              device.id,
              SERVICE_UUID,
              CHARACTERISTIC_UUID,
              (data) => {
                setDeviceData(data);
              }
            );
        }, 1000);

      } catch (error) {
        setConnectionStatus('Connection Failed');
        console.error(`Failed to connect or monitor ${device.name}`, error);
      }
    };

    connectAndMonitor();

    // Cleanup on unmount: disconnect from the device if it was valid.
    return () => {
      if (device) {
        console.log(`Disconnecting from ${device.name}...`);
        bleService.disconnectFromDevice(device.id);
      }
    };
  }, [device]); // Effect depends on the device object

  // Render an error state if no device is available.
  if (!device) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.deviceContainer}>
            <Text style={styles.errorTitle}>Navigation Error</Text>
            <Text style={styles.errorText}>Device information was not received. Please go back and try again.</Text>
            <Button title="Go Back" onPress={() => navigation.goBack()} />
        </View>
      </SafeAreaView>
    );
  }

  // Render the main screen if the device exists.
  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Live Device Data</Text>
      
      <View style={styles.deviceContainer}>
        <Text style={styles.deviceName}>{device.name || 'Unnamed Device'}</Text>
        <Text style={styles.status}>{connectionStatus}</Text>
        <View style={styles.dataBox}>
            {connectionStatus === 'Connecting...' && <ActivityIndicator color="#007BFF"/>}
            <Text style={styles.dataLabel}>Received Value:</Text>
            <Text style={styles.dataValue}>{deviceData || '---'}</Text>
        </View>
      </View>

      <View style={styles.footer}>
        <Button title="Disconnect and Go Back" onPress={() => navigation.goBack()} />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
    padding: 10,
    justifyContent: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  deviceContainer: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 20,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  deviceName: {
    fontSize: 20,
    fontWeight: '600',
    textAlign: 'center',
  },
  status: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
    textAlign: 'center',
    marginBottom: 10,
  },
  dataBox: {
    marginTop: 10,
    padding: 15,
    backgroundColor: '#FAFAFA',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#EEE',
    minHeight: 100, 
    alignItems: 'center',
    justifyContent: 'center',
  },
  dataLabel: {
    fontSize: 16,
    color: '#333',
  },
  dataValue: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#007BFF',
    marginTop: 5,
  },
  footer: {
    padding: 20,
  },
  errorTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#D8000C',
    textAlign: 'center',
    marginBottom: 10,
  },
  errorText: {
    fontSize: 16,
    color: '#333',
    textAlign: 'center',
    marginBottom: 20,
  }
});

export default DeviceDataScreen;
