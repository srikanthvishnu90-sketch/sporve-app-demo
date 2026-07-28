import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/push/push_service.dart';
import '../authentication/controllers/auth_provider.dart';
import '../client/view/home_screen.dart';
import '../client/view/search_screen.dart';
import '../client/view/schedule_screen.dart';
import '../client/view/messages_screen.dart';
import '../client/view/profile_screen.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../widgets/motion_widgets.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    // Home is the browse-first provider feed. It personalizes to the athlete's
    // goal once one is set (server-ranked "best for your goal" rail on top).
    const HomeScreen(),
    const SearchScreen(),
    const ScheduleScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // The user has reached the app shell → a session exists. Register this
    // device for push (no-op unless a Firebase project is wired up).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PushService>().register();
      // Airbnb-style: browse-first. A dismissible "sign in / create account"
      // popup appears once for guests — never a blocking screen.
      context.read<AuthProvider>().maybeShowEntryPrompt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      // Instant tab switching with every tab kept alive — preserves each tab's
      // state and scroll position (no rebuild/re-fetch on switch).
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.ink,
          border: Border(top: BorderSide(color: AppColors.hairline, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand indicator slides to the active tab (Kalshi-style).
              const SizedBox(height: 6),
              SlidingTabIndicator(
                count: 5,
                index: _selectedIndex,
                color: AppColors.slateText,
                slotPadding: const EdgeInsets.symmetric(horizontal: 26),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    AnimatedNavItem(
                      icon: Icons.home_outlined, activeIcon: Icons.home,
                      label: 'Home', selected: _selectedIndex == 0,
                      onTap: () => _select(0),
                    ),
                    AnimatedNavItem(
                      icon: Icons.search_outlined, activeIcon: Icons.search,
                      label: 'Explore', selected: _selectedIndex == 1,
                      onTap: () => _select(1),
                    ),
                    AnimatedNavItem(
                      icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today,
                      label: 'Bookings', selected: _selectedIndex == 2,
                      onTap: () => _select(2),
                    ),
                    AnimatedNavItem(
                      icon: Icons.forum_outlined, activeIcon: Icons.forum,
                      label: 'Messages', selected: _selectedIndex == 3,
                      onTap: () => _select(3),
                    ),
                    AnimatedNavItem(
                      icon: Icons.person_outline, activeIcon: Icons.person,
                      label: 'Profile', selected: _selectedIndex == 4,
                      onTap: () => _select(4),
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

  void _select(int index) => setState(() => _selectedIndex = index);
}
