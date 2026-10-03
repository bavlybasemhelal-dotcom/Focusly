import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_colors.dart';
import 'login_screen.dart';

/// Data model representing a single onboarding slide.
class OnboardingPageData {
  final String titleKey;
  final String subtitleKey;
  final IconData heroIcon;
  final Color glowColorDark;
  final Color glowColorLight;

  const OnboardingPageData({
    required this.titleKey,
    required this.subtitleKey,
    required this.heroIcon,
    required this.glowColorDark,
    required this.glowColorLight,
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

  static const List<OnboardingPageData> _pages = [
    // Page 1: Organize Everything
    OnboardingPageData(
      titleKey: 'onboarding_title_1',
      subtitleKey: 'onboarding_sub_1',
      heroIcon: Icons.checklist_rounded,
      glowColorDark: AppColors.cyanElectric,
      glowColorLight: Color(0xFF2563EB),
    ),
    // Page 2: Build Better Habits
    OnboardingPageData(
      titleKey: 'onboarding_title_2',
      subtitleKey: 'onboarding_sub_2',
      heroIcon: Icons.local_fire_department_rounded,
      glowColorDark: AppColors.amberGold,
      glowColorLight: Color(0xFFF59E0B),
    ),
    // Page 3: Stay Focused
    OnboardingPageData(
      titleKey: 'onboarding_title_3',
      subtitleKey: 'onboarding_sub_3',
      heroIcon: Icons.timer_rounded,
      glowColorDark: AppColors.accentGreenNeon,
      glowColorLight: Color(0xFF10B981),
    ),
    // Page 4: Grow With Your Team
    OnboardingPageData(
      titleKey: 'onboarding_title_4',
      subtitleKey: 'onboarding_sub_4',
      heroIcon: Icons.groups_rounded,
      glowColorDark: AppColors.primaryBlueLight,
      glowColorLight: Color(0xFF6366F1),
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

  void _navigateToLogin() {
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

  void _onNextPressed() {
    if (_currentPageIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final isLastPage = _currentPageIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // -----------------------------------------------------------------
          // 1. DYNAMIC AMBIENT AURORA BLOOM
          // -----------------------------------------------------------------
          _buildAmbientGlowBlooms(isDark),

          // -----------------------------------------------------------------
          // 2. MAIN ONBOARDING PAGEVIEW & CONTROLS
          // -----------------------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                // Top Header with Logo & Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mini Brand Mark
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF0F1B4C)
                                  : Colors.white,
                              border: Border.all(
                                color: brandPrimary,
                                width: 1.8,
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2E6FF2,
                                        ).withValues(alpha: 0.1),
                                        blurRadius: 8,
                                      ),
                                    ],
                            ),
                            child: Icon(
                              Icons.track_changes_rounded,
                              color: brandPrimary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('app_name'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),

                      // Skip Button
                      if (!isLastPage)
                        TextButton(
                          onPressed: _navigateToLogin,
                          style: TextButton.styleFrom(
                            foregroundColor: secondaryTextColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 6.0,
                            ),
                          ),
                          child: Text(
                            context.tr('skip'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // PageView with Slides
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
                      final page = _pages[index];
                      return _buildPageContent(
                        page: page,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        brandPrimary: brandPrimary,
                      );
                    },
                  ),
                ),

                // Bottom Indicator & Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(28.0, 12.0, 28.0, 28.0),
                  child: Column(
                    children: [
                      // Animated Indicator Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (index) {
                          final isSelected = index == _currentPageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: isSelected ? 28.0 : 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandPrimary
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Full-width Gradient Next / Get Started Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? AppColors.cyanElectric.withValues(
                                      alpha: 0.35,
                                    )
                                  : const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: isDark
                                ? const Color(0xFF060B24)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage
                                    ? context.tr('get_started')
                                    : context.tr('next'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFF060B24)
                                    : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildPageContent({
    required OnboardingPageData page,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    final glowColor = isDark ? page.glowColorDark : page.glowColorLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero Illustration Box with Luminous Rim
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF0F1B4C).withValues(alpha: 0.7)
                  : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFDBEAFE),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor.withValues(alpha: isDark ? 0.12 : 0.09),
                ),
                child: Center(
                  child: Icon(page.heroIcon, size: 78, color: glowColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Title
          Text(
            context.tr(page.titleKey),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: primaryTextColor,
              letterSpacing: -0.6,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              context.tr(page.subtitleKey),
              style: TextStyle(
                fontSize: 15,
                color: secondaryTextColor,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final page = _pages[_currentPageIndex];
    final glow = isDark ? page.glowColorDark : page.glowColorLight;

    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glow.withValues(alpha: isDark ? 0.18 : 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
