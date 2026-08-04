import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../../providers/auth_provider.dart';
import '../../services/meditation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> with TickerProviderStateMixin {
  final MeditationService _service = MeditationService();
  int _selectedDuration = 5;
  int _timeLeft = 5 * 60;
  bool _isActive = false;
  bool _isCompleted = false;
  int _currentMantra = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<Map<String, String>> _sounds = [
    {'id': 'nature', 'name': 'Forest Sounds'},
    {'id': 'tibetan', 'name': 'Tibetan Bowls'},
    {'id': 'ocean', 'name': 'Ocean Waves'},
    {'id': 'flute', 'name': 'Peaceful Flute'},
    {'id': 'chimes', 'name': 'Wind Chimes'},
    {'id': 'silence', 'name': 'Silence'},
  ];
  String _selectedSound = 'nature';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  void _startTimer() {
    setState(() { _isActive = true; _isCompleted = false; });
    _pulseCtrl.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 0) {
        timer.cancel();
        _pulseCtrl.stop();
        setState(() { _isActive = false; _isCompleted = true; });
        _saveSession();
        _rotateMantra();
      } else {
        setState(() { _timeLeft--; });
        if (_timeLeft % 10 == 0) _rotateMantra();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() => _isActive = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() {
      _isActive = false;
      _isCompleted = false;
      _timeLeft = _selectedDuration * 60;
    });
  }

  void _rotateMantra() {
    setState(() {
      _currentMantra = Random().nextInt(AppConstants.mantras.length);
    });
  }

  Future<void> _saveSession() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      await _service.saveSession(auth.user!.uid, _selectedDuration);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _timeLeft / (_selectedDuration * 60);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Meditation',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Circular Timer
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isActive ? _pulseAnim.value : 1.0,
                            child: SizedBox(
                              width: 220, height: 220,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 220, height: 220,
                                    child: CircularProgressIndicator(
                                      value: _isCompleted ? 1 : (1 - progress),
                                      strokeWidth: 8,
                                      backgroundColor: AppTheme.bgCard,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _isCompleted ? const Color(0xFF10B981) : AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 180, height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [AppTheme.primary.withOpacity(0.15), AppTheme.bgCard],
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (_isCompleted) ...[
                                          const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                                          const SizedBox(height: 8),
                                          const Text('Complete!', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w600)),
                                        ] else ...[
                                          const Icon(Icons.spa_outlined, size: 36, color: AppTheme.primary),
                                          const SizedBox(height: 8),
                                          Text(
                                            formatTimer(_timeLeft),
                                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 40, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                          ),
                                          Text(
                                            '$_selectedDuration min session',
                                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Mantra
                      if (_isActive)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          child: Container(
                            key: ValueKey(_currentMantra),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                            ),
                            child: Text(
                              AppConstants.mantras[_currentMantra],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.primaryLight, fontSize: 16, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Duration Selection
                      if (!_isActive && !_isCompleted) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Session Duration', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: AppConstants.meditationDurations.map((d) {
                            final isSelected = _selectedDuration == d;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDuration = d;
                                    _timeLeft = d * 60;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary : AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFF2D2D4E)),
                                  ),
                                  child: Text(
                                    '${d}m',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Sound Selection
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Background Sound', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _sounds.map((s) {
                            final isSelected = _selectedSound == s['id'];
                            return GestureDetector(
                              onTap: () => setState(() => _selectedSound = s['id']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primary.withOpacity(0.2) : AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? AppTheme.primary : const Color(0xFF2D2D4E)),
                                ),
                                child: Text(
                                  s['name']!,
                                  style: TextStyle(
                                    fontFamily: 'Outfit', fontSize: 13,
                                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Control Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isActive || _timeLeft < _selectedDuration * 60)
                            _ControlButton(
                              icon: Icons.refresh,
                              label: 'Reset',
                              onTap: _resetTimer,
                              color: AppTheme.textMuted,
                            ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _isActive ? _pauseTimer : _startTimer,
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                gradient: _isCompleted ? AppTheme.goldGradient : AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                              ),
                              child: Icon(
                                _isCompleted ? Icons.check : (_isActive ? Icons.pause : Icons.play_arrow),
                                color: Colors.white, size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isCompleted) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: const Column(
                            children: [
                              Text('🎉', style: TextStyle(fontSize: 32)),
                              SizedBox(height: 8),
                              Text('Session Complete!', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              SizedBox(height: 4),
                              Text('Your meditation session has been saved.', style: TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
