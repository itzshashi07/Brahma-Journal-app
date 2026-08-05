import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _profile?.email == 'officialshashi2023@gmail.com' || _user?.email == 'officialshashi2023@gmail.com';

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await _loadProfile(user.uid);
      } else {
        _profile = null;
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> _loadProfile(String uid) async {
    _profile = await _profileService.getProfile(uid);
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      if (email.trim() == 'officialshashi2023@gmail.com' && password == 'Admin@2026') {
        try {
          await _authService.signIn(email, password);
        } catch (e) {
          // If login fails (e.g. user does not exist in Firebase), create user & profile as Admin
          try {
            final credential = await _authService.signUp(email, password);
            final uid = credential.user!.uid;
            final newProfile = UserProfile(
              uid: uid,
              name: 'Admin',
              email: email.trim(),
              age: 30,
              gender: 'Other',
              phone: '9999999999',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _profileService.saveProfile(newProfile);
            await FirebaseFirestore.instance.collection(AppConstants.profilesCollection).doc(uid).update({
              'premium': true,
              'role': 'admin',
            });
          } on FirebaseAuthException catch (ae) {
            if (ae.code == 'email-already-in-use') {
              _error = 'Admin email is already registered in Firebase with a different password. Please log in using your original password, or reset it to Admin@2026 in the Firebase Console.';
            } else {
              _error = _mapAuthError(ae.code);
            }
            _loading = false;
            notifyListeners();
            return false;
          } catch (ae) {
            _error = 'Failed to auto-register Admin: $ae';
            _loading = false;
            notifyListeners();
            return false;
          }
        }
        _loading = false;
        notifyListeners();
        return true;
      }

      await _authService.signIn(email, password);
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

      // 3. Mark as paid & active subscription
      await FirebaseFirestore.instance.collection(AppConstants.profilesCollection).doc(uid).update({
        'premium': true,
        'paymentId': paymentId,
        'subscriptionId': subscriptionId,
        'planSelected': planSelected,
        'paymentDate': FieldValue.serverTimestamp(),
      });

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

  Future<void> signOut() async {
    await _authService.signOut();
    _profile = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_user != null) {
      await _loadProfile(_user!.uid);
      notifyListeners();
    }
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
