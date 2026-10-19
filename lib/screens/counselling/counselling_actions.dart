import 'package:flutter/material.dart';

import '../../models/counselling_session.dart';
import '../../services/counselling_service.dart';

enum CounsellingAction { end, delete }

/// Destructive changes stay pending until the server confirms them. An error
/// leaves the dialog open so an operator never mistakes a failed tap for success.
Future<bool> confirmCounsellingAction({
  required BuildContext context,
  required CounsellingService service,
  required CounsellingSession session,
  required CounsellingAction action,
}) async {
  var busy = false;
  String? error;
  final deleting = action == CounsellingAction.delete;
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(
              deleting ? 'Delete this conversation?' : 'End this session?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name.isEmpty
                      ? 'This member’s conversation'
                      : session.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(deleting
                    ? 'This permanently removes the request and its messages for both the member and admin. It cannot be undone.'
                    : 'The chat will close. Its messages stay readable for two hours, then the conversation is deleted automatically.'),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  busy ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (deleting) {
                          await service.deleteSession(session.id);
                        } else {
                          await service.endSession(session.id);
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setLocal(() {
                            busy = false;
                            error =
                                'Could not ${deleting ? 'delete the conversation' : 'end the session'}. Please retry.';
                          });
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(deleting ? 'Delete conversation' : 'End session'),
            ),
          ],
        ),
      ),
    ),
  );
  return changed == true;
}
