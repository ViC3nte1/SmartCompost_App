import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Pengaturan untuk Android
    // app_icon harus ada di folder android/app/src/main/res/drawable/
    // Jika belum ada icon khusus, gunakan '@mipmap/ic_launcher'
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Handler jika notifikasi diklik (Opsional)
      onDidReceiveNotificationResponse: (details) {
        // Logika navigasi jika perlu
      },
    );

    // Meminta izin notifikasi untuk Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification(
      int id, String title, String body, String payload) async {
    
    // Konfigurasi Detail Notifikasi agar Pop-up (High Importance)
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'compost_alert_channel', // ID Channel (bebas)
      'Compost Alerts', // Nama Channel yang muncul di setting HP
      channelDescription: 'Notifikasi bahaya untuk monitoring kompos',
      importance: Importance.max, // WAJIB MAX agar pop-up (Heads-up)
      priority: Priority.high,    // WAJIB HIGH agar pop-up
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}