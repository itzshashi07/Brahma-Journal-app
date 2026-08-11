import 'package:flutter/material.dart';

/// The avatar set members choose from.
///
/// Replaces photo upload entirely. That is a deliberate simplification, not a
/// downgrade:
///
///  * It needs no Cloud Storage bucket, so it works on the free plan.
///  * There is nothing to moderate — a curated set cannot carry an offensive
///    or identifying image.
///  * Nothing personal leaves the device, which matters on a screen where the
///    leaderboard shows every member's picture to every other member.
///  * Each one is vector art that stays sharp at any size and costs a few KB.
///
/// Only the avatar's `id` is stored on the profile. No URLs, no files.
class SpiritualAvatar {
  final String id;
  final String asset;
  final String label;
  final List<Color> gradient;

  /// 'male', 'female', or null for avatars offered to everyone.
  final String? affinity;

  const SpiritualAvatar({
    required this.id,
    required this.asset,
    required this.label,
    required this.gradient,
    this.affinity,
  });
}

class SpiritualAvatars {
  static const List<SpiritualAvatar> all = [
    SpiritualAvatar(
      id: 'soul',
      asset: 'assets/art/avatars/soul.svg',
      label: 'Point of Light',
      gradient: [Color(0xFF7C3AED), Color(0xFF4338CA)],
    ),
    SpiritualAvatar(
      id: 'meditator_m',
      asset: 'assets/art/avatars/meditator_m.svg',
      label: 'Seated in Peace',
      gradient: [Color(0xFF0891B2), Color(0xFF155E75)],
      affinity: 'male',
    ),
    SpiritualAvatar(
      id: 'meditator_f',
      asset: 'assets/art/avatars/meditator_f.svg',
      label: 'Seated in Peace',
      gradient: [Color(0xFFEC4899), Color(0xFF9D174D)],
      affinity: 'female',
    ),
    SpiritualAvatar(
      id: 'diya',
      asset: 'assets/art/avatars/diya.svg',
      label: 'Diya',
      gradient: [Color(0xFFF59E0B), Color(0xFFB45309)],
    ),
    SpiritualAvatar(
      id: 'hands',
      asset: 'assets/art/avatars/hands.svg',
      label: 'Open Palms',
      gradient: [Color(0xFF10B981), Color(0xFF065F46)],
    ),
    SpiritualAvatar(
      id: 'peacock',
      asset: 'assets/art/avatars/peacock.svg',
      label: 'Peacock Feather',
      gradient: [Color(0xFF6366F1), Color(0xFF3730A3)],
    ),
    SpiritualAvatar(
      id: 'sunrise',
      asset: 'assets/art/avatars/sunrise.svg',
      label: 'Amrit Vela',
      gradient: [Color(0xFFF97316), Color(0xFF9A3412)],
    ),
    SpiritualAvatar(
      id: 'tree',
      asset: 'assets/art/avatars/tree.svg',
      label: 'Rooted',
      gradient: [Color(0xFF059669), Color(0xFF064E3B)],
    ),
  ];

  static SpiritualAvatar? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The avatar suggested when someone picks a gender and has not chosen one.
  static SpiritualAvatar defaultFor(String? gender) {
    final g = gender?.toLowerCase().trim();
    if (g == 'male') return byId('meditator_m')!;
    if (g == 'female') return byId('meditator_f')!;
    return byId('soul')!;
  }

  /// The set offered to a member: everything, with the figure that does not
  /// match their stated gender left out so the grid stays short and relevant.
  /// Gender is never required — someone who has not set one sees them all.
  static List<SpiritualAvatar> forGender(String? gender) {
    final g = gender?.toLowerCase().trim();
    if (g != 'male' && g != 'female') return all;
    return all.where((a) => a.affinity == null || a.affinity == g).toList();
  }
}
