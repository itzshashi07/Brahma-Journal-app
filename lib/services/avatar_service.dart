import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/spiritual_avatars.dart';

/// Profile avatar selection.
///
/// Photo upload has been removed. Members now choose from a curated set of
/// spiritual avatars, and only the avatar's `id` is stored — a short string,
/// no file, no URL, no Cloud Storage bucket.
///
/// That removes a whole class of problems rather than fixing them: nothing to
/// moderate, no image of a real person published to every other member on the
/// leaderboard, no upload to rate-limit, no storage bill, and no dependency on
/// a Storage bucket that this project does not have.
///
/// The 30-day change limit went with it. That limit existed because uploads
/// cost storage and invited abuse; picking one of eight presets costs nothing,
/// so making members wait a month to change their mind would be friction with
/// no purpose behind it.
class AvatarService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stores the chosen avatar on the profile and mirrors it onto the public
  /// leaderboard row.
  Future<void> selectAvatar({
    required String uid,
    required String avatarId,
  }) async {
    // Reject anything not in the catalogue, so a stale build or a tampered
    // client cannot write an id the app will later fail to render.
    if (SpiritualAvatars.byId(avatarId) == null) {
      throw ArgumentError('Unknown avatar: $avatarId');
    }

    await _db.collection(AppConstants.profilesCollection).doc(uid).set({
      'avatarId': avatarId,
      'avatarUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Best-effort: the avatar is already saved above, and a leaderboard write
    // that fails should never surface as "could not change your avatar".
    try {
      await _db.collection(AppConstants.leaderboardCollection).doc(uid).set({
        'avatarId': avatarId,
      }, SetOptions(merge: true));
    } catch (_) {
      // The next stats sync rewrites the row.
    }
  }

  /// Applies the default avatar for a gender, but never overwrites a choice the
  /// member has already made.
  Future<void> applyGenderDefaultIfUnset({
    required String uid,
    required String? gender,
    required String? currentAvatarId,
  }) async {
    if (currentAvatarId != null && currentAvatarId.isNotEmpty) return;
    await selectAvatar(
      uid: uid,
      avatarId: SpiritualAvatars.defaultFor(gender).id,
    );
  }
}
