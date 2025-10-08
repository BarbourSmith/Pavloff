import React, { useEffect, Component } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import 'react-native-gesture-handler';
import { createStackNavigator } from '@react-navigation/stack';
import { Platform, Alert, Text, View } from 'react-native';
import { requestMultiple, PERMISSIONS, RESULTS, check } from 'react-native-permissions';

import HomeScreen from './screens/HomeScreen';
import ConnectionScreen from './screens/ConnectionScreen';
import DataDisplayScreen from './screens/DataDisplayScreen';

// Error Boundary Component
class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('App Error Boundary caught an error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 }}>
          <Text style={{ fontSize: 18, fontWeight: 'bold', marginBottom: 10 }}>
            Something went wrong
          </Text>
          <Text style={{ textAlign: 'center', color: '#666' }}>
            The app encountered an unexpected error. Please restart the app.
          </Text>
          <Text style={{ marginTop: 10, fontSize: 12, color: '#999' }}>
            Error: {this.state.error?.message}
          </Text>
        </View>
      );
    }

    return this.props.children;
  }
}

const Stack = createStackNavigator();

const App = () => {
  useEffect(() => {
    const requestPermissions = async () => {
      try {
        if (Platform.OS === 'android') {
          const permissionsToRequest = [];
          // For Android 12 (API 31) and above
          if (Platform.Version >= 31) {
            permissionsToRequest.push(PERMISSIONS.ANDROID.BLUETOOTH_SCAN);
            permissionsToRequest.push(PERMISSIONS.ANDROID.BLUETOOTH_CONNECT);
          } else {
            // For Android 11 (API 30) and below
            permissionsToRequest.push(PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION);
          }

          const statuses = await requestMultiple(permissionsToRequest);
          const allGranted = Object.values(statuses).every(
            (status) => status === RESULTS.GRANTED
          );

          if (!allGranted) {
            console.log('Some Android permissions were not granted:', statuses);
            Alert.alert(
              'Permissions Required',
              'Bluetooth and location permissions are required to scan for and connect to devices.',
              [
                { text: 'Cancel', style: 'cancel' },
                { text: 'Settings', onPress: () => {
                  // Could open settings here if needed
                  console.log('User should go to settings to enable permissions');
                }}
              ]
            );
          } else {
            console.log('All required Android permissions granted.');
          }
        } else if (Platform.OS === 'ios') {
          // For iOS, we mainly need to check if Bluetooth is available
          // The permissions are handled through Info.plist
          console.log('iOS detected - Bluetooth permissions handled via Info.plist');
          
          // You could add additional iOS-specific checks here if needed
          // For example, checking if Bluetooth is enabled
        }
      } catch (error) {
        console.error('Error requesting permissions:', error);
        Alert.alert(
          'Permission Error',
          'Failed to request necessary permissions. The app may not function properly.',
          [{ text: 'OK' }]
        );
      }
    };

    requestPermissions();
  }, []);

  return (
    <ErrorBoundary>
      <NavigationContainer>
        <Stack.Navigator 
          initialRouteName="Home"
          screenOptions={{
            headerStyle: {
              backgroundColor: '#007BFF',
            },
            headerTintColor: '#fff',
            headerTitleStyle: {
              fontWeight: 'bold',
            },
          }}
        >
          <Stack.Screen 
            name="Home" 
            component={HomeScreen}
            options={{ title: 'BLE Device Scanner' }} 
          />
          <Stack.Screen 
            name="Connection" 
            component={ConnectionScreen}
            options={{ title: 'Connecting...' }} 
          />
          <Stack.Screen 
            name="DataDisplay" 
            component={DataDisplayScreen}
            options={{ title: 'Live IMU Data' }} 
          />
        </Stack.Navigator>
      </NavigationContainer>
    </ErrorBoundary>
  );
};

export default App;
