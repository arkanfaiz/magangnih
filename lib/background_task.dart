import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart'; // Tambahkan ini
import 'package:firebase_database/firebase_database.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Inisialisasi Firebase
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

      // Ambil data suhu dari API
      final url = 'http://172.17.81.224/sensor_suhu/api/suhu_update.php';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temperature = double.parse(data['data'][0]['suhu']);
        final humidity = data['data'][0]['kelembaban'];

        // Simpan data ke Firebase
        final database = FirebaseDatabase.instance.ref();
        final now = DateTime.now();
        final timestamp = now.toUtc().millisecondsSinceEpoch;
        final timeKey = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

        await database.child('temperature_logs').push().set({
          'temperature': temperature,
          'humidity': humidity,
          'day': _getDay(now.weekday),
          'date': "${now.day}-${now.month}-${now.year}",
          'time': timeKey,
          'timestamp': timestamp,
        });

        print("✅ Data suhu berhasil disimpan ke Firebase pada $timeKey");
        return true; // Tugas berhasil
      } else {
        print("⚠️ Gagal mengambil data suhu dari API");
        return false; // Tugas gagal
      }
    } catch (e) {
      print("❌ Error: $e");
      return false; // Tugas gagal
    }
  });
}

String _getDay(int weekday) {
  List<String> days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
  return days[weekday % 7];
}