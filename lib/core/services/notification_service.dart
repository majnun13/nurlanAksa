import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Bildirim ID'leri – iptal ederken aynılarını kullanıyoruz
  static const int _idStepReminder = 100;
  static const int _idBreakfast = 200;
  static const int _idLunch = 201;
  static const int _idDinner = 202;
  static const List<int> _mealIds = [_idBreakfast, _idLunch, _idDinner];

  Future<void> init() async {
    tz.initializeTimeZones();
    _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // B12: Kullanıcı bildirimleri kapattıysa planlama yapma
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('pref_notifications') ?? true;
    if (notificationsEnabled) {
      try {
        await _scheduleStaticReminders();
        await scheduleMealReminders();
      } catch (e) {
        // Android release modunda bildirim planlama hatası olabilir — uygulamayı çökertme
        debugPrint('[NotificationService] Bildirim planlama hatası: $e');
      }
    }
  }

  /// Cihazın yerel saat dilimini tz.local'e ata.
  /// Bu yapılmazsa bildirimler UTC saatine göre tetiklenir.
  void _configureLocalTimeZone() {
    final timeZoneName = _getDeviceTimeZone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Bilinmeyen timezone adı → UTC'ye geri dön
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  String _getDeviceTimeZone() {
    // DateTime.now().timeZoneOffset'ten IANA adı çıkarmak güvenilmez.
    // Ancak Dart'ta native timezone adı almak için en iyi yaklaşım bu.
    // iOS/Android'de genellikle DateTime.now().timeZoneName doğru döner.
    final name = DateTime.now().timeZoneName;
    // Bazı cihazlar kısaltma döndürür (ör. "TRT", "EET"), bu durumda
    // offset'e göre bilinen bir konum seçeriz.
    try {
      tz.getLocation(name);
      return name;
    } catch (_) {
      // Kısaltma geldi — offset'ten tahmin et
      final offset = DateTime.now().timeZoneOffset;
      if (offset.inHours == 3) return 'Europe/Istanbul';
      if (offset.inHours == 0) return 'UTC';
      if (offset.inHours == 1) return 'Europe/Berlin';
      if (offset.inHours == 2) return 'Europe/Athens';
      return 'UTC';
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    // Tıklanınca yapılacak işlem
  }

  // ── A. Hareket & Adım Bildirimleri ──
  Future<void> _scheduleStaticReminders() async {
    await _scheduleDailyTime(
      id: _idStepReminder,
      title: 'Harekete Geç!',
      body: 'Günün yarısı bitti! Adım hedefinizi tamamlamak için kısa bir yürüyüşe ne dersiniz?',
      hour: 15,
      minute: 0,
    );
  }

  // ── B. Beslenme Bildirimleri ──
  /// Önceki öğün bildirimlerini iptal edip, güncellenen saatlere göre yeniden planlar.
  Future<void> scheduleMealReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Kullanıcı bildirimleri kapattıysa öğün bildirimlerini de iptal et
      final notificationsEnabled = prefs.getBool('pref_notifications') ?? true;
      if (!notificationsEnabled) {
        for (final id in _mealIds) {
          await flutterLocalNotificationsPlugin.cancel(id);
        }
        return;
      }

      // Önce eski öğün bildirimlerini iptal et (saat değişikliğinde çift bildirim önlenir)
      for (final id in _mealIds) {
        await flutterLocalNotificationsPlugin.cancel(id);
      }

      // Varsayılan saatler veya kullanıcı seçimleri
      final breakfastTime = prefs.getString('pref_breakfast_time') ?? '09:00';
      final lunchTime = prefs.getString('pref_lunch_time') ?? '13:30';
      final dinnerTime = prefs.getString('pref_dinner_time') ?? '19:00';

      await _scheduleTimeFromString(id: _idBreakfast, title: 'Kahvaltı Zamanı 🍳', body: 'Güne enerjik başlamak için kahvaltınızı kaydetmeyi unutmayın!', timeStr: breakfastTime);
      await _scheduleTimeFromString(id: _idLunch, title: 'Öğle Yemeği 🥗', body: 'Öğle yemeği saati! Kalori ve protein hedefinize sadık mısınız?', timeStr: lunchTime);
      await _scheduleTimeFromString(id: _idDinner, title: 'Akşam Yemeği 🍽️', body: 'Akşam yemeğinizi zamanında yiyin, formunuzu koruyun!', timeStr: dinnerTime);
    } catch (e) {
      debugPrint('[NotificationService] scheduleMealReminders hatası: $e');
    }
  }

  Future<void> _scheduleTimeFromString({required int id, required String title, required String body, required String timeStr}) async {
    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    await _scheduleDailyTime(id: id, title: title, body: body, hour: hour, minute: minute);
  }

  Future<void> _scheduleDailyTime({required int id, required String title, required String body, required int hour, required int minute}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'daily_reminders',
          'Günlük Hatırlatıcılar',
          importance: Importance.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Tüm zamanlanmış bildirimleri iptal et (çıkış yapınca vs.)
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // ── D. Acil Anomali Bildirimi ──
  Future<void> showInstantNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'anomaly_alerts',
      'Acil Sağlık Uyarıları',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.red,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails, iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      999,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
