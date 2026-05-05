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

  Future<void> init() async {
    tz.initializeTimeZones();

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

    await _scheduleStaticReminders();
    await scheduleMealReminders();
  }

  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    // Tıklanınca yapılacak işlem
  }

  // ── A. Hareket & Adım Bildirimleri ──
  Future<void> _scheduleStaticReminders() async {
    // 15:00 Adım kontrolü
    await _scheduleDailyTime(
      id: 100,
      title: 'Harekete Geç!',
      body: 'Günün yarısı bitti! Adım hedefinizi tamamlamak için kısa bir yürüyüşe ne dersiniz?',
      hour: 15,
      minute: 0,
    );
  }

  // ── B. Beslenme Bildirimleri ──
  Future<void> scheduleMealReminders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Varsayılan saatler veya kullanıcı seçimleri
    final breakfastTime = prefs.getString('pref_breakfast_time') ?? '09:00';
    final lunchTime = prefs.getString('pref_lunch_time') ?? '13:30';
    final dinnerTime = prefs.getString('pref_dinner_time') ?? '19:00';

    await _scheduleTimeFromString(id: 200, title: 'Kahvaltı Zamanı', body: 'Güne enerjik başlamak için kahvaltınızı kaydetmeyi unutmayın!', timeStr: breakfastTime);
    await _scheduleTimeFromString(id: 201, title: 'Öğle Yemeği', body: 'Öğle yemeği saati! Kalori ve protein hedefinize sadık mısınız?', timeStr: lunchTime);
    await _scheduleTimeFromString(id: 202, title: 'Akşam Yemeği', body: 'Akşam yemeğinizi zamanında yiyin, formunuzu koruyun!', timeStr: dinnerTime);
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Günlük Hatırlatıcılar',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
