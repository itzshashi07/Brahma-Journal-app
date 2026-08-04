import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../core/constants/app_constants.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveProfile(UserProfile profile) async {
    try {
      await _db.collection(AppConstants.profilesCollection).doc(profile.uid).set({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _db.collection(AppConstants.profilesCollection).doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(uid, doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ getProfile error: $e');
      return null;
    }
  }

  Future<List<UserProfile>> getAllProfiles() async {
    try {
      final snapshot = await _db.collection(AppConstants.profilesCollection).get();
      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('❌ getAllProfiles error: $e');
      return [];
    }
  }
}
