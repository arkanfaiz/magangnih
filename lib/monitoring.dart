import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'notification_service.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late final WebViewController _controller;
  final NetworkCheck _networkCheck = NetworkCheck();
  final String nagVisUrl =
      'http://172.17.81.38/nagvis/frontend/nagvis-js/index.php?mod=Map&act=view&show=Monitoring'; // Ganti dengan URL NagVis kamu

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(nagVisUrl));

    NotificationService().init();
    _startNetworkCheck();
  }

  // Pengecekan koneksi setiap beberapa detik
  void _startNetworkCheck() {
    const duration = Duration(seconds: 30); // Set interval 30 detik
    Future.doWhile(() async {
      await Future.delayed(duration);
      bool isConnected = await _networkCheck.isNagVisConnected(nagVisUrl);
      if (!isConnected) {
        NotificationService().showNotification(
          'Error Jaringan',
          'Tidak bisa terhubung dengan NagVis, pastikan jaringan berjalan dengan baik!',
        );
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Network View")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
