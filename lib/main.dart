import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/journal_provider.dart';
import 'models/journal_entry.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/journal/journal_screen.dart';
import 'screens/meditation/meditation_screen.dart';
import 'screens/meditation/meditation_categories_screen.dart';
import 'screens/meditation/meditation_library_screen.dart';
import 'screens/meditation/meditation_quiz_screen.dart';
import 'screens/meditation/mind_games_screen.dart';
import 'screens/meditation/technique_player_screen.dart';
import 'screens/games/game_leaderboard_screen.dart';
import 'screens/games/game_zone_screen.dart';
import 'screens/gita/gita_screen.dart';
import 'screens/affirmations/affirmations_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/anonymous_thoughts/anonymous_thoughts_screen.dart';
import 'screens/activities/deep_work_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/support/support_screen.dart';
import 'screens/support/support_inbox_screen.dart';
import 'screens/support/moderation_inbox_screen.dart';
import 'screens/settings/delete_account_screen.dart';
import 'screens/counselling/counselling_screen.dart';
import 'screens/counselling/counselling_inbox_screen.dart';
import 'screens/legal/legal_screen.dart';
import 'screens/settings/app_updates_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/blogs/blogs_screen.dart';
import 'screens/blogs/create_blog_screen.dart';
import 'screens/blogs/blog_detail_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/products/create_product_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/create_announcement_screen.dart';
import 'services/notification_service.dart';
import 'services/notification_center.dart';
import 'services/firebase_messaging_service.dart';
import 'services/api_service.dart';


/// Startup.
///
/// **Nothing optional is awaited before runApp().** The previous version
/// awaited App Check activation and notification setup here, each wrapped in a
/// try/catch — which guards against a *throw* and does nothing at all against a
/// *hang*. Both of them can hang: App Check retries against the network, and
/// `requestNotificationsPermission()` waits on a system dialog that may never
/// be answered. When either did, main() never reached runApp() and the app
/// opened to a black screen with no error in the log — the hardest possible
/// failure to diagnose, because a hung app looks exactly like a crashed one
/// except that nothing is printed.
///
/// So: Firebase (which the providers genuinely need) is awaited with a bound,
/// the first frame is drawn, and everything else happens behind it.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('▶ boot: binding ready');

  // Auth and Firestore are unusable until this resolves, so it is the one thing
  // worth waiting for — but bounded, because "slow" must not become "never".
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 15));
    debugPrint('▶ boot: firebase ready');
  } catch (e) {
    // The app still starts. Screens that need Firebase show their own error
    // states, which is far better than a black rectangle.
    debugPrint('⚠️ Firebase init failed, starting anyway: $e');
  }

  // Registered before runApp and never awaited beyond this call. It hands the
  // engine a top-level entry point to spawn in a background isolate when a
  // push arrives with the app closed — registering it later, or from inside
  // _initBackgroundServices, risks a message landing before the handler exists
  // and being dropped without trace.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const InnenFlowApp());
  debugPrint('▶ boot: first frame scheduled');

  unawaited(_initBackgroundServices());
}

/// Hardening and convenience, none of which the first frame depends on.
Future<void> _initBackgroundServices() async {
  // Kick the API awake first and do not wait on it. The free-tier instance
  // suspends after a spell of inactivity, and a cold start takes the better
  // part of a minute — far better spent now, behind the dashboard, than when
  // the user opens a screen and watches a spinner.
  unawaited(ApiService().warmUp());

  // App Check attests that requests reach Firebase from a genuine, unmodified
  // build of this app. The Firebase config in firebase_options.dart is public
  // by design — it identifies the project, it does not protect it — so without
  // App Check anyone can extract it and drive Firestore, Auth and the callable
  // functions straight from a script. Security rules still do the authorisation;
  // this raises the cost of even reaching them.
  //
  // Debug builds use the debug provider: register the token it prints in
  // Firebase Console → App Check → Manage debug tokens.
  try {
    await FirebaseAppCheck.instance
        .activate(
          androidProvider:
              kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
          appleProvider:
              kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
        )
        .timeout(const Duration(seconds: 20));
    debugPrint('▶ boot: app check active');
  } catch (e) {
    debugPrint('⚠️ App Check unavailable, continuing without attestation: $e');
  }

  // Includes the Android 13+ notification permission prompt, which waits on the
  // user. That is exactly the kind of wait that must happen behind a rendered
  // screen rather than in front of one.
  try {
    await NotificationService().init().timeout(const Duration(seconds: 30));
    debugPrint('▶ boot: notifications ready');
  } catch (e) {
    debugPrint('⚠️ Notification setup failed: $e');
  }

  // Push. Runs after NotificationService because every FCM message is rendered
  // through it — the plugin has to be initialised before a message can arrive
  // and ask it to draw something.
  //
  // Bounded like everything else here: requestPermission() waits on a system
  // dialog the user may simply walk away from, and on iOS getToken() can block
  // until APNs answers.
  try {
    await FirebaseMessagingService().init().timeout(const Duration(seconds: 30));
    debugPrint('▶ boot: push ready');
  } catch (e) {
    debugPrint('⚠️ Push setup failed: $e');
  }
}

class InnenFlowApp extends StatelessWidget {
  const InnenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        // Watches the broadcast feed, the operator alerts and the member's own
        // counselling threads, so a request or a reply raises a real
        // notification instead of only being discoverable by opening a screen.
        ChangeNotifierProvider(create: (_) => NotificationCenter()),
      ],
      child: Builder(
        builder: (childContext) {
          return MaterialApp.router(
            title: 'InnenFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: _buildRouter(childContext),
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: context.read<AuthProvider>(),
      redirect: (ctx, state) {
        final auth = ctx.read<AuthProvider>();
        final isAuth = auth.isAuthenticated;
        final isLoading = auth.loading;
        final loc = state.matchedLocation;

        if (isLoading) return '/';

        // Every route that shows user data requires a session. /blogs,
        // /products and /notifications were missing from this list, so their
        // screens — including the admin-only create screens beneath them —
        // could be reached by deep link without signing in at all.
        const protectedRoutes = [
          '/dashboard', '/journal', '/meditation', '/affirmations', '/thoughts',
          '/community', '/analytics', '/deep-work', '/profile', '/support', '/blogs',
          '/products', '/notifications', '/announcements', '/how-to-use',
          '/app-updates', '/support-inbox', '/gita', '/games', '/counselling',
          '/reports', '/delete-account',
        ];
        final isProtected = protectedRoutes.any((r) => loc.startsWith(r));
        if (isProtected && !isAuth) return '/welcome';

        // Admin-only surfaces. The screens themselves also check isAdmin and
        // Firestore rules reject the writes regardless — this is the first of
        // the three, not the only one.
        // NOT '/blogs/create'. Writing an article is open to every member —
        // firestore.rules stamps the author from the session and only lets them
        // edit or delete their own post. Listing it here was the whole bug:
        // the Sanctuary showed a "Write" button to everyone and this redirect
        // bounced them straight back to the dashboard when they pressed it.
        const adminRoutes = [
          '/products/create', '/announcements/create', '/support-inbox',
          '/counselling/inbox', '/reports',
        ];
        if (adminRoutes.any((r) => loc.startsWith(r)) && !auth.isAdmin) {
          return '/dashboard';
        }

        // The counselling room belongs to the member. An admin opening it
        // landed on the intake form — which asked the counsellor for their own
        // name, age, phone and reason for seeking help, then offered to charge
        // them ₹299 to talk to themselves. Their way in is the inbox, where
        // every request and every live chat already is.
        if (loc == '/counselling' && auth.isAdmin) return '/counselling/inbox';

        if ((loc == '/welcome' || loc == '/login' || loc == '/signup') && isAuth) return '/dashboard';

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (ctx, _) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (ctx, _) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
        GoRoute(path: '/forgot-password', builder: (ctx, _) => const ForgotPasswordScreen()),
        GoRoute(path: '/phone-login', builder: (ctx, _) => const PhoneLoginScreen()),
        GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardScreen()),
        GoRoute(
          path: '/journal',
          builder: (ctx, state) {
            final entry = state.extra as JournalEntry?;
            return JournalScreen(entry: entry);
          },
        ),
        GoRoute(path: '/meditation', builder: (ctx, _) => const MeditationCategoriesScreen()),
        GoRoute(
          path: '/meditation/session',
          builder: (ctx, state) => MeditationScreen(
            initialMinutes: int.tryParse(state.uri.queryParameters['minutes'] ?? ''),
          ),
        ),
        GoRoute(
          path: '/meditation/quiz',
          builder: (ctx, _) => const MeditationQuizScreen(),
        ),
        GoRoute(
          path: '/meditation/all',
          builder: (ctx, _) => const MeditationLibraryScreen(),
        ),
        GoRoute(
          path: '/meditation/games',
          builder: (ctx, _) => const MindGamesScreen(),
        ),
        GoRoute(
          path: '/meditation/technique/:id',
          builder: (ctx, state) =>
              TechniquePlayerScreen(techniqueId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/meditation/theme/:id',
          builder: (ctx, state) =>
              MeditationThemeScreen(categoryId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/games', builder: (ctx, _) => const GameZoneScreen()),
        GoRoute(
          path: '/games/leaderboard',
          builder: (ctx, state) => GameLeaderboardScreen(
            initialGameId: state.uri.queryParameters['game'],
          ),
        ),
        GoRoute(path: '/gita', builder: (ctx, _) => const GitaScreen()),
        GoRoute(path: '/affirmations', builder: (ctx, _) => const AffirmationsScreen()),
        GoRoute(path: '/thoughts', builder: (ctx, _) => const AnonymousThoughtsScreen()),
        GoRoute(path: '/community', builder: (ctx, _) => const CommunityScreen()),
        GoRoute(path: '/analytics', builder: (ctx, _) => const AnalyticsScreen()),
        GoRoute(path: '/deep-work', builder: (ctx, _) => const DeepWorkScreen()),
        GoRoute(path: '/profile', builder: (ctx, _) => const ProfileScreen()),
        GoRoute(path: '/support', builder: (ctx, _) => const SupportScreen()),
        GoRoute(path: '/support-inbox', builder: (ctx, _) => const SupportInboxScreen()),
        // The moderation queue. Admin-only above, and firestore.rules refuses
        // the reads regardless of what this redirect allows.
        GoRoute(path: '/reports', builder: (ctx, _) => const ModerationInboxScreen()),
        // Deliberately NOT admin-gated: this is the member's own exit.
        GoRoute(path: '/delete-account', builder: (ctx, _) => const DeleteAccountScreen()),
        // The counselling room. '/counselling/inbox' is declared before the
        // bare path only for readability — go_router matches on the full
        // pattern, not on declaration order.
        GoRoute(
          path: '/counselling/inbox',
          builder: (ctx, _) => const CounsellingInboxScreen(),
        ),
        GoRoute(path: '/counselling', builder: (ctx, _) => const CounsellingScreen()),
        // Readable without signing in: someone deciding whether to create an
        // account needs to be able to read what happens to their data first,
        // and a store review reaches them from a link, not from inside a
        // session.
        GoRoute(
          path: '/legal/privacy',
          builder: (ctx, _) => const LegalScreen(doc: LegalDoc.privacy),
        ),
        GoRoute(
          path: '/legal/terms',
          builder: (ctx, _) => const LegalScreen(doc: LegalDoc.terms),
        ),
        GoRoute(path: '/app-updates', builder: (ctx, _) => const AppUpdatesScreen()),
        GoRoute(path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),
        // Same walkthrough, reachable any time from Support.
        GoRoute(path: '/how-to-use', builder: (ctx, _) => const OnboardingScreen()),
        GoRoute(path: '/blogs', builder: (ctx, _) => const BlogsScreen()),
        GoRoute(path: '/blogs/create', builder: (ctx, _) => const CreateBlogScreen()),
        GoRoute(
          path: '/blogs/:id',
          builder: (ctx, state) => BlogDetailScreen(blogId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/products', builder: (ctx, _) => const ProductsScreen()),
        GoRoute(path: '/products/create', builder: (ctx, _) => const CreateProductScreen()),
        GoRoute(path: '/notifications', builder: (ctx, _) => const NotificationsScreen()),
        GoRoute(path: '/announcements/create', builder: (ctx, _) => const CreateAnnouncementScreen()),
      ],
    );
  }
}
