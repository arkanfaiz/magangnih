// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class NagvisWebView extends StatefulWidget {
//   const NagvisWebView({super.key});

//   @override
//   _NagvisWebViewState createState() => _NagvisWebViewState();
// }

// class _NagvisWebViewState extends State<NagvisWebView> {
//   late final WebViewController _controller;

//   @override
//   void initState() {
//     super.initState();

//     // Inisialisasi WebViewController dengan benar
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..loadRequest(
//         Uri.parse(
//           'https://24ad-36-91-9-132.ngrok-free.app/nagvis/frontend/nagvis-js/index.php?mod=Map&act=view&show=test_1&user=admin&password=admin',
//         ),
//       );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('NagVis Map'),
//         backgroundColor: Colors.blueAccent,
//       ),
//       body: WebViewWidget(controller: _controller),
//     );
//   }
// }
