import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // SharedPreferences'i uygulama açılışında önceden başlat
  // Bu, tüm ekranların token'a eş zamanlı erişim race condition'ını önler
  final prefs = await SharedPreferences.getInstance();
  ApiClient.initPrefs(prefs);
  await NotificationService().init();
  runApp(const AksaApp());
}