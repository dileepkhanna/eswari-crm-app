import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../settings/settings_screen.dart';
import '../leaves/leaves_screen.dart';
import '../holidays/holidays_screen.dart';
import '../birthdays/birthday_calendar_screen.dart';
import '../reports/reports_screen.dart';
import '../activity/activity_screen.dart';

class ASEMoreTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  const ASEMoreTab({super.key, required this.userData, required this.isManager});

  static const Color _primary = Color(0xFF1565C0);

  String get userName =>
      '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim();
  String get designation => userData['designation'] ?? '';
  String get phone => userData['phone'] ?? '';
  String get email => userData['email'] ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileCard(),
            const SizedBox(height: 20),
            if (isManager) ...[_buildManagerSection(context), const SizedBox(height: 16)],
            _buildMenuSection(context),
            const SizedBox(height: 16),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white,
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
                if (designation.isNotEmpty)
                  Text(designation, style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(isManager ? 'Manager' : 'Employee',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerSection(BuildContext context) {
    return _section('Manager Tools', [
      _MoreItem(Icons.bar_chart_rounded,    'Reports',    const Color(0xFF2E7D32), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReportsScreen(userData: userData, isManager: isManager)));
      }),
      _MoreItem(Icons.timeline_rounded,     'Activity',   const Color(0xFF6A1B9A), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ActivityScreen(userData: userData, isManager: isManager)));
      }),
      _MoreItem(Icons.pending_actions_rounded,'Leaves',   const Color(0xFFE65100), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeavesScreen(userData: userData)));
      }),
    ], context);
  }

  Widget _buildMenuSection(BuildContext context) {
    return _section('General', [
      _MoreItem(Icons.beach_access_rounded, 'Holidays',   const Color(0xFF1565C0), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => HolidaysScreen(userData: userData)));
      }),
      _MoreItem(Icons.event_available_rounded,'My Leaves',const Color(0xFF2E7D32), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeavesScreen(userData: userData)));
      }),
      _MoreItem(Icons.cake_rounded,         'Birthdays',  const Color(0xFFE65100), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => BirthdayCalendarScreen(userData: userData)));
      }),
      _MoreItem(Icons.settings_rounded,     'Settings',   const Color(0xFF757575), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => SettingsScreen(userData: userData)));
      }),
    ], context);
  }

  Widget _section(String title, List<_MoreItem> items, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: item.color.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(item.label,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface)),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    onTap: item.onTap,
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 66,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.1)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          }
        },
        icon: Icon(Icons.logout_rounded,
            color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828)),
        label: Text('Logout',
            style: TextStyle(
                color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MoreItem(this.icon, this.label, this.color, this.onTap);
}
