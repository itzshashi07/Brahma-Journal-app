import 'package:flutter_test/flutter_test.dart';
import 'package:brahma_app/core/constants/counselling.dart';
import 'package:brahma_app/core/utils/route_access.dart';

void main() {
  String? redirect(String path,
          {bool signedIn = false,
          bool admin = false,
          bool initializing = false}) =>
      routeAccessRedirect(
          location: path,
          authenticated: signedIn,
          admin: admin,
          initializing: initializing);

  for (final path in [
    '/products/create',
    '/announcements/create',
    '/support-inbox',
    if (Counselling.enabled) '/counselling/inbox',
    '/reports',
    '/admin/accounts',
    '/reports/item'
  ]) {
    test('local role access: $path', () {
      expect(redirect(path), '/welcome');
      expect(redirect(path, signedIn: true), '/dashboard');
      expect(redirect(path, signedIn: true, admin: true), isNull);
    });
  }
  test('admin counselling opens inbox; member retains intake', () {
    expect(redirect('/counselling', signedIn: true, admin: true),
        '/counselling/inbox');
    expect(redirect('/counselling', signedIn: true), isNull);
  }, skip: !Counselling.enabled);
  test('counselling switched off: every way in lands on the dashboard', () {
    for (final path in ['/counselling', '/counselling/inbox']) {
      expect(redirect(path), '/welcome');
      expect(redirect(path, signedIn: true), '/dashboard');
      expect(redirect(path, signedIn: true, admin: true), '/dashboard');
    }
  }, skip: Counselling.enabled);
  test('member can write an article', () {
    expect(redirect('/blogs/create', signedIn: true), isNull);
    expect(redirect('/blogs/create'), '/welcome');
  });
  test('restoration blocks private routes without looping on splash', () {
    expect(redirect('/journal', initializing: true), '/');
    expect(redirect('/', initializing: true), isNull);
  });
  test('signed-out login and recovery stay available', () {
    expect(redirect('/login'), isNull);
    expect(redirect('/forgot-password'), isNull);
    expect(redirect('/login', signedIn: true), '/dashboard');
  });
}
