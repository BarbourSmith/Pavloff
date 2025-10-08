import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  Button,
  FlatList,
  ActivityIndicator,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  Alert,
} from 'react-native';
import bleService from '../services/bleService';
import { useFocusEffect } from '@react-navigation/native';

const HomeScreen = ({ navigation }) => {
  const [isScanning, setIsScanning] = useState(false);
  const [scannedDevices, setScannedDevices] = useState([]);
  const [selectedDevices, setSelectedDevices] = useState([]);
  const [scanError, setScanError] = useState(null);
  const [scanTimeoutId, setScanTimeoutId] = useState(null);

  // Clear state when the screen comes into focus
  useFocusEffect(
    useCallback(() => {
      // Clear previous state
      setScannedDevices([]);
      setSelectedDevices([]);
      setScanError(null);
      
      // Stop any ongoing scan and clear timeout
      if (isScanning) {
        bleService.stopScanning();
        setIsScanning(false);
      }
      if (scanTimeoutId) {
        clearTimeout(scanTimeoutId);
        setScanTimeoutId(null);
      }
    }, [isScanning, scanTimeoutId])
  );

  const handleScan = async () => {
    if (isScanning) {
      // Stop scanning if currently scanning
      console.log('[SCAN] User requested to stop scanning');
      bleService.stopScanning();
      
      // Clear the timeout if it exists
      if (scanTimeoutId) {
        clearTimeout(scanTimeoutId);
        setScanTimeoutId(null);
      }
      
      setIsScanning(false);
      setScanError(null);
      Alert.alert('Scan Stopped', 'Device scanning has been stopped.');
      return;
    }

    // Start scanning
    setIsScanning(true);
    setScanError(null);
    setScannedDevices([]);
    
    const deviceMap = new Map();

    try {
      // Check BLE state before scanning
      const bleState = await bleService.getBleState();
      if (bleState !== 'PoweredOn') {
        throw new Error(`Bluetooth is ${bleState}. Please enable Bluetooth and try again.`);
      }

      console.log('[SCAN] Starting device scan...');
      bleService.scanForDevices(
        (device) => {
          console.log(`[SCAN] Found device: ${device.name} (${device.id})`);
          if (!deviceMap.has(device.id)) {
            deviceMap.set(device.id, device);
            setScannedDevices(Array.from(deviceMap.values()));
          }
        },
        (error) => {
          console.error('[SCAN] Scan error:', error);
          setScanError(error.message);
          setIsScanning(false);
          if (scanTimeoutId) {
            clearTimeout(scanTimeoutId);
            setScanTimeoutId(null);
          }
        }
      );

      // Stop scanning after timeout
      const timeoutId = setTimeout(() => {
        console.log('[SCAN] Scan timeout reached');
        setIsScanning(false);
        setScanTimeoutId(null);
        if (deviceMap.size === 0) {
          setScanError('No devices found. Make sure your ESP32 devices are powered on and advertising.');
        } else {
          console.log(`[SCAN] Scan completed. Found ${deviceMap.size} devices.`);
        }
      }, bleService.CONFIG.SCAN_TIMEOUT);
      
      setScanTimeoutId(timeoutId);
      
    } catch (error) {
      console.error('[SCAN] Failed to start scan:', error);
      setScanError(error.message);
      setIsScanning(false);
      if (scanTimeoutId) {
        clearTimeout(scanTimeoutId);
        setScanTimeoutId(null);
      }
    }
  };

  const handleToggleSelectDevice = (device) => {
    setSelectedDevices(prevSelected => {
      const isSelected = prevSelected.find(d => d.id === device.id);
      if (isSelected) {
        return prevSelected.filter(d => d.id !== device.id);
      } else {
        // Allow selecting up to 2 devices
        if (prevSelected.length < 2) {
            return [...prevSelected, device];
        } else {
            Alert.alert("Limit Reached", "You can select a maximum of two devices.");
            return prevSelected;
        }
      }
    });
  };

  const handleProceed = () => {
    if (selectedDevices.length > 0) {
      navigation.navigate('Connection', { devices: selectedDevices });
    } else {
      Alert.alert('No Devices Selected', 'Please select at least one device to proceed.');
    }
  };

  const renderDeviceItem = ({ item }) => {
    const isSelected = selectedDevices.some(d => d.id === item.id);
    return (
      <TouchableOpacity
        style={[styles.deviceItem, isSelected && styles.selectedDeviceItem]}
        onPress={() => handleToggleSelectDevice(item)}>
        <Text style={styles.deviceTextName}>{item.name}</Text>
        <Text style={styles.deviceTextId}>{item.id}</Text>
      </TouchableOpacity>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Select Devices (1 or 2)</Text>
        <Button
          title={isScanning ? 'Stop Scan' : 'Scan for Devices'}
          onPress={handleScan}
          color={isScanning ? '#F44336' : '#007BFF'}
        />
        {isScanning && (
          <Text style={styles.scanningText}>
            Scanning for devices... ({Math.floor(bleService.CONFIG.SCAN_TIMEOUT / 1000)}s timeout)
          </Text>
        )}
      </View>

      {isScanning && <ActivityIndicator size="large" color="#007BFF" style={styles.loader} />}

      {scanError && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{scanError}</Text>
        </View>
      )}

      <FlatList
        data={scannedDevices}
        keyExtractor={item => item.id}
        renderItem={renderDeviceItem}
        ListEmptyComponent={
          !isScanning && !scanError ? (
            <Text style={styles.emptyText}>No devices found. Press "Scan" to begin.</Text>
          ) : null
        }
        contentContainerStyle={styles.listContainer}
      />

      <View style={styles.footer}>
        <Text style={styles.selectedCount}>
          {selectedDevices.length} device(s) selected
        </Text>
        <Button
          title="Proceed to Connect"
          onPress={handleProceed}
          disabled={selectedDevices.length === 0}
        />
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F8F9FA' },
  header: { padding: 20, backgroundColor: '#FFFFFF', borderBottomWidth: 1, borderBottomColor: '#E0E0E0' },
  title: { fontSize: 22, fontWeight: 'bold', textAlign: 'center', marginBottom: 15 },
  scanningText: { fontSize: 12, color: '#666666', textAlign: 'center', marginTop: 10, fontStyle: 'italic' },
  loader: { marginVertical: 20 },
  errorContainer: { 
    backgroundColor: '#FFEBEE', 
    padding: 15, 
    margin: 10, 
    borderRadius: 8, 
    borderLeftWidth: 4, 
    borderLeftColor: '#F44336' 
  },
  errorText: { fontSize: 14, color: '#C62828', textAlign: 'center' },
  listContainer: { paddingHorizontal: 10, paddingBottom: 120 },
  deviceItem: { backgroundColor: '#FFFFFF', padding: 20, marginVertical: 6, borderRadius: 8, borderWidth: 2, borderColor: '#DDDDDD' },
  selectedDeviceItem: { borderColor: '#007BFF', backgroundColor: '#E9F5FF' },
  deviceTextName: { fontSize: 16, fontWeight: '600' },
  deviceTextId: { fontSize: 12, color: '#6c757d', marginTop: 4 },
  emptyText: { textAlign: 'center', marginTop: 50, fontSize: 16, color: '#6c757d' },
  footer: { position: 'absolute', bottom: 0, left: 0, right: 0, padding: 20, borderTopWidth: 1, borderTopColor: '#E0E0E0', backgroundColor: '#FFFFFF' },
  selectedCount: { textAlign: 'center', marginBottom: 10, fontSize: 16, fontWeight: '500' },
});

export default HomeScreen;
