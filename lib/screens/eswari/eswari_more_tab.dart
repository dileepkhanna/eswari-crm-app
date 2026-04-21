import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../settings/settings_screen.dart';
import '../leaves/leaves_screen.dart';
import '../holidays/holidays_screen.dart';
import '../birthdays/birthday_calendar_screen.dart';
import '../team/team_screen.dart';
import 'eswari_announcements_screen.dart';

class EswariMoreTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isManager;

  const EswariMoreTab({
    super.key,
    required this.userData,
    required this.isManager,
  });

  String get userName =>
      '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim();
  String get designation => userData['designation'] ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 20),
          if (isManager) ...[
            _buildManagerSection(context),
            const SizedBox(height: 16),
          ],
          _buildMenuSection(context),
          const SizedBox(height: 16),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF90CAF9), const Color(0xFF64B5F6)] // Dark mode: lighter blue gradient
            : [const Color(0xFF1565C0), const Color(0xFF42A5F5)], // Light mode: ASE Blue gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)).withOpacity(isDark ? 0.3 : 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (designation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    designation,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isManager ? '👔' : '👤',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isManager ? 'Manager' : 'Employee',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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

  Widget _buildManagerSection(BuildContext context) {
    return _section(context, 'Manager Tools', [
      _MoreItem(Icons.groups_rounded, 'My Team', const Color(0xFF2196F3), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeamScreen(userData: userData)),
        );
      }),
      _MoreItem(Icons.bar_chart_rounded, 'Reports', const Color(0xFF4CAF50), () {}),
      _MoreItem(Icons.timeline_rounded, 'Activity', const Color(0xFF9C27B0), () {}),
      _MoreItem(Icons.trending_up_rounded, 'Conversion Analytics', const Color(0xFFFF9800), () {}),
    ]);
  }

  Widget _buildMenuSection(BuildContext context) {
    return _section(context, 'General', [
      _MoreItem(Icons.campaign_rounded, 'Announcements', const Color(0xFF1565C0), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EswariAnnouncementsScreen()),
        );
      }),
      _MoreItem(Icons.beach_access_rounded, 'Holidays', const Color(0xFF2196F3), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HolidaysScreen(userData: userData)),
        );
      }),
      _MoreItem(Icons.event_available_rounded, 'My Leaves', const Color(0xFF4CAF50), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeavesScreen(userData: userData)),
        );
      }),
      _MoreItem(Icons.cake_rounded, 'Birthdays', const Color(0xFFFF9800), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BirthdayCalendarScreen(userData: userData)),
        );
      }),
      _MoreItem(Icons.settings_rounded, 'Settings', const Color(0xFF757575), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsScreen(userData: userData)),
        );
      }),
    ]);
  }

  Widget _section(BuildContext context, String title, List<_MoreItem> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    onTap: item.onTap,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 66,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                    ),
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        icon: Icon(
          Icons.logout_rounded, 
          color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
        ),
        label: Text(
          'Logout',
          style: TextStyle(
            color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
