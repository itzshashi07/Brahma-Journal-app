import 'package:flutter/material.dart';

/// A built avatar, encoded as a short string on the profile.
///
/// The spiritual set (lotus, diya, point of light) is still there and still
/// loved by some members, but it is eight fixed pictures — several people end
/// up with the same one, and none of them look like a person. These are drawn
/// in code from a handful of choices, so there is no asset to ship, nothing to
/// upload or moderate, and a member can make something that is recognisably
/// theirs.
///
/// Stored as `m:bg,skin,hair,hairColor,face,accessory,clothes` — short enough
/// to sit in the existing `avatarId` string field, so no schema change and no
/// migration. Anything unparseable falls back to the defaults rather than
/// throwing, because an avatar is never worth an error screen.
class ModernAvatar {
  final int bg;
  final int skin;
  final int hair;
  final int hairColor;
  final int face;
  final int accessory;
  final int clothes;

  const ModernAvatar({
    this.bg = 0,
    this.skin = 1,
    this.hair = 1,
    this.hairColor = 0,
    this.face = 0,
    this.accessory = 0,
    this.clothes = 0,
  });

  static const prefix = 'm:';

  static bool isModern(String? id) => id != null && id.startsWith(prefix);

  String get id =>
      '$prefix$bg,$skin,$hair,$hairColor,$face,$accessory,$clothes';

  ModernAvatar copyWith({
    int? bg,
    int? skin,
    int? hair,
    int? hairColor,
    int? face,
    int? accessory,
    int? clothes,
  }) =>
      ModernAvatar(
        bg: bg ?? this.bg,
        skin: skin ?? this.skin,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        face: face ?? this.face,
        accessory: accessory ?? this.accessory,
        clothes: clothes ?? this.clothes,
      );

  static ModernAvatar parse(String? id) {
    if (!isModern(id)) return const ModernAvatar();
    final parts = id!.substring(prefix.length).split(',');
    int at(int i, int max) {
      if (i >= parts.length) return 0;
      final v = int.tryParse(parts[i]) ?? 0;
      return v < 0 || v >= max ? 0 : v;
    }

    return ModernAvatar(
      bg: at(0, backgrounds.length),
      skin: at(1, skinTones.length),
      hair: at(2, hairStyles.length),
      hairColor: at(3, hairColors.length),
      face: at(4, faces.length),
      accessory: at(5, accessories.length),
      clothes: at(6, clothesColors.length),
    );
  }

  // ─────────────────────────── option sets ───────────────────────────

  static const backgrounds = <List<Color>>[
    [Color(0xFF7C3AED), Color(0xFF4338CA)],
    [Color(0xFF0891B2), Color(0xFF0F172A)],
    [Color(0xFFF59E0B), Color(0xFFB45309)],
    [Color(0xFF10B981), Color(0xFF065F46)],
    [Color(0xFFEC4899), Color(0xFF831843)],
    [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    [Color(0xFF64748B), Color(0xFF1E293B)],
    [Color(0xFFF97316), Color(0xFF7C2D12)],
  ];

  static const skinTones = <Color>[
    Color(0xFFF6D5B8),
    Color(0xFFE8B990),
    Color(0xFFCC9A6E),
    Color(0xFFA9744C),
    Color(0xFF7A4E30),
    Color(0xFF4E3220),
  ];

  static const hairColors = <Color>[
    Color(0xFF1F1B18),
    Color(0xFF3B2A20),
    Color(0xFF6B4423),
    Color(0xFF9A6B3F),
    Color(0xFF8B8B8B),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
  ];

  static const clothesColors = <Color>[
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFF8FAFC),
    Color(0xFF1F2937),
  ];

  /// Labels are shown under the option rows, so they have to be short.
  static const hairStyles = <String>[
    'Buzz',
    'Short',
    'Side part',
    'Curly',
    'Bun',
    'Long',
    'Ponytail',
    'Wrap',
    'Scarf',
  ];

  static const faces = <String>[
    'Calm',
    'Happy',
    'Focused',
    'Meditating',
  ];

  static const accessories = <String>[
    'None',
    'Glasses',
    'Headphones',
    'Cap',
    'Earrings',
    'Bindi',
  ];

  /// A spread of ready-made looks for people who do not want to fiddle with
  /// seven rows of choices — most members will tap one of these and leave.
  static const presets = <ModernAvatar>[
    ModernAvatar(bg: 0, skin: 1, hair: 1, hairColor: 0, face: 0, accessory: 0, clothes: 0),
    ModernAvatar(bg: 1, skin: 2, hair: 5, hairColor: 1, face: 1, accessory: 4, clothes: 1),
    ModernAvatar(bg: 3, skin: 0, hair: 2, hairColor: 2, face: 2, accessory: 1, clothes: 2),
    ModernAvatar(bg: 2, skin: 3, hair: 4, hairColor: 0, face: 3, accessory: 5, clothes: 3),
    ModernAvatar(bg: 4, skin: 1, hair: 6, hairColor: 0, face: 1, accessory: 0, clothes: 4),
    ModernAvatar(bg: 5, skin: 4, hair: 3, hairColor: 1, face: 0, accessory: 2, clothes: 5),
    ModernAvatar(bg: 6, skin: 2, hair: 7, hairColor: 0, face: 3, accessory: 0, clothes: 6),
    ModernAvatar(bg: 7, skin: 5, hair: 8, hairColor: 0, face: 0, accessory: 5, clothes: 3),
    ModernAvatar(bg: 1, skin: 0, hair: 0, hairColor: 4, face: 2, accessory: 1, clothes: 6),
    ModernAvatar(bg: 3, skin: 3, hair: 5, hairColor: 5, face: 1, accessory: 2, clothes: 0),
    ModernAvatar(bg: 5, skin: 1, hair: 3, hairColor: 6, face: 1, accessory: 0, clothes: 1),
    ModernAvatar(bg: 0, skin: 4, hair: 4, hairColor: 0, face: 3, accessory: 0, clothes: 5),
  ];
}
