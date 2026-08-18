import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';
import '../core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  User? _user;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;

  /// Raised when somebody signs in, cleared by whoever reads it. The dashboard
  /// uses it to decide whether to open the welcome celebration — which must
  /// appear after *signing in* and not on every cold start. See the listener in
  /// the constructor for how those two are told apart.
  bool _justSignedIn = false;

  /// True the first time this is read after a sign-in, false afterwards.
  bool consumeJustSignedIn() {
    if (!_justSignedIn) return false;
    _justSignedIn = false;
    return true;
  }

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  /// Whether this account holds the `admin` custom claim.
  ///
  /// Previously this compared the signed-in email against a hardcoded address,
  /// paired with a hardcoded password in [signIn] — a secret that shipped
  /// inside the APK, so anyone who unzipped it could sign in as the operator.
  /// The claim is minted by the `setAdminClaim` Cloud Function and signed by
  /// Firebase: it cannot be guessed, forged, or self-assigned, and the same
  /// claim is what firestore.rules checks server-side. This getter only drives
  /// which controls are visible — it is never the thing that grants access.
  bool get isAdmin => _isAdmin || _isConfiguredAdminEmail;

  /// Transitional fallback so admin controls are reachable before the first
  /// custom claim is minted — see [AppConstants.adminEmail]. Firestore rules
  /// carry the identical fallback, so this never grants the UI more than the
  /// server will actually honour.
  bool get _isConfiguredAdminEmail {
    final email = _user?.email?.toLowerCase().trim();
    return email != null && email == AppConstants.adminEmail.toLowerCase();
  }

  /// Whether any auth state has arrived yet.
  ///
  /// The first event is the SDK reporting what it restored from disk, not
  /// somebody signing in — telling those apart is the whole reason this exists.
  bool _sawInitialAuthState = false;

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      // The flag is raised HERE rather than in signIn/signUp, and that placement
      // is load-bearing. Firebase emits this event the instant the credential
      // resolves — before the awaits in signUp() finish — so the router
      // redirects and the dashboard reads the flag while those methods are
      // still running. Setting it from them lost the race and the celebration
      // never appeared.
      //
      // A sign-in is: not the first event we have seen, and we were signed out
      // before it. That excludes the session restored at cold start, which is
      // the one case that must stay silent.
      final wasSignedOut = _user == null;
      final isFirstEvent = !_sawInitialAuthState;
      _sawInitialAuthState = true;
      if (user != null && wasSignedOut && !isFirstEvent) _justSignedIn = true;

      _user = user;
      if (user != null) {
        // The claim first, because `isAdmin` decides which routes exist and the
        // router is about to run.
        await _refreshAdminClaim(user);

        // Routing is unblocked *here*, on identity, and not after the profile
        // has been fetched.
        //
        // ─────────────────────────────────────────────────────────────────
        // Why: the splash that would not end
        //
        // `loading` is what the router reads to decide whether it knows enough
        // to route — `if (isLoading) return '/'` sends every destination back
        // to the splash. It used to stay true until the profile request came
        // back, and that request goes to an API that sleeps on a free tier: a
        // cold start is the better part of a minute. So after signing in the
        // app sat on the splash, navigated, got bounced to '/', and did it
        // again, until the profile finally landed. Reproduced on the emulator
        // twice: signed in, then a splash that outlasted a fresh install.
        //
        // Who you are is known now. What your display name is can arrive a
        // moment later — every screen already renders without it (the greeting
        // falls back, the avatar draws its default), and none of them can be
        // reached without a session anyway.
        _loading = false;
        notifyListeners();

        unawaited(_loadProfile(user.uid));
      } else {
        _profile = null;
        _isAdmin = false;
        _loading = false;
        notifyListeners();
      }
    });
  }

  /// Reads the `admin` claim out of the signed Firebase ID token.
  Future<void> _refreshAdminClaim(User user, {bool forceRefresh = false}) async {
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      _isAdmin = token.claims?['admin'] == true;
    } catch (e) {
      // Fail closed: if the claim cannot be read, assume no privilege.
      _isAdmin = false;
    }
    notifyListeners();
  }

  /// Pulls a freshly minted claim without requiring a sign-out.
  Future<void> refreshAdminClaim() async {
    final user = _user;
    if (user != null) await _refreshAdminClaim(user, forceRefresh: true);
  }

  // The client-side "a new seeker joined" alert that used to live here is
  // gone.
  //
  // It wrote to `/admin_notifications` from the handset, with the document id
  // derived from the uid so a second attempt would be an *update* — which
  // firestore.rules refused for anyone but an admin. That was a clever way to
  // get "exactly once" out of a client that cannot read the collection, and it
  // depended on three things staying true at once: the rule, the id scheme,
  // and every sign-in path remembering to call it.
  //
  // The server raises it now, from `GET /api/profile/me`, which already knows
  // whether it just created the profile. That is the same question with a
  // direct answer, it fires for email, Google and phone without any of them
  // opting in, and it leaves the app with no Firestore write at all.

  /// Reads the profile once, on sign-in.
  ///
  /// This was a Firestore `snapshots()` subscription held open for the entire
  /// session. It existed because the profile is written from several places —
  /// the edit screen, `sync-stats`, the avatar picker — and the listener meant
  /// none of them had to remember to tell the provider.
  ///
  /// A live socket per signed-in device is a lot to pay for that, and it is not
  /// available over the API regardless. Every one of those writers goes through
  /// this provider or through [ProfileService], so [refreshProfile] after a
  /// write does the same job for the cost of one request — and the profile only
  /// changes when this device changes it, which is the case a listener was
  /// never needed for.
  Future<void> _loadProfile(String uid) async {
    try {
      _profile = await _profileService.getProfile(uid);
    } catch (e) {
      // Keep whatever was already loaded. A profile that fails to refresh is a
      // stale name; a profile blanked on a dropped request is a screen that
      // says the member has no account.
      debugPrint('⚠️ auth: profile unavailable: $e');
    }
    _loading = false;
    notifyListeners();
  }

  /// Signs in through Firebase Auth.
  ///
  /// There is deliberately no special case here. The previous version compared
  /// against a hardcoded operator email and password and, if that account did
  /// not exist, silently created it and granted itself `premium` and
  /// `role: admin`. Both the credential and the escalation path shipped inside
  /// the APK, so the operator account could be taken over by anyone who read
  /// the binary. Admin is now a server-minted claim; see [isAdmin].
  Future<bool> signIn(String email, String password) async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      await _authService.signIn(email, password);
      // Nothing to do with the credential here: the authStateChanges listener
      // in the constructor picks the sign-in up, refreshes the admin claim and
      // loads the profile. The operator alert that used to fire from this line
      // is raised server-side on profile creation now.
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to sign in. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
    required String phone,
    required String paymentId,
    String? subscriptionId,
    required String planSelected,
  }) async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      // 1. Create firebase auth user
      final credential = await _authService.signUp(email, password);
      final uid = credential.user!.uid;

      // 2. Create and save profile
      final newProfile = UserProfile(
        uid: uid,
        name: name,
        email: email,
        age: age,
        gender: gender,
        phone: phone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _profileService.saveProfile(newProfile);

      // 3. Entitlement is NOT granted here.
      //
      // This used to write `premium: true` straight from the client the moment
      // Razorpay's callback fired — and because a user may write their own
      // profile, anyone could set that field directly and skip payment
      // entirely. `premium`, `paymentId`, `subscriptionId`, `planSelected` and
      // `paymentDate` are now server-only fields (see firestore.rules); they
      // are written by the verifySubscriptionPayment Cloud Function, and only
      // after it has checked the Razorpay HMAC signature against the secret.

      _user = credential.user;
      _profile = newProfile;
      _loading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to register. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sends a password reset link.
  ///
  /// Always reports success, even for an address with no account. Firebase
  /// behaves the same way on purpose: a form that says "no such user" lets
  /// anyone test which email addresses are registered here, which is the first
  /// step of a credential-stuffing campaign.
  Future<bool> sendPasswordReset(String email) async {
    try {
      _error = null;
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        _error = 'That does not look like a valid email address.';
        notifyListeners();
        return false;
      }
      // user-not-found and friends are swallowed deliberately — see above.
      return true;
    } catch (e) {
      _error = 'Could not send the reset email. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Google sign-in. Returns false if the user dismissed the chooser.
  Future<bool> signInWithGoogle() async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        _loading = false;
        notifyListeners();
        return false;
      }

      await _ensureProfileExists(credential.user!);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.code == 'account-exists-with-different-credential'
          ? 'That email is already registered with a password. Sign in with your password instead.'
          : _mapAuthError(e.code);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Creates a profile document for accounts that arrive through a federated
  /// provider, which skip the email/password signup form entirely.
  ///
  /// Deliberately writes no entitlement fields — `premium` is server-only, so a
  /// Google account starts out exactly as unprivileged as any other.
  Future<void> _ensureProfileExists(User user) async {
    final existing = await _profileService.getProfile(user.uid);
    if (existing != null) return;

    await _profileService.saveProfile(UserProfile(
      uid: user.uid,
      name: user.displayName,
      email: user.email,
      phone: user.phoneNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _profile = null;
    notifyListeners();
  }

  /// Re-reads the profile.
  ///
  /// Call this after anything that writes one — the edit screen, the avatar
  /// picker, `sync-stats`. It is what replaces the listener that used to notice
  /// on its own.
  Future<void> refreshProfile() async {
    if (_user != null) await _loadProfile(_user!.uid);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Failed to sign in. Please try again.';
    }
  }

}
