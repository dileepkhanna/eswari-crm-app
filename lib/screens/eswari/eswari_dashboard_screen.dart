import 'package:flutter/material.dart';
import 'eswari_home_tab.dart';
import 'eswari_calls_tab.dart';
import 'eswari_leads_tab.dart';
import 'eswari_tasks_tab.dart';
import 'eswari_projects_tab.dart';
import 'eswari_more_tab.dart';
import '../../widgets/announcement_popup.dart';

class EswariDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EswariDashboardScreen({super.key, required this.userData});

  @override
  State<EswariDashboardScreen> createState() => _EswariDashboardScreenState();
}

class _EswariDashboardScreenState extends State<EswariDashboardScreen> {
  int _currentIndex = 0;

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
  String get role => widget.userData['role'] ?? 'employee';
  bool get isManager => role == 'manager';

  static const Color _primary = Color(0xFF1565C0); // ASE Blue
  static const Color _accent = Color(0xFF42A5F5); // Light Blue

  late final List<Widget> _tabs = [
    EswariHomeTab(
      userData: widget.userData,
      isManager: isManager,
      onNavigateToTab: (index) => setState(() => _currentIndex = index),
    ),
    EswariCallsTab(userData: widget.userData, isManager: isManager),
    EswariLeadsTab(userData: widget.userData, isManager: isManager),
    EswariTasksTab(userData: widget.userData, isManager: isManager),
    EswariProjectsTab(userData: widget.userData, isManager: isManager),
    EswariMoreTab(userData: widget.userData, isManager: isManager),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem('Home', Icons.home_rounded, Icons.home_outlined),
    _NavItem('Calls', Icons.phone_rounded, Icons.phone_outlined),
    _NavItem('Leads', Icons.leaderboard_rounded, Icons.leaderboard_outlined),
    _NavItem('Tasks', Icons.task_alt_rounded, Icons.task_outlined),
    _NavItem('Projects', Icons.folder_rounded, Icons.folder_outlined),
    _NavItem('More', Icons.grid_view_rounded, Icons.grid_view_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _tabs),
          const AnnouncementPopup(), // Add announcement popup
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset('asserts/eswari.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Eswari Group',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                isManager ? 'Manager' : 'Employee',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _currentIndex = 5),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: _navItems.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isActive = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _primary.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? _primary : theme.colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive ? _primary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData activeIcon, icon;
  const _NavItem(this.label, this.activeIcon, this.icon);
}
