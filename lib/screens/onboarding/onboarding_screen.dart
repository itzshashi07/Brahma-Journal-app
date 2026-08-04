import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.edit_note_outlined,
      'title': 'Daily Journaling',
      'slogan': 'Reflect on your path',
      'desc': 'Write down your daily actions, spiritual practices, and habits. Keep track of what matters to your soul.',
    },
    {
      'icon': Icons.spa_outlined,
      'title': 'Mindful Meditation',
      'slogan': 'Find your inner silence',
      'desc': 'Listen to peaceful ambient soundscapes. Use customizable timers to build a focused daily meditation habit.',
    },
    {
      'icon': Icons.favorite_border_outlined,
      'title': 'Affirmations & Mantras',
      'slogan': 'Cultivate positive energy',
      'desc': 'Anchor your consciousness with Serene Divine affirmations and spiritual mantras designed for peaceful living.',
    },
    {
      'icon': Icons.chat_bubble_outline_outlined,
      'title': 'Anonymous Thoughts',
      'slogan': 'Express safely, zero judgment',
      'desc': 'Share your innermost reflections anonymously and connect with companion souls in a peaceful environment.',
    },
    {
      'icon': Icons.groups_outlined,
      'title': 'Spiritual Community',
      'slogan': 'Grow together in harmony',
      'desc': 'Compete on non-disruptive streak leaderboards. Elevate your spiritual metrics alongside other seekers.',
    },
    {
      'icon': Icons.analytics_outlined,
      'title': 'Deep Mood Analytics',
      'slogan': 'Understand your emotional trends',
      'desc': 'Track and visualize your mental state trends over time to identify what brings you deep peace.',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button Top Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: AppTheme.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // PageView Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Vector Outline Icon Container
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1.5),
                            ),
                            child: Icon(
                              slide['icon'] as IconData,
                              size: 72,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Slogan tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2D4E).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              slide['slogan'] as String,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Slide Title
                          Text(
                            slide['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Slide Description
                          Text(
                            slide['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots Indicator & Action Button Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(_slides.length, (idx) {
                        final isActive = _currentPage == idx;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          height: 6,
                          width: isActive ? 18 : 6,
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primary : const Color(0xFF2D2D4E),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    // Next / Get Started Action Button
                    SizedBox(
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              if (_currentPage == _slides.length - 1) {
                                _completeOnboarding();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28.0),
                              child: Center(
                                child: Text(
                                  _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
