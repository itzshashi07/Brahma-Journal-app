import 'modern_avatars.dart';

/// Six fixed portraits. Existing wire IDs render in older clients too.
class ProfilePictures {
  static final List<ModernAvatar> all =
      List.unmodifiable(ModernAvatar.presets.take(6));

  static bool contains(String id) => all.any((picture) => picture.id == id);
  static String get defaultId => all.first.id;
}
