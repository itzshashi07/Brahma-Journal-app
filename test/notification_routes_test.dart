import 'package:flutter_test/flutter_test.dart';

import 'package:brahma_app/core/utils/notification_routes.dart';

/// The table a notification tap goes through before anything is pushed.
///
/// Worth a test because the failure it prevents is invisible in review: a route
/// written for the website reaches GoRouter, which has no such path, and the
/// member taps a notification and lands on an error screen.
void main() {
  group('appRouteFor', () {
    test('an article notification opens that article', () {
      expect(appRouteFor('/blogs/6a7bce8e68ce8f72f29b97a4'),
          '/blogs/6a7bce8e68ce8f72f29b97a4');
    });

    test('a route this app does not have opens nothing', () {
      expect(appRouteFor('/admin'), isNull);
      expect(appRouteFor('/app/dashboard'), isNull);
    });

    test('empty, null and non-paths open nothing', () {
      expect(appRouteFor(null), isNull);
      expect(appRouteFor(''), isNull);
      expect(appRouteFor('   '), isNull);
      expect(appRouteFor('https://innenflow.com/app'), isNull);
    });

    test('an operator alert goes to the operator screen, not the member one',
        () {
      expect(appRouteFor('/support', isAdminAlert: true), '/support-inbox');
      expect(appRouteFor('/counselling', isAdminAlert: true),
          '/counselling/inbox');
      expect(appRouteFor('/admin/reports', isAdminAlert: true), '/reports');
    });

    test('the same paths on a member notification stay the member\'s', () {
      expect(appRouteFor('/support'), '/support');
      expect(appRouteFor('/counselling'), '/counselling');
    });

    test('a known section with anything under it is allowed through', () {
      expect(appRouteFor('/games/leaderboard'), '/games/leaderboard');
      expect(appRouteFor('/meditation/theme/calm'), '/meditation/theme/calm');
    });

    test('a prefix that only looks like a known one is refused', () {
      expect(appRouteFor('/blogsomething'), isNull);
      expect(appRouteFor('/profile-settings'), isNull);
    });
  });
}
