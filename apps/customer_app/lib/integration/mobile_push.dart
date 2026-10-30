import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> beautyPushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM's notification payload is displayed by Android/iOS while the app is closed.
  // Never display it again here or the user receives duplicate notifications.
}

/// Optional device push. Missing/disabled Firebase never prevents sign-in or bookings.
class MobilePush with WidgetsBindingObserver {
  MobilePush._({required this.appType, required this.apiBaseUrl});
  static MobilePush? instance;
  static String? _lastOpenNotification;
  static final pendingOpen = ValueNotifier<Map<String, String>?>(null);

  static void _queueOpen(Map<String, dynamic> data) {
    final notificationId = data['notificationId'];
    if (notificationId is String && notificationId == _lastOpenNotification) return;
    if (notificationId is String) _lastOpenNotification = notificationId;
    final type = data['type'];
    final entity = data['entityId'];
    if (type is String &&
        entity is String &&
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(entity))
      pendingOpen.value = {'type': type, 'entityId': entity};
  }

  // Android is configured with google-services.json. Other platforms stay opt-in.
  static bool get enabled =>
      const bool.hasEnvironment('PUSH_NOTIFICATIONS_ENABLED')
      ? const bool.fromEnvironment('PUSH_NOTIFICATIONS_ENABLED')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const channelId = 'hii_beauty_updates';
  final String appType;
  final String apiBaseUrl;
  final _storage = const FlutterSecureStorage();
  final _local = FlutterLocalNotificationsPlugin();
  final _client = http.Client();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _retry;
  String? _lastBinding;
  bool _syncing = false;
  bool _resync = false;
  bool _disposed = false;
  String? lastError;

  static Future<void> initialize({
    required String appType,
    required String apiBaseUrl,
  }) async {
    if (!enabled ||
        kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    final service = MobilePush._(appType: appType, apiBaseUrl: apiBaseUrl);
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(beautyPushBackgroundHandler);
      await service._local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_beauty'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          try {
            final data = jsonDecode(response.payload ?? '');
            if (data is Map<String, dynamic>) _queueOpen(data);
          } catch (_) {
            /* Ignore malformed notification payloads. */
          }
        },
      );
      await service._local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              'Booking and service updates',
              description:
                  'Assignments, service updates and Hi Beauty announcements',
              importance: Importance.high,
            ),
          );
      // Foreground display uses the local plugin on both platforms, once.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      instance = service;
      service._subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          unawaited(service._show(message));
        }),
      );
      // Registration tokens match the backend Admin SDK's token targets.
      // ignore: deprecated_member_use
      service._subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((_) {
          service._lastBinding = null;
          unawaited(service.sync());
        }),
      );
      service._subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => _queueOpen(message.data),
        ),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _queueOpen(initial.data);
      WidgetsBinding.instance.addObserver(service);
      service._retry = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(service.sync()),
      );
      unawaited(service.sync());
    } catch (_) {
      service.lastError =
          'Push setup failed. Check this app’s Firebase configuration.';
      debugPrint(service.lastError);
      service.dispose();
    }
  }

  String get _sessionKey => 'hii_beauty.$appType.mobile_session';

  /// Called after login and retried after reconnect/resume; token refresh replaces the old binding.
  Future<void> sync() async {
    if (_disposed) return;
    if (_syncing) {
      _resync = true;
      return;
    }
    _syncing = true;
    try {
      final session = await _storage.read(key: _sessionKey);
      if (session == null) {
        _lastBinding = null;
        return;
      }
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (![
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ].contains(permission.authorizationStatus)) {
        lastError = 'Notifications are disabled in device settings.';
        return;
      }
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || _disposed) return;
      final binding = '$session:$token';
      if (binding == _lastBinding) return;
      final base = Uri.parse(apiBaseUrl);
      if (!base.hasAuthority ||
          !['http', 'https'].contains(base.scheme) ||
          (!kDebugMode && base.scheme != 'https') ||
          base.userInfo.isNotEmpty ||
          base.hasQuery ||
          base.hasFragment) {
        throw StateError('Invalid notification API URL');
      }
      if (await _storage.read(key: _sessionKey) != session) {
        _resync = true;
        return;
      }
      final uri = base.replace(
        path:
            '${base.path.replaceFirst(RegExp(r'/+$'), '')}/mobile/$appType/push-device',
      );
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $session',
            },
            body: jsonEncode({
              'token': token,
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200)
        throw StateError('Device registration failed');
      _lastBinding = binding;
      lastError = null;
    } catch (_) {
      lastError =
          'Push registration is unavailable; it will retry automatically.';
      debugPrint(lastError);
    } finally {
      _syncing = false;
      if (_resync && !_disposed) {
        _resync = false;
        unawaited(sync());
      }
    }
  }

  Future<void> _show(RemoteMessage message) async {
    try {
      if (_disposed || await _storage.read(key: _sessionKey) == null) return;
      final notification = message.notification;
      if (notification == null) return;
      final identity =
          '${message.data['notificationId'] ?? message.messageId ?? message.sentTime}';
      // Stable ID replaces an at-least-once retry in the notification tray.
      final id = identity.codeUnits.fold<int>(
        0,
        (value, unit) => (value * 31 + unit) & 0x7fffffff,
      );
      await _local.show(
        id: id,
        title: notification.title,
        body: notification.body,
        payload: jsonEncode(message.data),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Booking and service updates',
            importance: Importance.high,
            priority: Priority.high,
            tag: identity,
            icon: 'ic_stat_beauty',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      debugPrint('Unable to display foreground notification.');
    }
  }

  Future<void> signedOut() async {
    _lastOpenNotification = null;
    pendingOpen.value = null;
    _lastBinding = null;
    try {
      await _local.cancelAll();
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      debugPrint('Notification cleanup will finish on the next sign-in.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    if (identical(instance, this)) instance = null;
  }
}
