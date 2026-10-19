import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import 'sacred.dart';

class AdultCommunityGate extends StatelessWidget {
  const AdultCommunityGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAdmin || (auth.profile?.age ?? 0) >= 18) return child;
    return Scaffold(body: SacredBackdrop(child: SafeArea(child: Column(children: [
      SacredAppBar(title: 'Your space', onBack: () => context.pop()),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.shield_outlined, size: 56, color: AppTheme.primaryLight), const SizedBox(height: 24),
        const Text('A calmer place to explore', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
        const Text('Anonymous community conversations are for adults. You can still play a short game, explore everyday wisdom, and keep your thoughts private. For something worrying you, talk to a trusted adult.', style: TextStyle(height: 1.6, color: AppTheme.textSecondary, fontSize: 16)),
        const SizedBox(height: 24), SacredButton(label: 'Explore Game Zone', onTap: () => context.push('/games')),
        const SizedBox(height: 12), SacredButton(label: 'Gratitude & Small Wins', secondary: true, onTap: () => context.push('/small-wins')),
        if (auth.profile?.age == null) TextButton(onPressed: () => context.push('/profile'), child: const Text('Complete your profile')),
      ]))),
    ]))));
  }
}
