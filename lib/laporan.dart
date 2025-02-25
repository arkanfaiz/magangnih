import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // Import dart:async for Timer

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  _LaporanPageState createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  final _database = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _temperatureData = [];
  List<String> _keys = [];
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  late Stream<DatabaseEvent> _dataStream;
  late Timer _timer; // Declare a Timer variable to handle the periodic data reload

  @override
  void initState() {
    super.initState();
    _dataStream = _database.child('temperature_logs').onValue;
    _loadTemperatureData();
    _startAutoReload(); // Start the automatic data reload every 10 seconds
  }

  void _loadTemperatureData() {
    _dataStream.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists && snapshot.value is Map) {
        setState(() {
          _keys = (snapshot.value as Map).keys.cast<String>().toList();
          _temperatureData = List.from((snapshot.value as Map).values);
          _temperatureData.sort((a, b) => _convertTimeToComparable(a['time']).compareTo(_convertTimeToComparable(b['time'])));

          int totalPages = (_temperatureData.length / _itemsPerPage).ceil();
          _currentPage = totalPages > 0 ? totalPages - 1 : 0;
        });
      } else {
        setState(() {
          _temperatureData = [];
          _keys = [];
          _currentPage = 0;
        });
      }
    });
  }

  // Fungsi untuk mengubah format waktu menjadi nilai yang dapat dibandingkan
  int _convertTimeToComparable(String time) {
    try {
      List<String> parts = time.split(':'); // Misal "14:30" dipecah menjadi ["14", "30"]
      int hours = int.parse(parts[0]); // Ambil jam
      int minutes = int.parse(parts[1]); // Ambil menit
      return (hours * 60) + minutes; // Konversi ke menit untuk perbandingan
    } catch (e) {
      print("Error parsing time: $time");
      return 0; // Default jika terjadi kesalahan
    }
  }

  // Function to automatically reload data every 10 seconds
  void _startAutoReload() {
    _timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      _loadTemperatureData(); // Call _loadTemperatureData every 10 seconds
    });
  }

  void _confirmDeleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus"),
        content: const Text("Apakah Anda yakin ingin menghapus data ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tidak", style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(index);
            },
            child: const Text("Ya", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) async {
    if (index >= 0 && index < _keys.length) {
      String keyToDelete = _keys[index]; // Simpan key yang akan dihapus
      await _database.child('temperature_logs').child(keyToDelete).remove();
      
      // Hapus item dari daftar lokal untuk menghindari flickering di UI
      setState(() {
        _keys.removeAt(index);
        _temperatureData.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dihapus'))
      );
    }
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Hapus Semua"),
        content: const Text("Apakah Anda yakin ingin menghapus semua data?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tidak", style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAll();
            },
            child: const Text("Ya", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteAll() async {
    await _database.child('temperature_logs').remove();
    
    setState(() {
      _temperatureData.clear();
      _keys.clear();
      _currentPage = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua data berhasil dihapus'))
    );
  }

  @override
  void dispose() {
    // Make sure to cancel the timer when the widget is disposed
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (_temperatureData.length / _itemsPerPage).ceil();
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    List<Map> currentPageData = _temperatureData.sublist(
      startIndex, endIndex > _temperatureData.length ? _temperatureData.length : endIndex);
    List<String> currentKeys = _keys.sublist(
      startIndex, endIndex > _keys.length ? _keys.length : endIndex);

    while (currentPageData.length < _itemsPerPage) {
      currentPageData.add({'temperature': '', 'humidity': '', 'day': '', 'date': '', 'time': ''});
      currentKeys.add('');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  const Text(
                    'Data Suhu & Kelembaban Harian',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 10),
                  // Navigasi Halaman (Prev/Next)
                  
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.blueAccent),
                      columns: const [
                        DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Suhu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Kelembaban', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Hari', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Jam', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      ],
                      rows: List.generate(_itemsPerPage, (index) {
                        Map data = currentPageData[index];
                        String key = currentKeys[index];
                        return DataRow(cells: [
                          DataCell(Text('${startIndex + index + 1}', style: const TextStyle(fontSize: 16))),
                          DataCell(Text('${data['temperature']}°C', style: const TextStyle(fontSize: 16))),
                          DataCell(Text('${data['humidity']}%', style: const TextStyle(fontSize: 16))),
                          DataCell(Text('${data['day']}', style: const TextStyle(fontSize: 16))),
                          DataCell(Text('${data['date']}', style: const TextStyle(fontSize: 16))),
                          DataCell(Text('${data['time']}', style: const TextStyle(fontSize: 16))),
                          DataCell(
                            key.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDeleteItem(startIndex + index),
                                )
                              : Container(),
                          ),
                        ]);
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _currentPage > 0 ? () {
                          setState(() {
                            _currentPage--;
                          });
                        } : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Prev'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "${_currentPage + 1} / $totalPages",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: endIndex < _temperatureData.length ? () {
                          setState(() {
                            _currentPage++;
                          });
                        } : null,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _confirmDeleteAll,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Hapus Semua Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}