import 'package:flutter/material.dart';
import '../core/constants/profile_pictures.dart';
import '../core/theme/app_theme.dart';
import 'profile_avatar.dart';

/// A fixed, bundled picture selector. No editor, uploads or network images.
class AvatarPickerSheet extends StatelessWidget {
  final String? currentId;
  final String? gender;
  const AvatarPickerSheet({super.key, this.currentId, this.gender});

  static Future<String?> show(BuildContext context,
          {String? currentId, String? gender}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.bgCard,
        showDragHandle: true,
        builder: (_) => AvatarPickerSheet(currentId: currentId),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose your profile picture',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Six ready-made pictures. Tap one to select it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < ProfilePictures.all.length; i++)
                    Semantics(
                      label: 'Profile picture ${i + 1}',
                      button: true,
                      selected: ProfilePictures.all[i].id == currentId,
                      child: InkWell(
                        key: ValueKey('profile-picture-$i'),
                        borderRadius: BorderRadius.circular(48),
                        onTap: () =>
                            Navigator.pop(context, ProfilePictures.all[i].id),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: ProfileAvatar(
                              initials: '',
                              avatarId: ProfilePictures.all[i].id,
                              size: 76,
                              showRing: ProfilePictures.all[i].id == currentId),
                        ),
                      ),
                    ),
                ]),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
          ]),
        ),
      );
}
