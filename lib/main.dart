// lib/main.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';


// ─── Screens ─────────────────────────────────────────────────────────────────
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/review_screen.dart';
import 'screens/role_selection_screen.dart';

import 'screens/customer/customer_home.dart';
import 'screens/customer/customer_craftsmen.dart';
import 'screens/customer/customer_profile_screen.dart';
import 'screens/customer/craftsman_detail_screen.dart';
import 'screens/customer/craftsman_map_screen.dart';
import 'screens/customer/deposit_payment_screen.dart';
import 'screens/customer/service_request_screen.dart';
import 'screens/customer/create_work_order_screen.dart';
import 'screens/customer/customer_work_orders_screen.dart';
import 'screens/customer/work_order_payment_screen.dart';
import 'screens/customer/customer_requests_screen.dart';

import 'screens/craftsman/craftsman_home.dart';
import 'screens/craftsman/craftsman_portfolio_screen.dart';
import 'screens/craftsman/craftsman_calendar_screen.dart';
import 'screens/craftsman/craftsman_requests_screen.dart';
import 'screens/craftsman/craftsman_profile_screen.dart';
import 'screens/craftsman/craftsman_work_orders_screen.dart';

import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_craftsmen_screen.dart';
import 'screens/admin/admin_reviews_screen.dart';

// ─── Providers ───────────────────────────────────────────────────────────────
import 'providers/locale_provider.dart';
import 'providers/review_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/craftsman_provider.dart';
import 'providers/geo_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/wishlist_provider.dart';

// ─── Globals ─────────────────────────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─── Localization ─────────────────────────────────────────────────────────────
const List<String> _supportedLocaleCodes = [
  'sk', 'cs', 'en', 'uk', 'hu', 'pl', 'de', 'fr',
  'es', 'it', 'ru', 'tr', 'nl', 'da', 'sv', 'no',
  'fi', 'hr', 'pt', 'zh', 'hi', 'sw', 'ar', 'ja',
];

const List<Locale> _supportedLocales = [
  Locale('sk'), Locale('cs'), Locale('en'), Locale('uk'),
  Locale('hu'), Locale('pl'), Locale('de'), Locale('fr'),
  Locale('es'), Locale('it'), Locale('ru'), Locale('tr'),
  Locale('nl'), Locale('da'), Locale('sv'), Locale('no'),
  Locale('fi'), Locale('hr'), Locale('pt'), Locale('zh'),
  Locale('hi'), Locale('sw'), Locale('ar'), Locale('ja'),
];

// ─── FCM Background ───────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

// ─── Notification Payload ─────────────────────────────────────────────────────
String? _buildPayload(Map<String, dynamic> data) {
  final screen    = data['screen']    as String?;
  final bookingId = data['bookingId'] as String?;
  final requestId = data['requestId'] as String?;
  final orderId   = data['workOrderId'] as String?;
  if (screen == 'work_order' && orderId != null) return 'work_order:$orderId';
  if (screen == 'booking_detail' && bookingId != null) return 'booking_detail:$bookingId';
  if (screen == 'service_request' && requestId != null) return 'service_request:$requestId';
  if (screen != null && screen.startsWith('chat:')) return screen;
  return screen;
}

void _handleNotificationTap(String? payload) {
  if (payload == null) return;
  if (payload.startsWith('work_order:')) {
    navigatorKey.currentState?.pushNamed('/customer_work_orders');
    return;
  }
  if (payload.startsWith('booking_detail:')) {
    navigatorKey.currentState?.pushNamed('/booking_detail',
        arguments: payload.split(':')[1]);
    return;
  }
  if (payload.startsWith('service_request:')) {
    navigatorKey.currentState?.pushNamed('/craftsman_requests');
    return;
  }
  if (payload.startsWith('chat:')) {
    final parts = payload.split(':');
    if (parts.length >= 3) {
      navigatorKey.currentState?.pushNamed('/chat',
          arguments: {'conversationId': parts[1], 'receiverId': parts[2]});
    }
    return;
  }
  switch (payload) {
    case 'customer_bookings':
      navigatorKey.currentState?.pushNamed('/customer_bookings'); break;
    case 'customer_work_orders':
      navigatorKey.currentState?.pushNamed('/customer_work_orders'); break;
    case 'craftsman_work_orders':
      navigatorKey.currentState?.pushNamed('/craftsman_work_orders'); break;
    case 'craftsman_bookings':
      navigatorKey.currentState?.pushNamed('/craftsman_bookings'); break;
    case 'craftsman_requests':
      navigatorKey.currentState?.pushNamed('/craftsman_requests'); break;
  }
}

// ─── FCM Token ────────────────────────────────────────────────────────────────
String? _cachedFcmToken;
String? _cachedFcmUid;

Future<void> saveFcmToken(String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    if (_cachedFcmUid != uid) {
      _cachedFcmToken = null;
      _cachedFcmUid   = uid;
    }
    if (token == _cachedFcmToken) return;
    _cachedFcmToken = token;
    final tokenData = {
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    };
    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(uid).set(
        tokenData, SetOptions(merge: true));
    final userDoc = await db.collection('users').doc(uid).get();
    final role =
        (userDoc.data()?['role'] as String?)?.trim().toLowerCase() ?? '';
    if (role == 'craftsman') {
      final craftsmanDoc =
          await db.collection('craftsmen').doc(uid).get();
      if (craftsmanDoc.exists) {
        await db.collection('craftsmen').doc(uid).update(tokenData);
      }
    }
    debugPrint('FCM: token uložený pre $uid');
  } catch (e) {
    debugPrint('FCM: chyba pri ukladaní tokenu: $e');
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prvý frame hneď — žiadna čierna obrazovka počas Firebase/init.
  runApp(const HomieBootstrap());
}

/// Zobrazí loader okamžite, potom spustí plnú aplikáciu po inicializácii.
class HomieBootstrap extends StatefulWidget {
  const HomieBootstrap({super.key});

  @override
  State<HomieBootstrap> createState() => _HomieBootstrapState();
}

class _HomieBootstrapState extends State<HomieBootstrap> {
  Widget? _app;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await EasyLocalization.ensureInitialized();

      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        if (!e.toString().contains('duplicate-app')) rethrow;
      }

      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } catch (e) {
        debugPrint('Firebase App Check: $e');
      }

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      const bookingsChannel = AndroidNotificationChannel(
          'bookings_channel', 'Rezervácie',
          description: 'Notifikácie o rezerváciách termínov',
          importance: Importance.max);
      const requestsChannel = AndroidNotificationChannel(
          'requests_channel', 'Požiadavky',
          description: 'Notifikácie o nových požiadavkách na služby',
          importance: Importance.defaultImportance);
      const chatChannel = AndroidNotificationChannel(
          'chat_channel', 'Správy',
          description: 'Správy od remeselníkov a zákazníkov',
          importance: Importance.high);
      const workOrdersChannel = AndroidNotificationChannel(
          'work_orders_channel', 'Objednávky práce',
          description: 'Notifikácie o objednávkach a platbách',
          importance: Importance.max);

      for (final channel in [
        bookingsChannel,
        requestsChannel,
        chatChannel,
        workOrdersChannel,
      ]) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (details) =>
            _handleNotificationTap(details.payload),
      );

      Stripe.publishableKey =
          'pk_test_51T4hLc7rtEYv7RoYZsJradFs3GS7K5iqnbua9eDquWNB0SWi5lBBLIY1H7m7ovNJqheROrA3iHuyn6KfhgZikSvf003veJdyZT';
      try {
        await Stripe.instance.applySettings();
      } catch (e) {
        debugPrint('Stripe applySettings: $e');
      }

      final systemLocale =
          WidgetsBinding.instance.platformDispatcher.locale;
      final startLocale =
          _supportedLocaleCodes.contains(systemLocale.languageCode)
              ? Locale(systemLocale.languageCode)
              : const Locale('en');

      if (!mounted) return;
      setState(() {
        _app = EasyLocalization(
          supportedLocales: _supportedLocales,
          path: 'assets/translations',
          fallbackLocale: const Locale('sk'),
          startLocale: startLocale,
          saveLocale: false,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                  create: (_) => LocaleProvider(), lazy: false),
              ChangeNotifierProvider(
                  create: (_) => ReviewProvider(), lazy: true),
              ChangeNotifierProvider(
                  create: (_) => AdminProvider(), lazy: true),
              ChangeNotifierProvider(
                  create: (_) => CraftsmanProvider(), lazy: true),
              ChangeNotifierProvider(
                  create: (_) => GeoProvider(), lazy: true),
              ChangeNotifierProvider(
                  create: (_) => ChatProvider(), lazy: true),
              ChangeNotifierProvider(
                  create: (_) => WishlistProvider(), lazy: true),
            ],
            child: const HomieApp(),
          ),
        );
      });
    } catch (e, st) {
      debugPrint('Homie init failed: $e\n$st');
      if (!mounted) return;
      setState(() => _initError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Color(0xFF2563EB)),
                  const SizedBox(height: 16),
                  const Text('Chyba pri štarte aplikácie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_initError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _app = null;
                      });
                      _initialize();
                    },
                    child: const Text('Skúsiť znova'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_app == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupLoadingScreen(),
      );
    }

    return _app!;
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF0F4FF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handyman, size: 64, color: Color(0xFF2563EB)),
            SizedBox(height: 28),
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text(
              'Načítavam Susedko…',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App ──────────────────────────────────────────────────────────────────────
class HomieApp extends StatefulWidget {
  const HomieApp({super.key});
  @override
  State<HomieApp> createState() => _HomieAppState();
}

class _HomieAppState extends State<HomieApp> {
  @override
  void initState() { super.initState(); _initFCM(); }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true);
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    messaging.onTokenRefresh.listen((newToken) async {
      _cachedFcmToken = null;
      _cachedFcmUid   = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await saveFcmToken(user.uid);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      final type = message.data['type'] as String? ?? '';
      String channelId   = 'bookings_channel';
      String channelName = 'Rezervácie';
      if (type == 'new_request') {
        channelId = 'requests_channel'; channelName = 'Požiadavky';
      } else if (type == 'chat_message') {
        channelId = 'chat_channel'; channelName = 'Správy';
      } else if (type == 'work_order') {
        channelId = 'work_orders_channel'; channelName = 'Objednávky práce';
      }
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.max, priority: Priority.high)),
        payload: _buildPayload(message.data));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) =>
        _handleNotificationTap(_buildPayload(message.data)));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(_buildPayload(initialMessage.data));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Homie',
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling),
        child: child!),
      routes: {
        // ── Customer ──────────────────────────────────────────────────────
        '/customer_craftsmen':    (_) => const CustomerCraftsmenScreen(),
        '/customer_profile':      (_) => const CustomerProfileScreen(),
        '/customer_work_orders':  (_) => const CustomerWorkOrdersScreen(),
        '/customer_requests':     (_) => const CustomerRequestsScreen(),

        // ── Craftsman ─────────────────────────────────────────────────────
        '/craftsman_work_orders': (_) => const CraftsmanWorkOrdersScreen(),
        '/craftsman_requests':  (_) => const CraftsmanRequestsScreen(),
        '/craftsman_calendar':  (_) => const CraftsmanCalendarScreen(),
        '/craftsman_portfolio': (_) => const CraftsmanPortfolioScreen(),
        '/craftsman_profile':   (_) => const CraftsmanProfileScreen(),

        // ── Admin ─────────────────────────────────────────────────────────
        '/admin_home':      (_) => AdminHomeScreen(),
        '/admin_users':     (_) => AdminUsersScreen(),
        '/admin_craftsmen': (_) => const AdminCraftsmenScreen(),
        '/admin_reviews':   (_) => AdminReviewsScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _authTimedOut = false;
  Key _authStreamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) setState(() => _authTimedOut = true);
    });
  }

  void _retryAuth() {
    setState(() {
      _authTimedOut = false;
      _authStreamKey = UniqueKey();
    });
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) setState(() => _authTimedOut = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      key: _authStreamKey,
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _AuthLoadingScreen(
            message: _authTimedOut
                ? 'Firebase Auth neodpovedá.\nSkontroluj internet a reštartuj app (R).'
                : 'Overujem prihlásenie…',
            showRetry: _authTimedOut,
            onRetry: _retryAuth,
          );
        }
        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen(
                  message: 'Načítavam profil…');
            }
            if (!snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return RoleSelectionScreen(uid: user.uid);
            }
            final data =
                snapshot.data!.data()! as Map<String, dynamic>;
            final role =
                (data['role'] as String?)?.trim().toLowerCase() ?? '';
            if (role.isEmpty) return RoleSelectionScreen(uid: user.uid);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              saveFcmToken(user.uid);
              if (role == 'customer') {
                context.read<GeoProvider>().init();
                context.read<ChatProvider>().init();
                context.read<WishlistProvider>().listenToWishlist();
              } else if (role == 'craftsman') {
                context.read<ChatProvider>().init();
              }
            });

            switch (role) {
              case 'customer':  return const CustomerHomeScreen();
              case 'craftsman': return const CraftsmanHome();
              case 'admin':     return AdminHomeScreen();
              default: return RoleSelectionScreen(uid: user.uid);
            }
          });
      });
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen({
    this.message = 'Načítavam…',
    this.showRetry = false,
    this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                ),
              ),
              if (showRetry && onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Skúsiť znova'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
