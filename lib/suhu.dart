import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

class suhupage extends StatefulWidget {
  const suhupage({super.key});

  @override
  _SuhuPageState createState() => _SuhuPageState();
}

class _SuhuPageState extends State<suhupage> {
  double _temperature = 0.0;
  String _humidity = '';
  String _day = '';
  String _date = '';
  String _time = '';

  final _database = FirebaseDatabase.instance.ref();
  Stream<DatabaseEvent>? _temperatureStream;

  Timer? _temperatureTimer;
  Timer? _firebaseSyncTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _temperatureStream = _database.child('temperature_logs').orderByChild('timestamp').limitToLast(1).onValue;

    // Menyimpan data suhu ke Firebase setiap 1 menit tanpa membuka halaman suhu
    _firebaseSyncTimer = Timer.periodic(Duration(minutes: 1), (Timer t) {
      _updateTemperature();
      _saveTemperatureToFirebase();
    });

    // Memperbarui waktu setiap detik
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      _updateDateTime();
    });
  }

  @override
  void dispose() {
    _temperatureTimer?.cancel();
    _firebaseSyncTimer?.cancel();
    super.dispose();
  }

  void _updateTemperature() async {
    final url = 'http://172.17.81.224/sensor_suhu/api/suhu_update.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Data API: $data");
        setState(() {
          _temperature = double.parse(data['data'][0]['suhu']);
          _humidity = data['data'][0]['kelembaban'];
        });
      } else {
        print('⚠️ Gagal memuat data suhu dan kelembaban');
      }
    } catch (e) {
      print('❌ Error fetching data: $e');
    }
  }

  Future<void> _saveTemperatureToFirebase() async {
    if (_isSaving) {
      print("⚠️ Penyimpanan masih berlangsung, abaikan permintaan baru.");
      return;
    }

    _isSaving = true;

    try {
      final now = DateTime.now();
      final timestamp = now.toUtc().millisecondsSinceEpoch;
      final timeKey = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final snapshot = await _database.child('temperature_logs')
          .orderByChild('timestamp')
          .equalTo(timestamp)
          .once();

      if (snapshot.snapshot.exists) {
        print("⚠️ Data dengan timestamp ini sudah ada di Firebase.");
        return;
      }

      if (_temperature == 0.0) {
        print("⚠️ Suhu tidak valid, tidak menyimpan data.");
        return;
      }

      final newDataRef = _database.child('temperature_logs').push();
      await newDataRef.set({
        'temperature': _temperature,
        'humidity': _humidity,
        'day': _day,
        'date': _date,
        'time': timeKey,
        'timestamp': timestamp,
      });

      print("✅ Data suhu berhasil disimpan pada $timeKey dengan ID: ${newDataRef.key}");
    } catch (e) {
      print("❌ Gagal menyimpan data suhu ke Firebase: $e");
    } finally {
      _isSaving = false;
    }
  }

  void _updateDateTime() {
    final now = DateTime.now();
    List<String> days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    setState(() {
      _day = days[now.weekday % 7];
      _date = "${now.day}-${now.month}-${now.year}";
      _time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monitoring Suhu Server AOCC', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      backgroundColor: Colors.blue.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder(
              stream: _temperatureStream,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(child: CircularProgressIndicator());
                }
                final data = (snapshot.data!.snapshot.value as Map<dynamic, dynamic>).values.last;
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('${data['temperature']}°C', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      SizedBox(height: 20),
                      Text(data['day'], style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                      Text(data['date'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.black54)),
                      SizedBox(height: 10),
                      Text(_time, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent)), // Menampilkan waktu realtime
                      SizedBox(height: 20),
                      Text('Kelembaban: ${data['humidity']}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.black54)),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _saveTemperatureToFirebase,
                child: Text("Simpan Data ke Firebase"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
