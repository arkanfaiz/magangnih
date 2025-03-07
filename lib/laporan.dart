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
  final Map<String, List<Map<dynamic, dynamic>>> _dailyData = {
    'Senin': [],
    'Selasa': [],
    'Rabu': [],
    'Kamis': [],
    'Jumat': [],
    'Sabtu': [],
    'Minggu': [],
  };

// Add this method to your _LaporanPageState class
List<FlSpot> _filterValidSpots(List<FlSpot> spots) {
  if (spots.isEmpty) return spots;
  
  // Get the min and max X values from your actual data
  final minX = spots.map((spot) => spot.x).reduce((a, b) => a < b ? a : b);
  
  // Only include spots that have valid X coordinates within the visible range
  return spots.where((spot) => 
    // Only include spots where x is greater than or equal to minX 
    // This prevents points from being plotted too far left
    spot.x >= minX &&
    // Make sure all Y values are valid numbers
    !spot.y.isNaN && 
    !spot.y.isInfinite
  ).toList();
}

  // Get minimum temperature value for a specific day
double _getMinTemperature(String day) {
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];
  if (dayData.isEmpty) return 20; // Default minimum if no data
  
  double minTemp = double.infinity;
  for (var data in dayData) {
    double? temp = double.tryParse(data['temperature'].toString());
    if (temp != null && temp < minTemp) {
      minTemp = temp;
    }
  }
  
  // If no valid temperatures found, return default
  return minTemp == double.infinity ? 20 : minTemp;
}

// Get maximum temperature value for a specific day
double _getMaxTemperature(String day) {
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];
  if (dayData.isEmpty) return 30; // Default maximum if no data
  
  double maxTemp = double.negativeInfinity;
  for (var data in dayData) {
    double? temp = double.tryParse(data['temperature'].toString());
    if (temp != null && temp > maxTemp) {
      maxTemp = temp;
    }
  }
  
  // If no valid temperatures found, return default
  return maxTemp == double.negativeInfinity ? 30 : maxTemp;
}

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

  // Add data tables for each day with the requested information
  for (String day in _daysOfWeek) {
    List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];

    if (dayData.isNotEmpty) {
      // Calculate min, max, and time of min/max temperature for this day
      double minTemp = double.infinity;
      double maxTemp = double.negativeInfinity;
      String minTempTime = "";
      String maxTempTime = "";
      
      // Calculate average temperature
      double sumTemp = 0;
      int tempCount = 0;
      
      // Calculate average humidity
      double sumHumidity = 0;
      int humidityCount = 0;
      
      for (var data in dayData) {
        // Process temperature data
        if (data['temperature'] != null && data['temperature'].toString().isNotEmpty) {
          double? temp = double.tryParse(data['temperature'].toString());
          if (temp != null) {
            // Check and update minimum temperature
            if (temp < minTemp) {
              minTemp = temp;
              minTempTime = data['time'] ?? "";
            }
            
            // Check and update maximum temperature
            if (temp > maxTemp) {
              maxTemp = temp;
              maxTempTime = data['time'] ?? "";
            }
            
            sumTemp += temp;
            tempCount++;
          }
        }
        
        // Process humidity data
        if (data['humidity'] != null && data['humidity'].toString().isNotEmpty) {
          double? humidity = double.tryParse(data['humidity'].toString());
          if (humidity != null) {
            sumHumidity += humidity;
            humidityCount++;
          }
        }
      }
      
      // Calculate averages
      double avgTemp = tempCount > 0 ? sumTemp / tempCount : 0;
      double avgHumidity = humidityCount > 0 ? sumHumidity / humidityCount : 0;
      
      // Format for display
      String avgTempFormatted = avgTemp.toStringAsFixed(1);
      String minTempFormatted = minTemp == double.infinity ? "N/A" : minTemp.toStringAsFixed(1);
      String maxTempFormatted = maxTemp == double.negativeInfinity ? "N/A" : maxTemp.toStringAsFixed(1);
      String avgHumidityFormatted = avgHumidity.toStringAsFixed(1);

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
                
                // Summary information section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Ringkasan Harian:', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Suhu Minimal: $minTempFormatted°C (Pukul $minTempTime)'),
                              pw.Text('Suhu Maksimal: $maxTempFormatted°C (Pukul $maxTempTime)'),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Suhu Rata-rata: $avgTempFormatted°C'),
                              pw.Text('Kelembapan Rata-rata: $avgHumidityFormatted%'),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Total rekaman data: ${dayData.length}'),
                    ],
                  ),
                ),
                
                // Rest of the code remains the same...
                // (Previous detailed data table and other sections)
              ],
            );
          },
        ),
      );
    }
  }

  // Rest of the method remains the same...
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

        // Urutan hari dimulai dari Jumat
        List<String> daysOrder = ["Kamis","Jumat", "Sabtu", "Minggu", "Senin", "Selasa", "Rabu", ];

        // Sorting berdasarkan hari dalam seminggu (descending), lalu tanggal, dan jam
        _temperatureData.sort((a, b) {
          // Sort by the day of the week (based on the new order starting from Friday)
          int dayComparison = daysOrder.indexOf(a['day']).compareTo(daysOrder.indexOf(b['day']));
          if (dayComparison != 0) return dayComparison;

          // Then by date (ascending)
          int dateCompare = _compareDates(a['date'], b['date']);
          if (dateCompare != 0) return dateCompare;

          // Finally by time (ascending)
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
  _timer = Timer.periodic(Duration(seconds: 30), (Timer t) {
    _loadTemperatureData(); // Call _loadTemperatureData every 2 seconds for smoother scrolling
  });
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
// Replace or update your existing _generateDayTemperatureSpots method
List<FlSpot> _generateDayTemperatureSpots(String day) {
  List<FlSpot> spots = [];
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];

  if (dayData.isEmpty) return spots;

  // Sort by time
  dayData.sort((a, b) => _convertTimeToComparable(a['time'])
      .compareTo(_convertTimeToComparable(b['time'])));

  // Find the earliest and latest time in the data
  double earliestTime = double.infinity;
  double latestTime = 0;
  
  // First pass to find time boundaries
  for (int i = 0; i < dayData.length; i++) {
    String time = dayData[i]['time'] ?? "00:00";
    List<String> timeParts = time.split(':');
    double hourDecimal = double.parse(timeParts[0]) + (double.parse(timeParts[1]) / 60);
    
    if (hourDecimal < earliestTime) {
      earliestTime = hourDecimal;
    }
    if (hourDecimal > latestTime) {
      latestTime = hourDecimal;
    }
  }
  
  // Set a reasonable minimum x value to prevent leftward extension
  // This ensures we don't plot points too far left
  double minAllowedX = earliestTime;
  
  // Second pass to create spots within the valid range
  for (int i = 0; i < dayData.length; i++) {
    String time = dayData[i]['time'] ?? "00:00";
    List<String> timeParts = time.split(':');
    double hourDecimal = double.parse(timeParts[0]) + (double.parse(timeParts[1]) / 60);

    // Only add points that are within our valid range
    if (hourDecimal >= minAllowedX && hourDecimal <= 24) {
      double? y = double.tryParse(dayData[i]['temperature'].toString());
      if (y != null) {
        spots.add(FlSpot(hourDecimal, y));
      }
    }
  }

  return spots;
}

// Get min and max X values for current day's data
// Replace or update your existing _getDayDataRange method
(double, double) _getDayDataRange(String day) {
  List<Map<dynamic, dynamic>> dayData = _dailyData[day] ?? [];
  
  if (dayData.isEmpty) return (0, 24);
  
  // Default visible range (4 hours window)
  double visibleRange = 4.0;
  
  // Get earliest and latest time entries
  dayData.sort((a, b) => _convertTimeToComparable(a['time'])
      .compareTo(_convertTimeToComparable(b['time'])));
  
  String earliestTime = dayData.first['time'] ?? "00:00";
  String latestTime = dayData.last['time'] ?? "00:00";
  
  List<String> earliestParts = earliestTime.split(':');
  List<String> latestParts = latestTime.split(':');
  
  double earliestHour = double.parse(earliestParts[0]) + (double.parse(earliestParts[1]) / 60);
  double latestHour = double.parse(latestParts[0]) + (double.parse(latestParts[1]) / 60);
  
  // Calculate min and max X values to show all data plus some padding
  double minX = earliestHour - 0.2; // Small padding to the left
  double maxX = latestHour + 0.8; // More padding to the right
  
  // Ensure min is never negative
  if (minX < 0) minX = 0;
  
  // Ensure we have at least a 2-hour window for better visualization
  if (maxX - minX < 2) {
    maxX = minX + 2;
  }
  
  // Ensure max is not beyond 24
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
                          headingRowColor: WidgetStateProperty.resolveWith(
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
                         
                          ],
                          rows: List.generate(_itemsPerPage, (index) {
                            Map data = currentPageData[index];
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

                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Daily Charts Section
            Expanded(
              flex:5 ,
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),// Replace the LineChart widget in your code with this implementation
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: LineChart(
                                  LineChartData(
                                    clipData: FlClipData.all(), // Add clipping to prevent chart elements from extending outside boundaries
                                    gridData: FlGridData(
                                      show: true,
                                      drawHorizontalLine: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: 1,
                                      verticalInterval: 1,
                                      checkToShowHorizontalLine: (value) => value % 1 == 0,
                                      checkToShowVerticalLine: (value) => value % 2 == 0,
                                    ),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value % 2 == 0 && value >= 0 && value <= 24) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 5.0),
                                                child: Text(
                                                  '${value.toInt()}:00',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                          reservedSize: 28,
                                          interval: 2,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 5.0),
                                              child: Text(
                                                '${value.toInt()}°',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            );
                                          },
                                          reservedSize: 35,
                                          interval: 5,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    // Ensure minX is actually the minimum found in the data, not a calculated window
                                    // Modify this part in your _getDayDataRange method or use a fixed minX that's within your data
                                    minX: _getDayDataRange(day).$1 > 0 ? _getDayDataRange(day).$1 : 0, // Add safety check
                                    maxX: _getDayDataRange(day).$2,
                                    minY: _getMinTemperature(day) - 1,
                                    maxY: _getMaxTemperature(day) + 1,
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                          return touchedSpots.map((LineBarSpot touchedSpot) {
                                            int hour = touchedSpot.x.toInt();
                                            int minute = ((touchedSpot.x - hour) * 60).round();
                                            String timeStr = '$hour:${minute.toString().padLeft(2, '0')}';
                                            
                                            return LineTooltipItem(
                                              '$timeStr\n${touchedSpot.y.toStringAsFixed(1)}°C',
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
                                        barWidth: 2.5,
                                        isStrokeCapRound: true,
                                        preventCurveOverShooting: true, // Prevent curves from extending beyond data points
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 3,
                                              color: Colors.red,
                                              strokeWidth: 1,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.red.withOpacity(0.2),
                                          cutOffY: _getMinTemperature(day) - 1,
                                          applyCutOffY: true,
                                        ),
                                        spots: _filterValidSpots(_generateDayTemperatureSpots(day)), // Added filtering function
                                      ),
                                    ],
                                  ),
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