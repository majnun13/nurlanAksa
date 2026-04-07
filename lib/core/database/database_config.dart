// ─────────────────────────────────────────────────────────────
//  DatabaseConfig – PostgreSQL bağlantı ayarları
//
//  HOST seçimi:
//    Android Emülatör  → '10.0.2.2'   (emülatörden Mac'e özel adres)
//    iOS Simulator     → 'localhost'
//    Fiziksel Cihaz    → Mac'in WiFi IP'si (ör. '192.168.1.42')
//
//  İleride Production'a geçince bu değerleri
//  flutter_dotenv veya --dart-define ile inject et.
// ─────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:postgres/postgres.dart';

class DatabaseConfig {
  DatabaseConfig._();

  // ── Platforma göre otomatik host seçimi ──────────────────
  static String get _host {
    if (Platform.isAndroid) {
      return '10.0.2.2'; // Android emülatöründe Mac = 10.0.2.2
    }
    return 'localhost';  // iOS simulator / masaüstü
  }
  static const int _port = 5432;
  static const String _database = 'aksa';
  static const String _username = 'yavuz'; // ← kendi Mac kullanıcı adınla değiştir
  static const String _password = '';       // lokal kurulumda genellikle boş

  // ── Tekil bağlantı (singleton) ────────────────────────────
  static Connection? _connection;

  /// Veritabanı bağlantısını döndürür.
  /// Bağlantı yoksa yeni bir tane açar.
  static Future<Connection> get connection async {
    if (_connection != null) {
      return _connection!;
    }
    _connection = await Connection.open(
      Endpoint(
        host: _host,
        port: _port,
        database: _database,
        username: _username,
        password: _password,
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable, // lokalde SSL kapalı
      ),
    );
    return _connection!;
  }

  /// Bağlantıyı kapatır (uygulama kapanırken çağır)
  static Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
