/// Where a notification actually goes when somebody taps it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Why a notification's `route` cannot be pushed as it stands
///
/// The route on a notification is written by the API, and the API serves two
/// clients. Some of what it writes is a *website* path: a support ticket alert
/// says `/support`, which in this app is the member's own contact form rather
/// than the operator's inbox, and a new signup says `/admin`, which is a page
/// this app does not have at all. Pushing either verbatim lands the operator
/// somewhere useless or on GoRouter's error screen — so every tap goes through
/// here first, and anything that has no answer in this app opens nothing.
///
/// The other half of the job is that admin alerts and member notifications
/// disagree about the same string: `/counselling` means "my counselling room"
/// to a member and "the queue" to an operator. The caller says which it is.
library;

/// Routes this app can actually open, longest-prefix first so `/counselling`
/// does not swallow `/counselling/inbox`.
const _known = <String>[
  '/dashboard',
  '/journal',
  '/meditation',
  '/affirmations',
  '/thoughts',
  '/community',
  '/analytics',
  '/deep-work',
  '/profile',
  '/support-inbox',
  '/support',
  '/blogs',
  '/products',
  '/notifications',
  '/announcements',
  '/gita',
  '/games',
  '/counselling/inbox',
  '/counselling',
  '/reports',
];

/// The screen in this app for a notification's route, or null when there is
/// nothing to open.
///
/// [isAdminAlert] is what separates the operator's reading of a path from the
/// member's — an alert about a support ticket belongs in the inbox, while the
/// same path on a member's notification is their own contact form.
String? appRouteFor(String? raw, {bool isAdminAlert = false}) {
  final route = (raw ?? '').trim();
  if (route.isEmpty || !route.startsWith('/')) return null;

  if (isAdminAlert) {
    switch (route) {
      case '/counselling':
      case '/counselling/inbox':
        return '/counselling/inbox';
      case '/support':
      case '/support-inbox':
        return '/support-inbox';
      case '/admin/reports':
      case '/reports':
        return '/reports';
      case '/blogs':
        // A submission waiting for review: the review strip is at the top of
        // the Sanctuary, so the article list is the right screen.
        return '/blogs';
    }
  }

  // A path with an id under a known section — `/blogs/<id>`, `/counselling` —
  // is fine as it stands. Anything else is the website's.
  final match = _known.firstWhere(
    (k) => route == k || route.startsWith('$k/'),
    orElse: () => '',
  );
  return match.isEmpty ? null : route;
}
