import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/greeting_utils.dart';

class CapitalDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final Function(int)? onNavigateToTab;

  const CapitalDashboardScreen({
    super.key,
    required this.userData,
    required this.isManager,
    this.onNavigateToTab,
  });

  @override
  State<CapitalDashboardScreen> createState() => _CapitalDashboardScreenState();
}

class _CapitalDashboardScreenState extends State<CapitalDashboardScreen> {
  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent  = Color(0xFF1E88E5);

  bool _loading = true;

  int _totalCalls    = 0;
  int _pendingCalls  = 0;
  int _totalLoans    = 0;
  int _activeLoans   = 0;
  int _totalServices = 0;
  int _totalTasks    = 0;
  int _pendingTasks  = 0;
  int _urgentTasks   = 0;

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/capital/customers/?page_size=1'),
        ApiService.get('/capital/customers/?call_status=pending&page_size=1'),
        ApiService.get('/capital/loans/?page_size=1'),
        ApiService.get('/capital/loans/?status=active&page_size=1'),
        ApiService.get('/capital/services/?page_size=1'),
        ApiService.get('/capital/tasks/?page_size=1'),
        ApiService.get('/capital/tasks/?status=in_progress&page_size=1'),
        ApiService.get('/capital/tasks/?priority=urgent&page_size=1'),
      ]);
      if (mounted) {
        setState(() {
          _totalCalls    = results[0]['data']?['count'] ?? 0;
          _pendingCalls  = results[1]['data']?['count'] ?? 0;
          _totalLoans    = results[2]['data']?['count'] ?? 0;
          _activeLoans   = results[3]['data']?['count'] ?? 0;
          _totalServices = results[4]['data']?['count'] ?? 0;
          _totalTasks    = results[5]['data']?['count'] ?? 0;
          _pendingTasks  = results[6]['data']?['count'] ?? 0;
          _urgentTasks   = results[7]['data']?['count'] ?? 0;
          _loading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor    = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final bgColor      = isDark ? const Color(0xFF12121C) : Colors.grey[50]!;
    final textPrimary  = isDark ? Colors.white : Colors.black87;
    final textSecondary= isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final shadowColor  = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        color: _primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(isDark),
              const SizedBox(height: 16),
              _buildStatsGrid(isDark, cardColor, textPrimary, shadowColor),
              const SizedBox(height: 20),
              _buildQuickActions(isDark, cardColor, textPrimary, shadowColor),
              const SizedBox(height: 20),
              _buildTodaySummary(isDark, cardColor, textPrimary, textSecondary, shadowColor),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Welcome Banner ──────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1B2A), const Color(0xFF1565C0)]
              : [_primary, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(isDark ? 0.4 : 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isManager ? 'Manager Dashboard' : '${getGreeting()},',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  userName.isEmpty ? 'User' : userName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(widget.isManager ? 'Manager' : 'Executive',
                        Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _chip('Eswari Capital', Colors.white.withOpacity(0.15)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDark ? 0.1 : 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      );

  // ── Stats Grid ──────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(bool isDark, Color cardColor, Color textPrimary, Color shadowColor) {
    final stats = [
      _Stat('Total Calls',   _totalCalls,   Icons.phone_rounded,             _primary),
      _Stat('Pending Calls', _pendingCalls, Icons.pending_actions_rounded,   _primary),
      _Stat('Loans',         _totalLoans,   Icons.account_balance_rounded,   _primary),
      _Stat('Services',      _totalServices,Icons.miscellaneous_services,    _primary),
      _Stat('Total Tasks',   _totalTasks,   Icons.task_alt_rounded,          _primary),
      _Stat('Urgent Tasks',  _urgentTasks,  Icons.priority_high_rounded,     Colors.red),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Overview',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : _primary)),
            if (_loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: stats
              .map((s) => _buildStatCard(s, cardColor, textPrimary, shadowColor))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(_Stat s, Color cardColor, Color textPrimary, Color shadowColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: s.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: s.color)),
                Text(s.label,
                    style: TextStyle(fontSize: 10, color: textPrimary.withOpacity(0.5)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────────
  Widget _buildQuickActions(bool isDark, Color cardColor, Color textPrimary, Color shadowColor) {
    final actions = [
      _Action('Calls',    Icons.phone_callback_rounded,  _primary,  1),
      _Action('Loans',    Icons.account_balance_rounded, _primary,  2),
      _Action('Services', Icons.miscellaneous_services,  _primary,  3),
      _Action('Tasks',    Icons.task_alt_rounded,        _primary,  4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : _primary)),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) {
            final isLast = a == actions.last;
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(a.tabIndex),
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: a.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(a.icon, color: a.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(a.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: textPrimary.withOpacity(0.8))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Today's Summary ─────────────────────────────────────────────────────────
  Widget _buildTodaySummary(bool isDark, Color cardColor, Color textPrimary,
      Color textSecondary, Color shadowColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Summary",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : _primary)),
        const SizedBox(height: 12),
        _summaryCard(Icons.phone_missed_rounded, 'Pending Calls',
            '$_pendingCalls calls need follow-up', _primary,
            cardColor, textPrimary, textSecondary, shadowColor),
        _summaryCard(Icons.account_balance_rounded, 'Active Loans',
            '$_activeLoans loans in progress', _primary,
            cardColor, textPrimary, textSecondary, shadowColor),
        _summaryCard(Icons.task_alt_rounded, 'Pending Tasks',
            '$_pendingTasks tasks to complete', _primary,
            cardColor, textPrimary, textSecondary, shadowColor),
        if (_urgentTasks > 0)
          _summaryCard(Icons.priority_high_rounded, 'Urgent Tasks',
              '$_urgentTasks tasks need immediate attention', Colors.red,
              cardColor, textPrimary, textSecondary, shadowColor),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String title, String subtitle, Color color,
      Color cardColor, Color textPrimary, Color textSecondary, Color shadowColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSecondary),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;
  const _Action(this.label, this.icon, this.color, this.tabIndex);
}
