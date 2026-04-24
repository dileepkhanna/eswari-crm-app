import 'package:flutter/material.dart';
import 'capital_dashboard_screen.dart';
import 'capital_more_tab.dart';
import 'capital_calls_screen.dart';
import 'capital_loans_screen.dart';
import 'capital_services_screen.dart';
import 'capital_tasks_screen.dart';

class CapitalMainScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;

  const CapitalMainScreen({
    super.key,
    required this.userData,
    required this.isManager,
  });

  @override
  State<CapitalMainScreen> createState() => _CapitalMainScreenState();
}

class _CapitalMainScreenState extends State<CapitalMainScreen> {
  int _currentIndex = 0;
  static const Color _primary = Color(0xFF1565C0);
  final _loansKey = GlobalKey<State>();

  String get _userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();

  AppBar _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(6),
            child: Image.asset('asserts/eswari.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Eswari Capital',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(widget.isManager ? 'Manager' : 'Executive',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _currentIndex = 5),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home
          CapitalDashboardScreen(
            userData: widget.userData,
            isManager: widget.isManager,
            onNavigateToTab: (index) => setState(() => _currentIndex = index),
          ),
          // Calls
          CapitalCallsScreen(isManager: widget.isManager, userData: widget.userData),
          // Loans — use key so it rebuilds when navigated to
          CapitalLoansScreen(
            key: ValueKey('loans_$_currentIndex'),
            isManager: widget.isManager,
            userData: widget.userData,
          ),
          // Services
          CapitalServicesScreen(
            key: ValueKey('services_$_currentIndex'),
            isManager: widget.isManager,
            userData: widget.userData,
          ),
          // Tasks
          CapitalTasksScreen(
            key: ValueKey('tasks_$_currentIndex'),
            isManager: widget.isManager,
            userData: widget.userData,
          ),
          // More
          CapitalMoreTab(
            userData: widget.userData,
            isManager: widget.isManager,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final items = [
      ('Home',     Icons.home_rounded,                Icons.home_outlined),
      ('Calls',    Icons.phone_rounded,               Icons.phone_outlined),
      ('Loans',    Icons.account_balance_rounded,     Icons.account_balance_outlined),
      ('Services', Icons.miscellaneous_services,      Icons.miscellaneous_services_outlined),
      ('Tasks',    Icons.task_alt_rounded,            Icons.task_alt_outlined),
      ('More',     Icons.grid_view_rounded,           Icons.grid_view_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.asMap().entries.map((e) {
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? _primary.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isActive ? item.$2 : item.$3,
                          color: isActive ? _primary : Colors.grey[500],
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(item.$1,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildPlaceholderTab(String title, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121C) : Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text('Coming Soon',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
