import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background task callback - MUST be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task started: $task');

    // Initialize Flutter
    WidgetsFlutterBinding.ensureInitialized();

    // Check temperature and send notification if needed
    if (task == 'checkServerTemperature' ||
        task == 'checkServerTemperatureNow') {
      await checkTemperatureInBackground();
    }

    return Future.value(true);
  });
}

// Function to check temperature in background - MUST be a top-level function
@pragma('vm:entry-point')
Future<void> checkTemperatureInBackground() async {
  print('Checking temperature in background...');

  // Initialize notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Set up the notification settings
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Ensure notification channels are created for Android
  await _createNotificationChannels(flutterLocalNotificationsPlugin);

  // Make API call to get temperature
  final url = 'http://172.17.81.224/sensor_suhu/api/suhu_update.php';
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      double temperature =
          (double.tryParse(data['data'][0]['suhu'].toString()) ?? 0.0) + 0;

      print('Background task checking temperature: $temperature°C');

      // Show notification based on temperature threshold
      if (temperature > 28) {
        await _showBackgroundNotification(
            flutterLocalNotificationsPlugin,
            'DANGER: High Temperature Alert',
            'Server temperature is critically high at ${temperature.toStringAsFixed(1)}°C',
            'danger');
      } else if (temperature > 27) {
        await _showBackgroundNotification(
            flutterLocalNotificationsPlugin,
            'WARNING: High Temperature Alert',
            'Server temperature is high at ${temperature.toStringAsFixed(1)}°C',
            'warning');
      } else if (temperature < 15) {
        await _showBackgroundNotification(
            flutterLocalNotificationsPlugin,
            'WARNING: Low Temperature Alert',
            'Server temperature is low at ${temperature.toStringAsFixed(1)}°C',
            'warning');
      }

      // Save latest temperature to shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_temperature', temperature);
      await prefs.setString('last_check_time', DateTime.now().toString());
      print('Temperature data saved to preferences');
    }
  } catch (e) {
    print('Error fetching temperature in background: $e');
  }
}

// Create notification channels - essential for Android 8+ to show notifications
@pragma('vm:entry-point')
Future<void> _createNotificationChannels(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
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

  print('Notification channels created successfully in background service');
}

// Function to show notifications from background task - MUST be a top-level function
@pragma('vm:entry-point')
Future<void> _showBackgroundNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    String title,
    String body,
    String channel) async {
  print('Preparing to display notification: $title - $body');

  try {
    // Setup notification details for high visibility
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channel, // channel ID
      'Temperature Alerts', // channel name
      channelDescription: 'Critical temperature alerts for server monitoring',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: channel == 'danger', // Keep danger notifications persistent
      autoCancel: false, // User must manually dismiss
      ticker: 'Temperature Alert',
      color: channel == 'danger' ? Colors.red : Colors.orange,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      visibility: NotificationVisibility.public, // Show on lock screen
      fullScreenIntent: channel == 'danger', // Full screen for danger alerts
      category: AndroidNotificationCategory.alarm,
      // Add icon for better visibility
      icon: '@mipmap/ic_launcher',
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show notification with unique ID (using timestamp)
    // Using a fixed ID for each type ensures we don't flood with notifications
    // but still show distinct notifications for different alert types
    final uniqueId = channel == 'danger' ? 1001 : 1002;
    await flutterLocalNotificationsPlugin.show(
        uniqueId, title, body, platformChannelSpecifics,
        payload: 'temperature');

    print('Notification sent successfully with ID: $uniqueId');
  } catch (e) {
    print('Error showing notification: $e');
  }
}
