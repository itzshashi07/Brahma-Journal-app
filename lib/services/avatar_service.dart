import '../core/constants/spiritual_avatars.dart';
import 'api_service.dart';

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
///
/// The leaderboard mirror is gone too, and needs no replacement: the API
/// updates the public row inside the same request that writes the profile, so
/// the two cannot disagree and there is no best-effort second write to fail.
class AvatarService {
  final ApiService _api = ApiService();

  /// Stores the chosen avatar on the profile.
  ///
  /// The [uid] parameter is kept so existing call sites compile unchanged and
  /// is deliberately unused — the server writes the profile belonging to the
  /// ID token, so nobody can set somebody else's avatar.
  Future<void> selectAvatar({
    String? uid,
    required String avatarId,
  }) async {
    // Rejected here as well as on the server, so a stale build fails with a
    // message that names the problem rather than a 400 from the API.
    if (SpiritualAvatars.byId(avatarId) == null) {
      throw ArgumentError('Unknown avatar: $avatarId');
    }

    await _api.patch('/api/profile/me', {'avatarId': avatarId});
  }

  /// Applies the default avatar for a gender, but never overwrites a choice the
  /// member has already made.
  Future<void> applyGenderDefaultIfUnset({
    String? uid,
    required String? gender,
    required String? currentAvatarId,
  }) async {
    if (currentAvatarId != null && currentAvatarId.isNotEmpty) return;
    await selectAvatar(avatarId: SpiritualAvatars.defaultFor(gender).id);
  }
}
