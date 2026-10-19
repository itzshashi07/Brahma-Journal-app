import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brahma_app/models/user_profile.dart';
import 'package:brahma_app/core/constants/app_constants.dart';
import 'package:brahma_app/providers/auth_provider.dart' as app;
import 'package:brahma_app/services/auth_service.dart';
import 'package:brahma_app/services/profile_service.dart';

class TestAuth extends Fake implements AuthService {
  final events = StreamController<User?>.broadcast();
  @override
  Future<UserCredential> signIn(String email, String password) async {
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Stream<User?> get authStateChanges => events.stream;
}

class TestProfile extends Fake implements ProfileService {
  final loads = <String, Completer<UserProfile?>>{};
  @override
  Future<UserProfile?> getProfile([String? uid]) =>
      (loads[uid!] ??= Completer<UserProfile?>()).future;
}

class TestToken extends Fake implements IdTokenResult {
  TestToken(this.admin);
  final bool admin;
  @override
  Map<String, dynamic> get claims => {'admin': admin};
}

class TestUser extends Fake implements User {
  TestUser(this.uid,
      {this.admin = false,
      this.pending,
      this.address,
      this.emailVerified = false});
  @override
  final String uid;
  final bool admin;
  final String? address;
  @override
  final bool emailVerified;
  final Completer<IdTokenResult>? pending;
  @override
  String? get email => address ?? '$uid@example.invalid';
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      pending == null ? TestToken(admin) : await pending!.future;
}

void main() {
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test('failed sign-in does not restart session initialization', () async {
    final auth = TestAuth();
    final provider =
        app.AuthProvider(authService: auth, profileService: TestProfile());
    auth.events.add(null);
    await flush();
    expect(provider.initializing, isFalse);
    expect(await provider.signIn('member@example.invalid', 'wrong'), isFalse);
    expect(provider.loading, isFalse);
    expect(provider.initializing, isFalse);
    expect(provider.error, isNotEmpty);
    provider.dispose();
    await auth.events.close();
  });
  test('local admin claim is removed immediately on sign-out', () async {
    final auth = TestAuth();
    final provider =
        app.AuthProvider(authService: auth, profileService: TestProfile());
    auth.events.add(TestUser('operator', admin: true));
    await flush();
    expect(provider.isAdmin, isTrue);
    auth.events.add(null);
    await flush();
    expect(provider.isAdmin, isFalse);
    expect(provider.isAuthenticated, isFalse);
    provider.dispose();
    await auth.events.close();
  });
  test('configured admin email requires verification, matching the API',
      () async {
    final auth = TestAuth();
    final provider =
        app.AuthProvider(authService: auth, profileService: TestProfile());
    auth.events.add(TestUser('unverified', address: AppConstants.adminEmail));
    await flush();
    expect(provider.isAdmin, isFalse);
    auth.events.add(TestUser('verified',
        address: AppConstants.adminEmail, emailVerified: true));
    await flush();
    expect(provider.isAdmin, isTrue);
    provider.dispose();
    await auth.events.close();
  });
  test('late admin token cannot grant admin UI to the next member', () async {
    final auth = TestAuth();
    final profiles = TestProfile();
    final provider =
        app.AuthProvider(authService: auth, profileService: profiles);
    final old = Completer<IdTokenResult>();
    auth.events.add(TestUser('operator', pending: old));
    await flush();
    auth.events.add(TestUser('member'));
    await flush();
    old.complete(TestToken(true));
    await flush();
    expect(provider.user?.uid, 'member');
    expect(provider.isAdmin, isFalse);
    provider.dispose();
    await auth.events.close();
  });
  test('late profile cannot appear in a different account', () async {
    final auth = TestAuth();
    final profiles = TestProfile();
    final provider =
        app.AuthProvider(authService: auth, profileService: profiles);
    auth.events.add(TestUser('first'));
    await flush();
    auth.events.add(TestUser('second'));
    await flush();
    profiles.loads['second']!
        .complete(UserProfile(uid: 'second', name: 'Second'));
    await flush();
    profiles.loads['first']!.complete(UserProfile(uid: 'first', name: 'First'));
    await flush();
    expect(provider.profile?.uid, 'second');
    provider.dispose();
    await auth.events.close();
  });
}
