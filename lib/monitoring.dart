import 'package:flutter/material.dart';
// Impor kDebugMode
import 'package:webview_flutter/webview_flutter.dart'; // Impor WebView
import 'notification_service.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late WebViewController _controller;
  final NetworkCheck _networkCheck = NetworkCheck();
  final String nagVisUrl =
      'http://172.17.81.38/nagvis/frontend/nagvis-js/index.php?mod=Map&act=view&show=Monitoring'; // URL tanpa parameter login

  @override
  void initState() {
    super.initState();
    // Inisialisasi WebViewController
    _initializeWebView();
    NotificationService().init();
    _startNetworkCheck();
  }

  // Inisialisasi WebView
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            // Tunggu 2 detik sebelum menjalankan JavaScript untuk memberi waktu halaman dimuat
            await Future.delayed(const Duration(seconds: 2));

            // Jalankan script JavaScript untuk login otomatis
            await _controller.runJavaScript('''
              console.log('Mengisi formulir login...');
              var usernameField = document.getElementById('username');
              var passwordField = document.getElementById('password');
              if (usernameField && passwordField) {
                usernameField.value = 'monitor';  // Isi dengan username
                passwordField.value = 'monitor';  // Isi dengan password
                console.log('Formulir diisi, mengirim...');
                document.getElementById('loginForm').submit();  // Kirim formulir login
              } else {
                console.log('Formulir login tidak ditemukan');
              }
            ''');
          },
          onPageStarted: (String url) {
            // Menambahkan log ketika halaman dimulai, bisa digunakan untuk debugging
            print("Page started loading: $url");
          },
          onWebResourceError: (WebResourceError error) {
            // Menambahkan log jika terjadi error pada halaman
            print("Web resource error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(nagVisUrl)); // Memuat URL tanpa parameter login
  }

  // Cek koneksi jaringan setiap beberapa detik
  void _startNetworkCheck() {
    const duration = Duration(seconds: 30); // Set interval ke 30 detik
    Future.doWhile(() async {
      await Future.delayed(duration);
      bool isConnected = await _networkCheck.isNagVisConnected(nagVisUrl);
      if (!isConnected) {
        NotificationService().showNotification(
          'Network Error',
          'Unable to connect to NagVis, please ensure the network is functioning properly!',
        );
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Network View")),
      body: WebViewWidget(
        controller: _controller,
      ),
    );
  }
}