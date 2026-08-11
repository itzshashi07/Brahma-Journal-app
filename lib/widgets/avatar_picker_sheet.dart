import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/constants/modern_avatars.dart';
import '../core/constants/spiritual_avatars.dart';
import '../core/theme/app_theme.dart';
import 'modern_avatar_art.dart';

/// Avatar chooser: build a modern one, or keep the spiritual set.
///
/// The spiritual avatars stay because some members chose them deliberately and
/// they suit the app. What they cannot do is look like the person holding the
/// phone — eight fixed pictures across a whole community means duplicates on
/// every leaderboard. The built avatars solve that without a photo upload,
/// which would mean storage, moderation, and someone's face on a public screen.
class AvatarPickerSheet extends StatefulWidget {
  final String? currentId;
  final String? gender;

  const AvatarPickerSheet({super.key, this.currentId, this.gender});

  /// Returns the chosen avatar id, or null if the sheet was dismissed.
  static Future<String?> show(
    BuildContext context, {
    String? currentId,
    String? gender,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(currentId: currentId, gender: gender),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late ModernAvatar _draft = ModernAvatar.isModern(widget.currentId)
      ? ModernAvatar.parse(widget.currentId)
      : ModernAvatar.presets.first;

  bool _modernTab = true;

  void _shuffle() {
    final r = Random();
    setState(() {
      _draft = ModernAvatar(
        bg: r.nextInt(ModernAvatar.backgrounds.length),
        skin: r.nextInt(ModernAvatar.skinTones.length),
        hair: r.nextInt(ModernAvatar.hairStyles.length),
        hairColor: r.nextInt(ModernAvatar.hairColors.length),
        face: r.nextInt(ModernAvatar.faces.length),
        accessory: r.nextInt(ModernAvatar.accessories.length),
        clothes: r.nextInt(ModernAvatar.clothesColors.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          margin: const EdgeInsets.all(AppTheme.space3),
          padding: const EdgeInsets.fromLTRB(AppTheme.space5, AppTheme.space4,
              AppTheme.space5, AppTheme.space4),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              _TabBar(
                modern: _modernTab,
                onChanged: (v) => setState(() => _modernTab = v),
              ),
              const SizedBox(height: AppTheme.space4),
              Flexible(
                child: _modernTab ? _buildModern() : _buildSpiritual(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── modern tab ───────────────────────────

  Widget _buildModern() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                ModernAvatarArt(avatar: _draft, size: 116),
                const SizedBox(height: AppTheme.space3),
                TextButton.icon(
                  onPressed: _shuffle,
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: const Text('Shuffle',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space2),

          // Ready-made looks first: most people pick one and leave, and the
          // rows below are for the few who want to fiddle.
          _label('Quick picks'),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ModernAvatar.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.space3),
              itemBuilder: (_, i) {
                final p = ModernAvatar.presets[i];
                final selected = p.id == _draft.id;
                return GestureDetector(
                  onTap: () => setState(() => _draft = p),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppTheme.primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ModernAvatarArt(avatar: p, size: 52),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.space4),

          _swatchRow(
            'Background',
            ModernAvatar.backgrounds.length,
            _draft.bg,
            (i) => setState(() => _draft = _draft.copyWith(bg: i)),
            swatch: (i) => _gradientDot(ModernAvatar.backgrounds[i]),
          ),
          _swatchRow(
            'Skin',
            ModernAvatar.skinTones.length,
            _draft.skin,
            (i) => setState(() => _draft = _draft.copyWith(skin: i)),
            swatch: (i) => _colorDot(ModernAvatar.skinTones[i]),
          ),
          _optionRow(
            'Hair',
            ModernAvatar.hairStyles,
            _draft.hair,
            (i) => setState(() => _draft = _draft.copyWith(hair: i)),
          ),
          _swatchRow(
            'Hair colour',
            ModernAvatar.hairColors.length,
            _draft.hairColor,
            (i) => setState(() => _draft = _draft.copyWith(hairColor: i)),
            swatch: (i) => _colorDot(ModernAvatar.hairColors[i]),
          ),
          _optionRow(
            'Expression',
            ModernAvatar.faces,
            _draft.face,
            (i) => setState(() => _draft = _draft.copyWith(face: i)),
          ),
          _optionRow(
            'Accessory',
            ModernAvatar.accessories,
            _draft.accessory,
            (i) => setState(() => _draft = _draft.copyWith(accessory: i)),
          ),
          _swatchRow(
            'Clothes',
            ModernAvatar.clothesColors.length,
            _draft.clothes,
            (i) => setState(() => _draft = _draft.copyWith(clothes: i)),
            swatch: (i) => _colorDot(ModernAvatar.clothesColors[i]),
          ),

          const SizedBox(height: AppTheme.space5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_draft.id),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Use this avatar',
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space2),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      );

  Widget _swatchRow(
    String label,
    int count,
    int selected,
    ValueChanged<int> onTap, {
    required Widget Function(int) swatch,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: AppTheme.space3),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: swatch(i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(
    String label,
    List<String> options,
    int selected,
    ValueChanged<int> onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              for (var i = 0; i < options.length; i++)
                GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: i == selected ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: i == selected
                            ? AppTheme.primaryLight
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color c) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(color: Colors.white24),
        ),
      );

  Widget _gradientDot(List<Color> colors) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  // ────────────────────────── spiritual tab ──────────────────────────

  Widget _buildSpiritual() {
    final options = SpiritualAvatars.forGender(widget.gender);
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppTheme.space3,
        crossAxisSpacing: AppTheme.space3,
        childAspectRatio: 0.78,
      ),
      itemCount: options.length,
      itemBuilder: (_, i) {
        final a = options[i];
        final selected = a.id == widget.currentId;
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(a.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: a.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: SvgPicture.asset(
                      a.asset,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                a.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppTheme.primaryLight : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  final bool modern;
  final ValueChanged<bool> onChanged;

  const _TabBar({required this.modern, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _tab('Build your own', modern, () => onChanged(true)),
          _tab('Classic', !modern, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
