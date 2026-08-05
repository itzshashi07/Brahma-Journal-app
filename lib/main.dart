import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/blogs/blogs_screen.dart';
import 'screens/blogs/create_blog_screen.dart';
import 'screens/blogs/blog_detail_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/products/create_product_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

        // Protect routes
        final protectedRoutes = ['/dashboard', '/journal', '/meditation', '/affirmations', '/thoughts', '/community', '/analytics', '/profile', '/support'];
        final isProtected = protectedRoutes.any((r) => loc.startsWith(r));
        if (isProtected && !isAuth) return '/welcome';
        if ((loc == '/welcome' || loc == '/login' || loc == '/signup') && isAuth) return '/dashboard';

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (ctx, _) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (ctx, _) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
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
        GoRoute(path: '/onboarding', builder: (ctx, _) => const OnboardingScreen()),
        GoRoute(path: '/blogs', builder: (ctx, _) => const BlogsScreen()),
        GoRoute(path: '/blogs/create', builder: (ctx, _) => const CreateBlogScreen()),
        GoRoute(
          path: '/blogs/:id',
          builder: (ctx, state) => BlogDetailScreen(blogId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/products', builder: (ctx, _) => const ProductsScreen()),
        GoRoute(path: '/products/create', builder: (ctx, _) => const CreateProductScreen()),
      ],
    );
  }
}
