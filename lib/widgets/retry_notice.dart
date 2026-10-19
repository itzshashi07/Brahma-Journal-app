import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class RetryNotice extends StatelessWidget {
  const RetryNotice({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_off_outlined, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 4),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again')),
          ]),
        ),
      );
}
