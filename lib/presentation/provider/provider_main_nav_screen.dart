import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/push/push_service.dart';
import './view/provider_dashboard_screen.dart';
import './view/provider_listings_screen.dart';
import './view/provider_schedule_screen.dart';
import './view/provider_chat_screen.dart';
import './view/provider_profile_screen.dart';
import '../widgets/common_widgets.dart';
import '../widgets/motion_widgets.dart';

class ProviderMainNavScreen extends StatefulWidget {
  const ProviderMainNavScreen({super.key});

  @override
  State<ProviderMainNavScreen> createState() => _ProviderMainNavScreenState();
}

class _ProviderMainNavScreenState extends State<ProviderMainNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ProviderDashboardScreen(),
    const ProviderListingsScreen(),
    const ProviderScheduleScreen(),
    const ProviderChatScreen(),
    const ProviderProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Provider reached their app shell → a session exists. Register this device
    // for push (no-op unless a Firebase project is wired up).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PushService>().register();
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
                      icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded,
                      label: 'DASHBOARD', selected: _selectedIndex == 0,
                      onTap: () => _select(0),
                    ),
                    AnimatedNavItem(
                      icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt_rounded,
                      label: 'LISTINGS', selected: _selectedIndex == 1,
                      onTap: () => _select(1),
                    ),
                    AnimatedNavItem(
                      icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today,
                      label: 'SCHEDULE', selected: _selectedIndex == 2,
                      onTap: () => _select(2),
                    ),
                    AnimatedNavItem(
                      icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble,
                      label: 'CHAT', selected: _selectedIndex == 3,
                      onTap: () => _select(3),
                    ),
                    AnimatedNavItem(
                      icon: Icons.person_outline, activeIcon: Icons.person,
                      label: 'PROFILE', selected: _selectedIndex == 4,
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
