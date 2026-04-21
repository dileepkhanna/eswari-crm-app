import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/company_config.dart';
import '../login_screen.dart';
import 'ase_home_tab.dart';
import 'ase_calls_tab.dart';
import 'ase_leads_tab.dart';
import 'ase_announcements_tab.dart';
import 'ase_more_tab.dart';

class ASEDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ASEDashboardScreen({super.key, required this.userData});

  @override
  State<ASEDashboardScreen> createState() => _ASEDashboardScreenState();
}

class _ASEDashboardScreenState extends State<ASEDashboardScreen> {
  int _currentIndex = 0;
  
  // Callback functions to refresh tabs
  VoidCallback? _refreshLeadsTab;

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
  String get role => widget.userData['role'] ?? 'employee';
  bool get isManager => role == 'manager';

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent  = Color(0xFF1976D2);

  late final List<Widget> _tabs = [
    ASEHomeTab(
      userData: widget.userData,
      isManager: isManager,
      onNavigateToTab: (index) => setState(() => _currentIndex = index),
    ),
    ASECallsTab(
      userData: widget.userData,
      isManager: isManager,
      onLeadConverted: () {
        // Trigger leads tab refresh
        _refreshLeadsTab?.call();
      },
    ),
    ASELeadsTab(
      userData: widget.userData,
      isManager: isManager,
      onRefreshRequested: (callback) {
        // Store the callback so calls tab can trigger it
        _refreshLeadsTab = callback;
      },
    ),
    ASEAnnouncementsTab(userData: widget.userData),
    ASEMoreTab(userData: widget.userData, isManager: isManager),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem('Home',          Icons.home_rounded,          Icons.home_outlined),
    _NavItem('Calls',         Icons.phone_rounded,         Icons.phone_outlined),
    _NavItem('Leads',         Icons.leaderboard_rounded,   Icons.leaderboard_outlined),
    _NavItem('Announcements', Icons.campaign_rounded,      Icons.campaign_outlined),
    _NavItem('More',          Icons.grid_view_rounded,     Icons.grid_view_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Company logo instead of hamburger
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(4),
            child: Image.asset('asserts/ase_tech.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ASE Technologies',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(isManager ? 'Manager' : 'Employee',
                  style: TextStyle(fontSize: 11,
                      color: Colors.white.withOpacity(0.8))),
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
            onTap: () => setState(() => _currentIndex = 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, -2))
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
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _primary.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? _primary : Colors.grey[500],
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isActive ? _primary : Colors.grey[500],
                          )),
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
