import '../constants/counselling.dart';

/// Client navigation guard. Server authorization still protects all data.
/// Only initial session restoration blocks routing; an in-progress login
/// must leave the form visible so failures can be corrected.
String? routeAccessRedirect({
  required String location,
  required bool initializing,
  required bool authenticated,
  required bool admin,
}) {
  if (initializing) return location == '/' ? null : '/';
  bool within(String route) =>
      location == route || location.startsWith('$route/');
  const protectedRoutes = [
    '/dashboard', '/small-wins', '/admin',
    '/journal',
    '/meditation',
    '/affirmations',
    '/thoughts',
    '/community',
    '/analytics',
    '/deep-work',
    '/profile',
    '/support',
    '/blogs',
    '/products',
    '/notifications',
    '/announcements',
    '/how-to-use',
    '/app-updates',
    '/support-inbox',
    '/gita',
    '/games',
    '/counselling',
    '/reports',
    '/delete-account',
  ];
  if (protectedRoutes.any(within) && !authenticated) return '/welcome';
  if (!Counselling.enabled && within('/counselling')) return '/dashboard';
  const adminRoutes = [
    '/admin',
    '/products/create',
    '/announcements/create',
    '/support-inbox',
    '/counselling/inbox',
    '/reports',
  ];
  if (adminRoutes.any(within) && !admin) return '/dashboard';
  if (location == '/counselling' && admin) return '/counselling/inbox';
  if (authenticated &&
      const ['/welcome', '/login', '/signup'].contains(location)) {
    return '/dashboard';
  }
  return null;
}
