import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'screens/affirmations/affirmations_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/anonymous_thoughts/anonymous_thoughts_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/support/support_screen.dart';
import 'screens/support/support_inbox_screen.dart';
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


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check attests that requests reach Firebase from a genuine, unmodified
  // build of this app. The Firebase config in firebase_options.dart is public
  // by design — it identifies the project, it does not protect it — so without
  // App Check anyone can extract it and drive Firestore, Auth and the callable
  // functions straight from a script. Security rules still do the authorisation;
  // this raises the cost of even reaching them.
  //
  // Debug builds use the debug provider: register the token it prints in
  // Firebase Console → App Check → Manage debug tokens.
  //
  // Never allowed to be fatal. Play Integrity throws on a device or build it
  // cannot attest — no Play Services, a sideloaded APK, or (as here) an app not
  // yet registered for App Check — and an uncaught throw at this point aborts
  // main() before runApp(), so the app opens to a black screen and never starts.
  // Attestation is a hardening layer; Firestore rules are what actually
  // authorise anything, and they are unaffected by this failing.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('⚠️ App Check unavailable, continuing without attestation: $e');
  }

  // Same reasoning: notification setup must not be able to keep the app from
  // starting either.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Notification setup failed: $e');
  }

  runApp(const BrahmaApp());
}

class BrahmaApp extends StatelessWidget {
  const BrahmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
      ],
      child: Builder(
        builder: (childContext) {
          return MaterialApp.router(
            title: 'Brahma Journal',
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
          '/community', '/analytics', '/profile', '/support', '/blogs',
          '/products', '/notifications', '/announcements', '/how-to-use',
          '/app-updates', '/support-inbox',
        ];
        final isProtected = protectedRoutes.any((r) => loc.startsWith(r));
        if (isProtected && !isAuth) return '/welcome';

        // Admin-only surfaces. The screens themselves also check isAdmin and
        // Firestore rules reject the writes regardless — this is the first of
        // the three, not the only one.
        const adminRoutes = ['/blogs/create', '/products/create', '/announcements/create', '/support-inbox'];
        if (adminRoutes.any((r) => loc.startsWith(r)) && !auth.isAdmin) {
          return '/dashboard';
        }

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
        GoRoute(path: '/meditation', builder: (ctx, _) => const MeditationScreen()),
        GoRoute(path: '/affirmations', builder: (ctx, _) => const AffirmationsScreen()),
        GoRoute(path: '/thoughts', builder: (ctx, _) => const AnonymousThoughtsScreen()),
        GoRoute(path: '/community', builder: (ctx, _) => const CommunityScreen()),
        GoRoute(path: '/analytics', builder: (ctx, _) => const AnalyticsScreen()),
        GoRoute(path: '/profile', builder: (ctx, _) => const ProfileScreen()),
        GoRoute(path: '/support', builder: (ctx, _) => const SupportScreen()),
        GoRoute(path: '/support-inbox', builder: (ctx, _) => const SupportInboxScreen()),
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
