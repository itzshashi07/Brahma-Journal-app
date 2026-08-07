import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math';
import '../../providers/auth_provider.dart';
import '../../services/meditation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';

class MeditationScreen extends StatefulWidget {
  /// Preselected session length, passed through when a guided theme is chosen.
  final int? initialMinutes;
  const MeditationScreen({super.key, this.initialMinutes});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> with TickerProviderStateMixin {
  final MeditationService _service = MeditationService();
  late int _selectedDuration = widget.initialMinutes ?? 5;
  bool _isActive = false;
  bool _isCompleted = false;
  int _currentMantra = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AudioPlayer _audioPlayer;

  /// Elapsed time is measured against the wall clock, not by counting timer
  /// ticks. Timer.periodic is throttled or suspended whenever the app is
  /// backgrounded or the screen locks, so tick-counting under-reported real
  /// meditation time — a 10 minute session logged as 6.
  int _accumulatedSeconds = 0; // finished run segments in this session
  DateTime? _segmentStartedAt; // when the current run segment began
  int _savedSeconds = 0; // already written to Firestore for this session
  int _lastMantraSecond = -1;
  String? _uid;

  final List<Map<String, String>> _sounds = [
    {
      'id': 'nature',
      'name': 'Forest Sounds',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
    },
    {
      'id': 'tibetan',
      'name': 'Tibetan Bowls',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'
    },
    {
      'id': 'ocean',
      'name': 'Ocean Waves',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'
    },
    {
      'id': 'flute',
      'name': 'Peaceful Flute',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'
    },
    {
      'id': 'chimes',
      'name': 'Wind Chimes',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'
    },
    {
      'id': 'silence',
      'name': 'Silence',
      'url': ''
    },
  ];
  String _selectedSound = 'nature';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _audioPlayer = AudioPlayer();
    _audioPlayer.setLoopMode(LoopMode.one).catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cached here because dispose() must not touch the widget tree's context.
    _uid = context.read<AuthProvider>().user?.uid;
  }

  int get _totalSeconds => _selectedDuration * 60;

  /// Real seconds meditated in this session, pauses excluded.
  int get _elapsedSeconds {
    final start = _segmentStartedAt;
    final running = start == null ? 0 : DateTime.now().difference(start).inSeconds;
    final elapsed = _accumulatedSeconds + running;
    return elapsed > _totalSeconds ? _totalSeconds : elapsed;
  }

  int get _timeLeft {
    final left = _totalSeconds - _elapsedSeconds;
    return left < 0 ? 0 : left;
  }

  Future<void> _changeSound(String soundId) async {
    setState(() => _selectedSound = soundId);
    if (_isActive) {
      await _playSelectedSound();
    }
  }

  Future<void> _playSelectedSound() async {
    final soundObj = _sounds.firstWhere((s) => s['id'] == _selectedSound);
    final url = soundObj['url'] ?? '';
    if (url.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(url);
        if (_isActive) {
          _audioPlayer.play();
        }
      } catch (e) {
        print('❌ Audio player error: $e');
      }
    } else {
      await _audioPlayer.stop();
    }
  }

  /// Play/pause button. A finished session starts a fresh one.
  void _onPrimaryTap() {
    if (_isActive) {
      _pauseTimer();
    } else {
      if (_isCompleted) _resetTimer();
      _startTimer();
    }
  }

  void _startTimer() {
    if (_isActive) return;
    setState(() {
      _isActive = true;
      _isCompleted = false;
      _segmentStartedAt = DateTime.now();
    });
    _pulseCtrl.repeat(reverse: true);
    _playSelectedSound();

    // Ticks only drive the display; the numbers come from the wall clock, so a
    // dropped tick costs nothing.
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft <= 0) {
        _completeSession();
      } else {
        setState(() {});
        // Guarded on the second, not the tick: four ticks land in the same
        // second and would otherwise flip the mantra four times.
        final elapsed = _elapsedSeconds;
        if (elapsed > 0 && elapsed % 15 == 0 && elapsed != _lastMantraSecond) {
          _lastMantraSecond = elapsed;
          _rotateMantra();
        }
      }
    });
  }

  void _completeSession() {
    _timer?.cancel();
    _pulseCtrl.stop();
    _audioPlayer.stop();
    _accumulatedSeconds = _totalSeconds;
    _segmentStartedAt = null;
    setState(() {
      _isActive = false;
      _isCompleted = true;
    });
    _saveSession();
    _rotateMantra();
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pulseCtrl.stop();
    _audioPlayer.pause();
    setState(() {
      _accumulatedSeconds = _elapsedSeconds;
      _segmentStartedAt = null;
      _isActive = false;
    });
    _saveSession();
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    _audioPlayer.stop();
    _saveSession(); // bank whatever was meditated before clearing it
    setState(() {
      _isActive = false;
      _isCompleted = false;
      _accumulatedSeconds = 0;
      _segmentStartedAt = null;
      _savedSeconds = 0;
    });
  }

  void _rotateMantra() {
    if (!mounted) return;
    setState(() {
      _currentMantra = Random().nextInt(AppConstants.mantras.length);
    });
  }

  /// Persists only the part of this session that has not been stored yet, so
  /// pausing twice does not log the same minutes twice.
  Future<void> _saveSession() async {
    final uid = _uid;
    final pending = _elapsedSeconds - _savedSeconds;
    if (uid == null || pending <= 0) return;
    _savedSeconds += pending;
    final saved = await _service.saveSession(uid, pending);
    if (!saved) _savedSeconds -= pending; // let a later attempt retry it
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Bank the in-progress segment before tearing down; saveSession() writes
    // through the Firestore SDK, which completes the write after disposal.
    _accumulatedSeconds = _elapsedSeconds;
    _segmentStartedAt = null;
    _saveSession();
    _pulseCtrl.dispose();
    _audioPlayer.dispose();
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
                                  _saveSession(); // keep any time already sat
                                  setState(() {
                                    _selectedDuration = d;
                                    _accumulatedSeconds = 0;
                                    _segmentStartedAt = null;
                                    _savedSeconds = 0;
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
                              onTap: () => _changeSound(s['id']!),
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
                          if (_isActive || _elapsedSeconds > 0)
                            _ControlButton(
                              icon: Icons.refresh,
                              label: 'Reset',
                              onTap: _resetTimer,
                              color: AppTheme.textMuted,
                            ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: _onPrimaryTap,
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                gradient: _isCompleted ? AppTheme.goldGradient : AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
                              ),
                              child: Icon(
                                _isCompleted ? Icons.replay : (_isActive ? Icons.pause : Icons.play_arrow),
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
                          child: Column(
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              const Text('Session Complete!', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              const SizedBox(height: 4),
                              Text(
                                '$_selectedDuration min saved to your practice.',
                                style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary, fontSize: 13),
                              ),
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
