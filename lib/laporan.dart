import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async'; // Import dart:async for Timer
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


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
  final int _itemsPerPage = 5;
  late Stream<DatabaseEvent> _dataStream;
  late Timer
      _timer; // Declare a Timer variable to handle the periodic data reload // Declare a Timer variable to handle the periodic data reload

  // Map to store data organized by days
  Map<String, List<Map<dynamic, dynamic>>> _dailyData = {
    'Senin': [],
    'Selasa': [],
    'Rabu': [],
    'Kamis': [],
    'Jumat': [],
    'Sabtu': [],
    'Minggu': [],
  };

  // Days of the week in order
  final List<String> _daysOfWeek = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  // Keep track of whether we've had 7 days of data to generate a weekly report
  bool _weeklyDataComplete = false;

  Future<void> _generateWeeklyPDF() async {
    final pdf = pw.Document();

    // Add title page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Laporan Mingguan Suhu dan Kelembaban',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text(
                    'Periode: ${DateTime.now().subtract(const Duration(days: 7)).toString().substring(0, 10)} - ${DateTime.now().toString().substring(0, 10)}',
                    style: pw.TextStyle(fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );

    // Add data tables for each day
    for (String day in _daysOfWeek) {
      List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];

      if (dayData.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Data $day',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 15),
                  pw.Table.fromTextArray(
                    context: context,
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headerDecoration:
                        pw.BoxDecoration(color: PdfColors.grey300),
                    data: <List<String>>[
                      <String>[
                        'No',
                        'Suhu (°C)',
                        'Kelembaban (%)',
                        'Tanggal',
                        'Jam'
                      ],
                      ...List.generate(dayData.length, (index) {
                        Map data = dayData[index];
                        return [
                          '${index + 1}',
                          '${data['temperature']}',
                          '${data['humidity']}',
                          '${data['date']}',
                          '${data['time']}',
                        ];
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  // Could add simple chart representation here if needed
                  pw.Text('Total rekaman data: ${dayData.length}'),
                  if (dayData.isNotEmpty)
                    pw.Text(
                        'Rata-rata suhu: ${_calculateAverageTemp(dayData)}°C'),
                  if (dayData.isNotEmpty)
                    pw.Text(
                        'Rata-rata kelembaban: ${_calculateAverageHumidity(dayData)}%'),
                ],
              );
            },
          ),
        );
      }
    }

    // Add summary page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Ringkasan Mingguan',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                data: <List<String>>[
                  <String>[
                    'Hari',
                    'Jumlah Data',
                    'Rata-rata Suhu (°C)',
                    'Rata-rata Kelembaban (%)'
                  ],
                  ..._daysOfWeek.map((day) {
                    List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];
                    return [
                      day,
                      '${dayData.length}',
                      dayData.isEmpty ? '-' : _calculateAverageTemp(dayData),
                      dayData.isEmpty
                          ? '-'
                          : _calculateAverageHumidity(dayData),
                    ];
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Calculate average temperature for a list of data points
  String _calculateAverageTemp(List<Map<dynamic, dynamic>> data) {
    if (data.isEmpty) return '0';
    double sum = 0;
    int count = 0;

    for (var item in data) {
      if (item['temperature'] != null &&
          item['temperature'].toString().isNotEmpty) {
        sum += double.tryParse(item['temperature'].toString()) ?? 0;
        count++;
      }
    }

    return count > 0 ? (sum / count).toStringAsFixed(1) : '0';
  }

  // Calculate average humidity for a list of data points
  String _calculateAverageHumidity(List<Map<dynamic, dynamic>> data) {
    if (data.isEmpty) return '0';
    double sum = 0;
    int count = 0;

    for (var item in data) {
      if (item['humidity'] != null && item['humidity'].toString().isNotEmpty) {
        sum += double.tryParse(item['humidity'].toString()) ?? 0;
        count++;
      }
    }

    return count > 0 ? (sum / count).toStringAsFixed(1) : '0';
  }

  @override
  void initState() {
    super.initState();
    _dataStream = _database.child('temperature_logs').onValue;
    _loadTemperatureData();
    _startAutoReload(); // Start the automatic data reload every 10 seconds
  }
Future<void> _loadTemperatureData() async {
  try {
    DataSnapshot snapshot = await _database.child('temperature_logs').get();
    if (snapshot.exists && snapshot.value is Map) {
      setState(() {
        _temperatureData = List.from((snapshot.value as Map).values);
        _keys = (snapshot.value as Map).keys.cast<String>().toList();

        // Urutan hari dalam seminggu
        List<String> daysOrder = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];

        // Sorting berdasarkan hari dalam seminggu, lalu tanggal, dan jam
        _temperatureData.sort((a, b) {
          int dayComparison = daysOrder.indexOf(b['day']).compareTo(daysOrder.indexOf(a['day']));
          if (dayComparison != 0) return dayComparison;
          
          int dateCompare = _compareDates(a['date'], b['date']);
          if (dateCompare != 0) return dateCompare;

          return _convertTimeToComparable(a['time']).compareTo(_convertTimeToComparable(b['time']));
        });

        // Organisasi data berdasarkan hari
        _organizeDataByDay();

        // Cek jika perlu membuat laporan mingguan
        _checkForWeeklyReportGeneration();

        // Set halaman terakhir
        if (_temperatureData.isNotEmpty) {
          _currentPage = (_temperatureData.length / _itemsPerPage).ceil() - 1;
          _currentPage = _currentPage < 0 ? 0 : _currentPage; // Pastikan tidak negatif
        }
      });
    } else {
      setState(() {
        _temperatureData = [];
        _keys = [];
        _currentPage = 0;
        _clearDailyData();
      });
      print('No data found in Firebase');
    }
  } catch (e) {
    print('Error loading data: $e');
  }
}

void _organizeDataByDay() {
  _clearDailyData();
  for (var data in _temperatureData) {
    String day = data['day'] ?? '';
    if (_daysOfWeek.contains(day)) {
      _dailyData[day]!.add(data);
    }
  }
}


  void _clearDailyData() {
    for (String day in _daysOfWeek) {
      _dailyData[day] = [];
    }
  }

  void _checkForWeeklyReportGeneration() {
    // Check if we have data for all 7 days
    int daysWithData = 0;
    for (String day in _daysOfWeek) {
      if (_dailyData[day]!.isNotEmpty) {
        daysWithData++;
      }
    }

    // If we have data for all 7 days and didn't already generate a report
    if (daysWithData == 7 && !_weeklyDataComplete) {
      _weeklyDataComplete = true;

      // Show dialog to generate report before clearing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Data Mingguan Lengkap"),
            content: const Text(
                "Data untuk 7 hari telah terkumpul. Apakah Anda ingin membuat laporan sebelum menghapus data?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Clear data without generating report
                  _deleteAll();
                  _weeklyDataComplete = false;
                },
                child: const Text("Hapus Saja",
                    style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Generate report, then clear data
                  await _generateWeeklyPDF();
                  _deleteAll();
                  _weeklyDataComplete = false;
                },
                child: const Text("Buat Laporan",
                    style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      });
    }
  }

  // Compare dates in format DD/MM/YYYY
  int _compareDates(String date1, String date2) {
    try {
      List<String> parts1 = date1.split('/');
      List<String> parts2 = date2.split('/');

      if (parts1.length == 3 && parts2.length == 3) {
        // Convert to comparable format (YYYYMMDD)
        int val1 = int.parse('${parts1[2]}${parts1[1]}${parts1[0]}');
        int val2 = int.parse('${parts2[2]}${parts2[1]}${parts2[0]}');
        return val1.compareTo(val2);
      }
    } catch (e) {
      print("Error comparing dates: $date1 vs $date2 - $e");
    }
    return 0;
  }

  // Fungsi untuk mengubah format waktu menjadi nilai yang dapat dibandingkan
  int _convertTimeToComparable(String time) {
    try {
      List<String> parts =
          time.split(':'); // Misal "14:30" dipecah menjadi ["14", "30"]
      int hours = int.parse(parts[0]); // Ambil jam
      int minutes = int.parse(parts[1]); // Ambil menit
      return (hours * 60) + minutes; // Konversi ke menit untuk perbandingan
    } catch (e) {
      print("Error parsing time: $time");
      return 0; // Default jika terjadi kesalahan
    }
  }


  void _startAutoReload() {
  _timer = Timer.periodic(Duration(seconds: 60), (Timer t) {
    _loadTemperatureData(); // Call _loadTemperatureData every 2 seconds for smoother scrolling
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
            child:
                const Text("Tidak", style: TextStyle(color: Colors.blueAccent)),
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
        _organizeDataByDay(); // Re-organize data after deletion
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
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
            child:
                const Text("Tidak", style: TextStyle(color: Colors.blueAccent)),
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
      _clearDailyData();
      _weeklyDataComplete = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua data berhasil dihapus')));
  }

  // Generate spots for line chart for a specific day
List<FlSpot> _generateDayTemperatureSpots(String day) {
  List<FlSpot> spots = [];
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];

  if (dayData.isEmpty) return spots;

  // Sort by time
  dayData.sort((a, b) => _convertTimeToComparable(a['time'])
      .compareTo(_convertTimeToComparable(b['time'])));

  for (int i = 0; i < dayData.length; i++) {
    // Convert time to hours as decimal for x-axis (e.g., "14:30" becomes 14.5)
    String time = dayData[i]['time'] ?? "00:00";
    List<String> timeParts = time.split(':');
    double hourDecimal =
        double.parse(timeParts[0]) + (double.parse(timeParts[1]) / 60);

    // Make sure x value is within 0-24 range
    if (hourDecimal >= 0 && hourDecimal < 24) {
      double? y = double.tryParse(dayData[i]['temperature'].toString());
      if (y != null) {
        spots.add(FlSpot(hourDecimal, y));
      }
    }
  }

  return spots;
}

// Get min and max X values for current day's data
(double, double) _getDayDataRange(String day) {
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];
  
  if (dayData.isEmpty) return (0, 24);
  
  // Default visible range (4 hours window)
  double visibleRange = 4.0;
  
  // Get the latest time entry
  dayData.sort((a, b) => _convertTimeToComparable(b['time'])
      .compareTo(_convertTimeToComparable(a['time'])));
  
  String latestTime = dayData.first['time'] ?? "00:00";
  List<String> timeParts = latestTime.split(':');
  double latestHour = double.parse(timeParts[0]) + (double.parse(timeParts[1]) / 60);
  
  // Calculate min and max X values to make chart automatically scroll
  double maxX = latestHour + 1; // Add 1 hour padding to the right
  double minX = maxX - visibleRange; // Show 4 hours window
  
  // Ensure min and max are within valid range
  if (minX < 0) minX = 0;
  if (maxX > 24) maxX = 24;
  
  return (minX, maxX);
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
    List<Map> currentPageData = _temperatureData.isEmpty
        ? []
        : _temperatureData.sublist(
            startIndex,
            endIndex > _temperatureData.length
                ? _temperatureData.length
                : endIndex);
    List<String> currentKeys = _keys.isEmpty
        ? []
        : _keys.sublist(
            startIndex, endIndex > _keys.length ? _keys.length : endIndex);

    while (currentPageData.length < _itemsPerPage) {
      currentPageData.add({
        'temperature': '',
        'humidity': '',
        'day': '',
        'date': '',
        'time': ''
      });
      currentKeys.add('');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateWeeklyPDF,
            tooltip: 'Simpan sebagai PDF',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Section - Now First
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3))
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Data Suhu & Kelembaban Harian',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: MaterialStateProperty.resolveWith(
                              (states) => Colors.blueAccent),
                          columns: const [
                            DataColumn(
                                label: Text('No',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Suhu',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Kelembaban',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Hari',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Tanggal',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Jam',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                            DataColumn(
                                label: Text('Aksi',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white))),
                          ],
                          rows: List.generate(_itemsPerPage, (index) {
                            Map data = currentPageData[index];
                            String key = currentKeys[index];
                            return DataRow(cells: [
                              DataCell(Text('${startIndex + index + 1}',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(Text(
                                  data['temperature'] != ''
                                      ? '${data['temperature']}°C'
                                      : '',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(Text(
                                  data['humidity'] != ''
                                      ? '${data['humidity']}%'
                                      : '',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(Text('${data['day']}',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(Text('${data['date']}',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(Text('${data['time']}',
                                  style: const TextStyle(fontSize: 16))),
                              DataCell(
                                key.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _confirmDeleteItem(
                                            startIndex + index),
                                      )
                                    : Container(),
                              ),
                            ]);
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Prev'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                        if (totalPages > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "${_currentPage + 1} / $totalPages",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: endIndex < _temperatureData.length
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _confirmDeleteAll,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Hapus Semua Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Daily Charts Section
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3))
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Grafik Suhu Harian',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _daysOfWeek.map((day) {
                            // Only show chart if there's data for this day
                            if (_dailyData[day]!.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text('Tidak ada data untuk $day',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ),
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              height: 220,
                              child: Column(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent),
                                    ),
                                  ),
                                  Expanded(
  child: LineChart(
    LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              // Only show a few hour markers
              if (value % 1 == 0 && value <= 24) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('${value.toInt()}:00'),
                );
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text('${value.toInt()}°C');
            },
            reservedSize: 40,
          ),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: true),
      // Get dynamic min and max X values
      minX: _getDayDataRange(day).$1,
      maxX: _getDayDataRange(day).$2,
      // Add these options for better scrolling behavior
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              // Convert decimal hour back to time format
              int hour = touchedSpot.x.toInt();
              int minute = ((touchedSpot.x - hour) * 60).round();
              String timeStr = '$hour:${minute.toString().padLeft(2, '0')}';
              
              return LineTooltipItem(
                '${timeStr}\n${touchedSpot.y.toStringAsFixed(1)}°C',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: Colors.red,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.red.withOpacity(0.3),
          ),
          spots: _generateDayTemperatureSpots(day),
        ),
      ],
    ),
  ),
),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}