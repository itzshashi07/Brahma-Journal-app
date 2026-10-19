import 'package:flutter/material.dart';
import '../../core/constants/real_life_wisdom.dart';
import '../../core/theme/app_theme.dart';

class RealLifeCards extends StatefulWidget {
  const RealLifeCards({super.key});
  @override
  State<RealLifeCards> createState() => _RealLifeCardsState();
}
class _RealLifeCardsState extends State<RealLifeCards> {
  bool _hinglish = false;
  String _topic = 'All';
  @override
  Widget build(BuildContext context) {
    final cards = realLifeWisdom.where((v) => _topic == 'All' || v.topic == _topic).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: Row(children: [
        const Expanded(child: Text('Real situations. One small next step.', style: TextStyle(color: AppTheme.textSecondary))),
        TextButton(onPressed: () => setState(() => _hinglish = !_hinglish), child: Text(_hinglish ? 'Hinglish' : 'English')),
      ])),
      SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        for (final topic in ['All', ...realLifeWisdom.map((v) => v.topic).toSet()]) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(topic), selected: topic == _topic, onSelected: (_) => setState(() => _topic = topic))),
      ])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: cards.length, itemBuilder: (_, i) {
        final c = cards[i];
        return Container(margin: const EdgeInsets.only(bottom: 18), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.topic.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: AppTheme.accentLight)),
          const SizedBox(height: 12), Text(_hinglish ? c.hinglishTitle : c.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600, height: 1.2)),
          const SizedBox(height: 14), Text(_hinglish ? c.hinglishBody : c.body, style: const TextStyle(height: 1.6, color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 18), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_hinglish ? 'AAJ TRY KARO' : 'TRY TODAY', style: const TextStyle(fontSize: 11, letterSpacing: 1.4, color: AppTheme.primaryLight, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8), Text(_hinglish ? c.hinglishAction : c.action, style: const TextStyle(height: 1.5)),
          ])),
        ]));
      })),
    ]);
  }
}
