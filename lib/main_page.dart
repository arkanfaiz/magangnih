import 'package:flutter/material.dart';
import 'package:magangnih/cctv.dart';
import 'package:magangnih/laporan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:magangnih/suhu.dart';
import 'login_page.dart';
import 'package:magangnih/monitoring.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Meminta izin untuk notifikasi
    _requestNotificationPermission();

    // Inisialisasi notifikasi
    _initializeNotifications();
  }

  // Meminta izin untuk menampilkan notifikasi
  Future<void> _requestNotificationPermission() async {
    // Cek izin untuk notifikasi
    PermissionStatus status = await Permission.notification.request();
    if (status.isGranted) {
      print("Izin notifikasi diberikan");
    } else {
      print("Izin notifikasi ditolak");
    }
  }

  // Fungsi untuk inisialisasi notifikasi
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Fungsi untuk menampilkan notifikasi
  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'channel_id',
      'Network Connectivity',
      channelDescription: 'Notifikasi koneksi jaringan',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // ID notifikasi
      'No Network Connection',
      'Your device is not connected to the internet.',
      platformDetails,
    );
  }

  // Fungsi untuk logout
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MAGANG AJA",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 33, 122, 185),
        foregroundColor: Colors.white,
        elevation: 5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 121, 202, 255),
              const Color.fromARGB(255, 254, 254, 254)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed:
                    _showNotification, // Memanggil fungsi untuk menampilkan notifikasi
                child: const Text('Test Notification'),
              ),
              buildMenuButton(
                context,
                icon: Icons.thermostat,
                label: "Suhu",
                page: SuhuPage(),
              ),
              buildMenuButton(
                context,
                icon: Icons.monitor,
                label: "Nagvis",
                page: MonitoringPage(),
              ),
              buildMenuButton(
                context,
                icon: Icons.videocam,
                label: "CCTV",
                page: Cctv(),
              ),
              buildMenuButton(
                context,
                icon: Icons.article,
                label: "Laporan",
                page: LaporanPage(),
              ),
              // Logout button
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: 300,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _logout, // Logout action
                    icon: Icon(Icons.logout, size: 28),
                    label: Text(
                      "Logout",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromARGB(255, 0, 21, 255),
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side:
                            BorderSide(color: Color.fromARGB(255, 0, 21, 255)),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMenuButton(BuildContext context,
      {required IconData icon, required String label, required Widget page}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: 300,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => page));
          },
          icon: Icon(icon, size: 28),
          label: Text(
            label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 0, 21, 255),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Color.fromARGB(255, 0, 21, 255)),
            ),
            elevation: 5,
          ),
        ),
      ),
    );
  }
}
