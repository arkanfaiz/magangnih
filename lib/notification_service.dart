import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'error_channel',
      'Error Notifications',
      channelDescription: 'Channel for NagVis network error notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }
}

class NetworkCheck {
  // Fungsi untuk mengecek status koneksi ke server NagVis
  Future<bool> isNagVisConnected(String nagVisUrl) async {
    try {
      final response = await http.get(Uri.parse(nagVisUrl));
      if (response.statusCode == 200) {
        return true; // Server terhubung dan merespon dengan baik
      } else {
        return false; // Server merespons tapi ada error (misalnya 404 atau 500)
      }
    } catch (e) {
      return false; // Tidak bisa terhubung ke server (timeout, error jaringan, dll)
    }
  }
}
