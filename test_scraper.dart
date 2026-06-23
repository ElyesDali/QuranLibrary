import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.instagram.com/p/C6Z7T_3M5hB/';
  final saveigUrl = Uri.parse('https://saveig.app/api/ajaxSearch');
  try {
    final res = await http.post(saveigUrl, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Requested-With': 'XMLHttpRequest'
    }, body: {
      'q': url,
      't': 'media',
      'lang': 'en'
    });
    print('SAVEIG RESPONSE: ${res.statusCode}');
    print(res.body.substring(0, res.body.length > 500 ? 500 : res.body.length));
  } catch (e) {
    print('Error: $e');
  }
}
