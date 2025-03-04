import 'package:flutter/material.dart';
import 'package:magangnih/main_page.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:magangnih/temperature_service.dart';
// Import the temperature service file with the callbackDispatcher

// Main entry point
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Request necessary permissions for notifications
  await _requestPermissions();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyDY5D30WSRZq_iEVvC9MY2e3Ye4700mJXE",
        appId: "1:596744547412:android:f5073d705662cb5567d1c1",
        messagingSenderId: "596744547412",
        projectId: "magangnih-38abe",
        databaseURL: "https://magangnih-38abe-default-rtdb.firebaseio.com",
        storageBucket: "magangnih-38abe.appspot.com",
      ),
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  // Initialize notifications first with proper channels
  await initializeNotifications();

  // Initialize Workmanager - this is critical for background tasks
  await Workmanager().initialize(
    callbackDispatcher, // This should now work with the properly imported function
    isInDebugMode: true, // Set to true for better debugging
  );

  // Cancel any existing tasks first to avoid duplicates
  await Workmanager().cancelAll();

  // Register periodic background task - every 15 minutes
  // Note: Android has limitations on how frequently background tasks can run
  await Workmanager().registerPeriodicTask(
    'temperatureCheck',
    'checkServerTemperature',
    frequency:
        Duration(minutes: 15), // Set to 15 minutes for better battery life
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
    ),
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: Duration(minutes: 1),
  );

  // Also register a one-time task to check temperature immediately
  await Workmanager().registerOneOffTask(
    'immediateTemperatureCheck',
    'checkServerTemperatureNow',
    initialDelay: Duration(seconds: 10),
  );

  // Run the app
  runApp(const MyApp());
}

// Function to request all necessary permissions
Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    // Request necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      // Important for background execution
      Permission.ignoreBatteryOptimizations,
    ].request();

    print('Notification permission: ${statuses[Permission.notification]}');
    print(
        'Battery optimization permission: ${statuses[Permission.ignoreBatteryOptimizations]}');

    // For Android 12+, request additional permissions if needed
    if (await Permission.systemAlertWindow.isGranted == false) {
      await Permission.systemAlertWindow.request();
      print('System alert window permission requested');
    }
  }
}

// Initialize notifications with proper high-priority channels
Future<void> initializeNotifications() async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Setup notification channel for Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
      print('Notification tapped with payload: ${response.payload}');
    },
  );

  // Create high-priority notification channels
  if (Platform.isAndroid) {
    // Create the danger notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'danger', // ID
            'Critical Temperature Alerts', // Name
            description: 'Critical high temperature notifications',
            importance: Importance.max,
            playSound: true,
            enableLights: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    // Create the warning notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'warning', // ID
            'Temperature Warnings', // Name
            description: 'Warnings for temperature anomalies',
            importance: Importance.high,
            playSound: true,
            enableLights: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    print('Notification channels created successfully');
  }

  // Request notification permission
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}
