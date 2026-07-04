import 'package:dio/dio.dart';

void main() async {
  final url = 'https://www.instagram.com/reel/C8-0B86t06I/'; // Example public reel
  
  try {
    print('Testing cobalt.qck.ie...');
    final res = await Dio().post(
      "https://cobalt.qck.ie/",
      data: {"url": url},
      options: Options(headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      })
    );
    print("Cobalt QCK Response: ${res.data}");
    return;
  } catch (e) {
    print("Cobalt QCK failed: $e");
  }

  try {
    print('Testing saveig.app/api/ajaxSearch...');
    final formData = FormData.fromMap({
      'q': url,
      't': 'media',
      'lang': 'en'
    });
    final res = await Dio().post(
      "https://v3.saveig.app/api/ajaxSearch",
      data: formData,
      options: Options(headers: {
        "Accept": "*/*",
      })
    );
    print("SaveIG Response: ${res.data}");
  } catch (e) {
    print("SaveIG failed: $e");
  }
}
