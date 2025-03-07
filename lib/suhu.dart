import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background task callback - MUST be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize Flutter
    WidgetsFlutterBinding.ensureInitialized();

    // Check temperature and send notification if needed
    await checkTemperatureInBackground();
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

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
    }
  } catch (e) {
    print('Error fetching temperature in background: $e');
  }
}

// Function to show notifications from background task - MUST be a top-level function
@pragma('vm:entry-point')
Future<void> _showBackgroundNotification(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    String title,
    String body,
    String channel) async {
  print('Displaying notification: $title - $body');

  try {
    // Setup notification details
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
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show notification with unique ID (using timestamp)
    final uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await flutterLocalNotificationsPlugin.show(
        uniqueId, title, body, platformChannelSpecifics,
        payload: 'temperature');

    print('Notification sent successfully with ID: $uniqueId');
  } catch (e) {
    print('Error showing notification: $e');
  }
}

class SuhuPage extends StatefulWidget {
  const SuhuPage({super.key});

  @override
  _SuhuPageState createState() => _SuhuPageState();
}

class _SuhuPageState extends State<SuhuPage> {
  double _temperature = 0.0;
  String _humidity = '';
  String _day = '';
  String _date = '';
  String _time = '';
  Timer? _timer;
  List<Map<String, String>> _temperatureList =
      []; // Added to store temperature history
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _database = FirebaseDatabase.instance.ref();
  Stream<DatabaseEvent>? _temperatureStream;

  Timer? _temperatureTimer;
  Timer? _firebaseSyncTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _registerBackgroundTasks();
    _updateTemperature();
    _updateDateTime();
    _fetchTemperatureHistory(); // Added to fetch temperature history
    _temperatureStream = _database
        .child('temperature_logs')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue;

    _firebaseSyncTimer = Timer.periodic(Duration(minutes: 1), (Timer t) {
      _updateTemperature();
      _saveTemperatureToFirebase();
    });

    // Timer for UI updates
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateTemperature();
      _updateDateTime();
    });

    // Added to refresh history periodically
    Timer.periodic(Duration(minutes: 1), (timer) {
      _fetchTemperatureHistory();
      _updateDateTime();
    });
  }

  @override
  void dispose() {
    _temperatureTimer?.cancel();
    _firebaseSyncTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification channels with proper settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Optional: Handle notification tap
        print('Notification tapped with payload: ${response.payload}');
      },
    );

    // Create notification channels with proper settings
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'danger', // channel ID
            'Critical Temperature Alerts', // channel name
            description: 'Critical temperature alerts for server monitoring',
            importance: Importance.max,
            enableLights: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'warning', // channel ID
            'Temperature Warning Alerts', // channel name
            description: 'Warning temperature alerts for server monitoring',
            importance: Importance.high,
            enableLights: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    // Request notification permissions
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _registerBackgroundTasks() async {
    // Register periodic task to check temperature every 1 minute
    await Workmanager().registerPeriodicTask(
      'temperatureCheck', // Unique name
      'checkServerTemperature', // Task name
      frequency: Duration(minutes: 1), // Set to 1 minute
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
    );

    // Also register a one-time task for immediate checking
    await Workmanager().registerOneOffTask(
      'initialTemperatureCheck',
      'checkServerTemperatureOnce',
      initialDelay: Duration(seconds: 5),
    );

    print('Background tasks registered successfully');
  }

  void _updateTemperature() async {
    final url = 'http://172.17.81.224/sensor_suhu/api/suhu_update.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double newTemperature =
            (double.tryParse(data['data'][0]['suhu'].toString()) ?? 0.0) + 0;
        String newHumidity = data['data'][0]['kelembaban'];

        setState(() {
          _temperature = newTemperature;
          _humidity = newHumidity;
        });

        // Check temperature and show notification if needed while app is in foreground
        if (_temperature > 28) {
          await _showBackgroundNotification(
              flutterLocalNotificationsPlugin,
              'DANGER: High Temperature Alert',
              'Server temperature is critically high at ${_temperature.toStringAsFixed(1)}°C',
              'danger');
        } else if (_temperature > 27) {
          await _showBackgroundNotification(
              flutterLocalNotificationsPlugin,
              'WARNING: High Temperature Alert',
              'Server temperature is high at ${_temperature.toStringAsFixed(1)}°C',
              'warning');
        } else if (_temperature < 15) {
          await _showBackgroundNotification(
              flutterLocalNotificationsPlugin,
              'WARNING: Low Temperature Alert',
              'Server temperature is low at ${_temperature.toStringAsFixed(1)}°C',
              'warning');
        }
      }
    } catch (e) {
      print('Error fetching temperature: $e');
    }
  }

 Future<void> _saveTemperatureToFirebase() async {
    if (_isSaving || _temperature == 0.0) {
      print("⚠ Data tidak valid atau sedang dalam proses penyimpanan.");
      return;
    }

    _isSaving = true;
    try {
      final now = DateTime.now();
      final int roundedMinute = (now.minute ~/ 1) * 1;
      final timeKey =
          "${now.hour.toString().padLeft(2, '0')}:${roundedMinute.toString().padLeft(2, '0')}";
      final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final timestamp = now.toUtc().millisecondsSinceEpoch;

      final snapshot = await _database
          .child('temperature_logs')
          .orderByChild('time')
          .equalTo(timeKey)
          .once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        bool existsForSameDate = data.values.any((entry) => entry['date'] == dateKey);

        if (existsForSameDate) {
          print("⚠ Data dengan waktu dan tanggal ini sudah ada.");
          return;
        }
      }

      final newDataRef = _database.child('temperature_logs').push();
      await newDataRef.set({
        'temperature': _temperature,
        'humidity': _humidity,
        'day': _day,
        'date': dateKey,
        'time': timeKey,
        'timestamp': timestamp,
      });

      print("✅ Data suhu berhasil disimpan: $_temperature°C");
    } catch (e) {
      print("❌ Gagal menyimpan ke Firebase: $e");
    } finally {
      _isSaving = false;
    }
  }


  // New method for fetching temperature history
  Future<void> _fetchTemperatureHistory() async {
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

        setState(() {
          _temperatureList = suhuList;
        });
      }
    } catch (e) {
      print('Error fetching temperature history: $e');
    }
  }

  void _updateDateTime() {
    final now = DateTime.now();
    List<String> days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    setState(() {
      _day = days[now.weekday % 7];
      _date = "${now.day}-${now.month}-${now.year}";
      _time =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    });
  }

  Widget _buildStatusIndicator(double temperature) {
    String status = 'Normal';
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    if (temperature > 28) {
      status = 'DANGER';
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber;
    } else if (temperature > 27 || temperature < 15) {
      status = 'WARNING';
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    }

    // Only show status indicator if not in normal range
    if (status == 'Normal') {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor),
          SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine temperature display color based on thresholds
    Color temperatureColor = Colors.blueAccent;
    if (_temperature > 28) {
      temperatureColor = Colors.red;
    } else if (_temperature > 27 || _temperature < 15) {
      temperatureColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Monitoring Suhu Server AOCC',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Colors.blue.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: Column(
                children: [
                  Text('${_temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: temperatureColor)),
                  _buildStatusIndicator(_temperature),
                  SizedBox(height: 20),
                  Text(_day,
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                  Text(_date,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54)),
                  SizedBox(height: 10),
                  Text(_time,
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                  SizedBox(height: 20),
                  Text('Kelembaban: $_humidity%',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Riwayat Suhu",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _temperatureList.length,
                itemBuilder: (context, index) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time section at the top with larger font and icon
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text(
                                "${_temperatureList[index]['waktu']}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 16),
                          // Temperature and humidity in a more organized layout
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Temperature section
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.thermostat, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text(
                                        "",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "${_temperatureList[index]['suhu']}°C",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              // Vertical divider between temperature and humidity
                              Container(
                                height: 50,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              // Humidity section
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.water_drop,
                                          color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text(
                                        "",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "${_temperatureList[index]['kelembaban']}%",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
