// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class SuhuService {
//   final String apiUrl = "http://172.17.81.224/sensor_suhu/api/suhu.php";

//   Future<Map<String, dynamic>> fetchSuhu() async {
//     final response = await http.get(Uri.parse(apiUrl));

//     if (response.statusCode == 200) {
//       var data = jsonDecode(response.body);
//       if (data['status'] == 1 && data['data'].isNotEmpty) {
//         return {
//           "suhu": double.parse(data['data'][0]['suhu']),
//           "kelembaban": int.parse(data['data'][0]['kelembaban']),
//         };
//       }
//       throw Exception("Data tidak tersedia");
//     } else {
//       throw Exception("Gagal mengambil data dari API");
//     }
//   }
// }
