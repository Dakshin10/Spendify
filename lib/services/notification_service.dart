import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/state/app_state.dart';

// Top-level or static background action handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background tap or action if needed
  final payload = notificationResponse.payload;
  final actionId = notificationResponse.actionId;
  
  if (payload != null) {
    if (actionId == 'add_action') {
      AppState.instance.approveTransaction(payload);
    } else if (actionId == 'ignore_action') {
      AppState.instance.ignoreTransaction(payload);
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) async {
          final String? payload = details.payload;
          final String? actionId = details.actionId;

          if (payload != null) {
            if (actionId == 'add_action' || details.input != null) {
              await AppState.instance.approveTransaction(payload);
            } else if (actionId == 'ignore_action') {
              await AppState.instance.ignoreTransaction(payload);
            }
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      // Request permissions
      await requestPermissions();
    } catch (e) {
      debugPrint("Failed to initialize NotificationService: $e");
    }
  }

  static Future<void> requestPermissions() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static Future<void> showTransactionNotification({
    required String id,
    required String title,
    required String body,
    required bool autoAdded,
  }) async {
    final List<AndroidNotificationAction> actions = [];
    
    if (!autoAdded) {
      actions.addAll([
        const AndroidNotificationAction(
          'add_action',
          'Add',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'ignore_action',
          'Ignore',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ]);
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'spendify_sms_ingestion',
      'SMS Ingestion Alerts',
      channelDescription: 'Alerts for incoming transaction SMS messages',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: actions,
      color: const Color(0xFF00FF66), // Spendify Neon accent color
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id.hashCode,
        title,
        body,
        platformChannelSpecifics,
        payload: id,
      );
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }
}
