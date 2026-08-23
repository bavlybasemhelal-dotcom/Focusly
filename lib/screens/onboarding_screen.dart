import 'package:flutter/material.dart';
import 'login_screen.dart';

// ==============================================================================
// FOCUSLY COLOR PALETTE (Matched with Splash Screen)
// ==============================================================================
const Color kBgDark = Color(0xFF060B24);
const Color kBgMidnight = Color(0xFF0B1647);
const Color kNavyDeep = Color(0xFF08123A);
const Color kCyanElectric = Color(0xFF00E5FF);
const Color kBlueSky = Color(0xFF29A9FF);
const Color kBlueRoyal = Color(0xFF1E58F6);
const Color kGreenNeon = Color(0xFF4ADE80);
const Color kGreenVibrant = Color(0xFF22C55E);
const Color kAmberGold = Color(0xFFFFB020);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSlate = Color(0xFF94A3B8);

/// Data model representing a single onboarding slide.
/// Adding more onboarding pages in the future is as simple as adding a new entry to the data list.
class OnboardingPageData {
  final String title;
  final String subtitle;
  final String tag;
  final String imagePath;
  final IconData heroIcon;
  final Color primaryGlowColor;
  final Color secondaryGlowColor;
  final List<String> badges;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.imagePath,
    required this.heroIcon,
    required this.primaryGlowColor,
    required this.secondaryGlowColor,
    required this.badges,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPageIndex = 0;

  // ---------------------------------------------------------------------------
  // ONBOARDING DATA DEFINITIONS
  // ---------------------------------------------------------------------------
  static const List<OnboardingPageData> _pages = [
    // Page 1: Organize Everything
    OnboardingPageData(
      title: 'Organize Everything',
      subtitle:
          'Unify your daily tasks, habits, and schedule in one smart workspace powered by adaptive AI planning.',
      tag: 'ALL-IN-ONE SYSTEM',
      imagePath: 'assets/images/onboarding_1.png',
      heroIcon: Icons.checklist_rounded,
      primaryGlowColor: kCyanElectric,
      secondaryGlowColor: kBlueRoyal,
      badges: ['Smart Task Engine', 'Calendar Sync', 'Daily Priorities'],
    ),
    // Page 2: Build Better Habits
    OnboardingPageData(
      title: 'Build Better Habits',
      subtitle:
          'Turn consistency into a habit with daily streak trackers, visual progress rings, and milestone celebrations.',
      tag: 'STREAK & TRACKING',
      imagePath: 'assets/images/onboarding_2.png',
      heroIcon: Icons.local_fire_department_rounded,
      primaryGlowColor: kAmberGold,
      secondaryGlowColor: kGreenNeon,
      badges: ['7-Day Streaks', 'Habit Heatmaps', 'XP Rewards'],
    ),
    // Page 3: Stay Focused
    OnboardingPageData(
      title: 'Stay Focused',
      subtitle:
          'Eliminate distractions and enter flow state with Pomodoro sprints, ambient soundscapes, and deep focus timers.',
      tag: 'DEEP WORK FLOW',
      imagePath: 'assets/images/onboarding_3.png',
      heroIcon: Icons.timer_rounded,
      primaryGlowColor: kGreenNeon,
      secondaryGlowColor: kCyanElectric,
      badges: ['25m Focus Block', 'Flow State 98%', 'Ambient Noise'],
    ),
    // Page 4: Grow With Your Team
    OnboardingPageData(
      title: 'Grow With Your Team',
      subtitle:
          'Form accountability squads, join group productivity challenges, and push your team goals together.',
      tag: 'COMMUNITY & CHALLENGES',
      imagePath: 'assets/images/onboarding_4.png',
      heroIcon: Icons.groups_rounded,
      primaryGlowColor: kBlueSky,
      secondaryGlowColor: kGreenNeon,
      badges: ['Squad Challenges', 'Leaderboards', 'Shared Goals'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Navigates forward to next page or finishes onboarding.
  void _onNextPressed() {
    if (_currentPageIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  /// Finalizes the onboarding flow and navigates to the Auth/Login screen.
  void _finishOnboarding() {
    // TODO: Persist onboarding completion flag in persistent storage
    // e.g.: final prefs = await SharedPreferences.getInstance();
    //       await prefs.setBool('has_seen_onboarding', true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isLastPage = _currentPageIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // -----------------------------------------------------------------
          // 1. AMBIENT AURORA BLOOMS
          // -----------------------------------------------------------------
          _buildAmbientGlowBlooms(),

          // -----------------------------------------------------------------
          // 2. MAIN CONTENT (Top Bar + PageView + Indicators + Bottom Button)
          // -----------------------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                // Top Header Bar (Brand Logo & Skip Button)
                _buildTopNavigationBar(isLastPage),

                // Swipeable PageView Area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildOnboardingPage(
                        _pages[index],
                        screenSize,
                      );
                    },
                  ),
                ),

                // Bottom Controls: Animated Pill Indicators & Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Neon Page Indicator Dots
                      _buildPageIndicators(),
                      const SizedBox(height: 24),

                      // Full-width Gradient Action Button ("Next" -> "Get Started")
                      _buildActionButton(isLastPage),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ambient background aurora light-blooms
  Widget _buildAmbientGlowBlooms() {
    final currentPage = _pages[_currentPageIndex];

    return Stack(
      children: [
        // Top-right dynamic bloom
        Positioned(
          top: -60,
          right: -60,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  currentPage.primaryGlowColor.withValues(alpha: 0.18),
                  kBlueRoyal.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom-left dynamic bloom
        Positioned(
          bottom: -40,
          left: -50,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  currentPage.secondaryGlowColor.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Top Bar with brand icon badge and animated "Skip" button
  Widget _buildTopNavigationBar(bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mini Brand Logo Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B4C).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  size: 16,
                  color: kCyanElectric,
                ),
                SizedBox(width: 6),
                Text(
                  'Focusly',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextWhite,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // "Skip" button (smoothly fades out on final page)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isLastPage ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: isLastPage,
              child: TextButton(
                onPressed: _finishOnboarding,
                style: TextButton.styleFrom(
                  foregroundColor: kTextSlate,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kCyanElectric,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single onboarding page slide with illustration card, titles, and feature chips
  Widget _buildOnboardingPage(OnboardingPageData data, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // -----------------------------------------------------------------
          // HERO ILLUSTRATION CARD WITH GLOWING ACCENT
          // -----------------------------------------------------------------
          Container(
            width: double.infinity,
            height: size.height * 0.34,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B4C).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: data.primaryGlowColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: data.primaryGlowColor.withValues(alpha: 0.15),
                  blurRadius: 25,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Radial center highlight
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          data.primaryGlowColor.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Image Asset with fallback to high-end vector illustration
                  Image.asset(
                    data.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF08123A),
                              border: Border.all(
                                color: data.primaryGlowColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: data.primaryGlowColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Icon(
                              data.heroIcon,
                              size: 46,
                              color: data.primaryGlowColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Mini floating badge inside the card
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: data.badges.map((badge) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF08123A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: kTextSlate,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Category Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: data.primaryGlowColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: data.primaryGlowColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              data.tag,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: data.primaryGlowColor,
                letterSpacing: 1.0,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Main Headline
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: kTextWhite,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Supporting Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: kTextSlate,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  /// Builds the animated dot/pill page indicators
  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final bool isActive = index == _currentPageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isActive
                ? const LinearGradient(
                    colors: [kCyanElectric, kGreenNeon],
                  )
                : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: kCyanElectric.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  /// Builds the full-width high-tech action button
  Widget _buildActionButton(bool isLastPage) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _onNextPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLastPage
                  ? [kBlueRoyal, kCyanElectric, kGreenNeon]
                  : [kBlueRoyal, kCyanElectric],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isLastPage
                    ? kGreenNeon.withValues(alpha: 0.4)
                    : kCyanElectric.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLastPage ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isLastPage
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
