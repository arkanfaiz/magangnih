import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Pastikan ini diimpor
import 'package:workmanager/workmanager.dart';
import 'background_task.dart'; // Import file background_task.dart
import 'login_page.dart'; // Import halaman login
import 'main_page.dart'; // Import halaman utama

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Pastikan binding diinisialisasi

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDY5D30WSRZq_iEVvC9MY2e3Ye4700mJXE", // Ganti dengan API key Anda dari google-services.json
      appId: "1:596744547412:android:f5073d705662cb5567d1c1", // Ganti dengan appId Anda
      messagingSenderId: "596744547412", // Ganti dengan messagingSenderId Anda
      projectId: "magangnih-38abe", // Ganti dengan projectId Anda
      databaseURL: "https://magangnih-38abe-default-rtdb.firebaseio.com", // Ganti dengan databaseURL Anda
      storageBucket: "magangnih-38abe.firebasestorage.app", // Ganti dengan storageBucket Anda
    ),
  );

  // Inisialisasi Workmanager
  // Workmanager().initialize(
  //   callbackDispatcher, // Fungsi callback untuk tugas latar belakang
  //   isInDebugMode: true, // Set false untuk production
  // );

  // Daftarkan tugas periodik
  Workmanager().registerPeriodicTask(
    "1",
    "saveTemperatureTask",
    frequency: Duration(minutes: 1), // Jalankan setiap 1 menit
    inputData: <String, dynamic>{}, // Data tambahan (opsional)
  );

  // Jalankan aplikasi
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Suhu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/', // Set route awal
      routes: {
                '/': (context) => MainPage(), // Halaman utama
        '/main': (context) => LoginPage(), // Halaman login

      },
      debugShowCheckedModeBanner: false, // Nonaktifkan banner debug
    );
  }
}