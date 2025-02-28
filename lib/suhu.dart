import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

class SuhuPage extends StatefulWidget {
  const SuhuPage({super.key});

  @override
  _SuhuPageState createState() => _SuhuPageState();
}

class _SuhuPageState extends State<SuhuPage> {
  double _averageTemperature = 0.0;
  String _humidity = '';
  String _day = '';
  String _date = '';
  String _time = '';
  List<Map<String, String>> _temperatureList = [];
  final _database = FirebaseDatabase.instance.ref();
  bool _isSaving = false;
  Timer? _refreshTimer;
  Timer? _saveTimer; 

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _UpdatefetchTemperature();

    _refreshTimer = Timer.periodic(Duration(seconds: 60), (Timer t) {
      _UpdatefetchTemperature();
    });

    Timer.periodic(Duration(seconds: 1), (Timer t) {
      _updateDateTime();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _saveTimer?.cancel(); 
    super.dispose();
  }

  Future<void> _UpdatefetchTemperature() async {
    final url = 'http://172.17.81.224/sensor_suhu/api/suhu.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, String>> suhuList = (data['data'] as List)
            .map((item) => {
                  'id': item['id'].toString(),
                  'waktu': item['waktu'].toString(),
                  'kelembaban': item['kelembaban'].toString(),
                  'suhu': item['suhu'].toString(),
                })
            .toList();

        suhuList.sort((a, b) {
          return b['id']!.compareTo(a['id']!); 
        });

        suhuList = suhuList.take(50).toList();

        double totalSuhu = suhuList.fold(0.0, (sum, item) => sum + double.parse(item['suhu']!));
        double averageSuhu = suhuList.isNotEmpty ? totalSuhu / suhuList.length : 0.0;

        if (_averageTemperature != averageSuhu) {
          setState(() {
            _temperatureList = suhuList;
            _averageTemperature = double.parse(averageSuhu.toStringAsFixed(2));
            if (suhuList.isNotEmpty) {
              _humidity = suhuList.last['kelembaban']!;
            }
          });

          _saveTemperatureToFirebase();
        }

        print("✅ Data Rata-Rata suhu diperbarui. Rata-rata: $_averageTemperature°C");
      } else {
        print("❌ Gagal mendapatkan data dari API.");
      }
    } catch (e) {
      print('❌ Error fetching temperature: $e');
    }
  }

  Future<void> _saveTemperatureToFirebase() async {
    if (_isSaving || _averageTemperature == 0.0) {
      print("⚠ Data tidak valid atau sedang dalam proses penyimpanan.");
      return;
    }

    _isSaving = true;
    try {
      final now = DateTime.now();
      final int roundedMinute = (now.minute ~/ 2) * 2;
      final timeKey = "${now.hour.toString().padLeft(2, '0')}:${roundedMinute.toString().padLeft(2, '0')}";

      final timestamp = now.toUtc().millisecondsSinceEpoch;

      final snapshot = await _database.child('temperature_logs')
          .orderByChild('time')
          .equalTo(timeKey)
          .once();

      if (snapshot.snapshot.exists) {
        print("⚠ Data dengan waktu ini sudah ada.");
        return;
      }

      final newDataRef = _database.child('temperature_logs').push();
      await newDataRef.set({
        'temperature': _averageTemperature,
        'humidity': _humidity,
        'day': _day,
        'date': _date,
        'time': timeKey,
        'timestamp': timestamp,
      });

      print("✅ Data Rata-Rata suhu berhasil disimpan: $_averageTemperature°C");
    } catch (e) {
      print("❌ Gagal menyimpan ke Firebase: $e");
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: Colors.lightBlue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Average Temperature",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        "${_averageTemperature.toStringAsFixed(2)}°C",
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _temperatureList.length,
                itemBuilder: (context, index) {
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(" ${index + 1}: Suhu:${_temperatureList[index]['suhu']}°C",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      subtitle: Text(
                        "Kelembaban: ${_temperatureList[index]['kelembaban']}%\nWaktu: ${_temperatureList[index]['waktu']}",
                        style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}