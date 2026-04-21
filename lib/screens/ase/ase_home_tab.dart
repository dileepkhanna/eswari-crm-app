import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../utils/greeting_utils.dart';

class ASEHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final Function(int)? onNavigateToTab;
  
  const ASEHomeTab({
    super.key,
    required this.userData,
    required this.isManager,
    this.onNavigateToTab,
  });

  @override
  State<ASEHomeTab> createState() => _ASEHomeTabState();
}

class _ASEHomeTabState extends State<ASEHomeTab> {
  int _callsCount  = 0;
  int _leadsCount  = 0;
  int _pendingCalls = 0;
  int _teamCount   = 0;
  bool _loading    = true;

  static const Color _primary = Color(0xFF1565C0);
  static const Color _accent  = Color(0xFF1976D2);

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
  String get managerName => widget.userData['manager_name'] ?? '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.get('/ase/customers/?page_size=1'),
        ApiService.get('/ase-leads/?page_size=1'),
        ApiService.get('/ase/customers/?call_status=pending&page_size=1'),
      ]);
      if (mounted) {
        setState(() {
          _callsCount   = results[0]['data']?['count'] ?? 0;
          _leadsCount   = results[1]['data']?['count'] ?? 0;
          _pendingCalls = results[2]['data']?['count'] ?? 0;
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 16),
            if (!widget.isManager && managerName.isNotEmpty)
              ...[_buildManagerCard(), const SizedBox(height: 16)],
            _buildStatsGrid(),
            const SizedBox(height: 20),
            if (widget.isManager) ...[_buildTeamSection(), const SizedBox(height: 20)],
            _buildQuickActions(context),
            const SizedBox(height: 20),
            _buildRecentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isManager ? 'Manager Dashboard' : '${getGreeting()},',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                const SizedBox(height: 4),
                Text(userName.isEmpty ? 'User' : userName,
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(widget.isManager ? 'Manager' : 'Employee',
                        Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _chip('ASE Technologies', Colors.white.withOpacity(0.15)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: Image.asset('asserts/ase_tech.png', fit: BoxFit.contain),
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

  Widget _buildManagerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.supervisor_account_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reporting Manager',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(managerName, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: _primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _Stat('Total Calls',   _callsCount,   Icons.phone_rounded,          _primary),
      _Stat('Total Leads',   _leadsCount,   Icons.leaderboard_rounded,    const Color(0xFF2E7D32)),
      _Stat('Pending Calls', _pendingCalls, Icons.pending_actions_rounded, const Color(0xFFE65100)),
      if (widget.isManager)
        _Stat('Team',        _teamCount,    Icons.groups_rounded,          const Color(0xFF6A1B9A)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
            if (_loading)
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.7,
          children: stats.map((s) => _buildStatCard(s)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: s.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}', style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold, color: s.color)),
                Text(s.label, style: const TextStyle(fontSize: 10, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    final employees = widget.userData['employees_names'] as List? ?? [];
    if (employees.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Team (${employees.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: employees.map((name) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: _primary),
                  const SizedBox(width: 4),
                  Text('$name', style: const TextStyle(fontSize: 12, color: _primary)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = widget.isManager
        ? [
            _Action('New Call',   Icons.phone_callback_rounded,  _primary,                1),
            _Action('New Lead',   Icons.add_chart_rounded,       const Color(0xFF2E7D32), 2),
            _Action('Reports',    Icons.bar_chart_rounded,       const Color(0xFF6A1B9A), 4),
            _Action('Team',       Icons.groups_rounded,          const Color(0xFFE65100), 4),
          ]
        : [
            _Action('New Call',      Icons.phone_callback_rounded, _primary,                1),
            _Action('New Lead',      Icons.add_chart_rounded,      const Color(0xFF2E7D32), 2),
            _Action('Announcements', Icons.campaign_rounded,       const Color(0xFF6A1B9A), 3),
            _Action('More',          Icons.grid_view_rounded,      const Color(0xFFE65100), 4),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) => Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to the respective tab
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(a.tabIndex);
                }
              },
              child: Container(
                margin: EdgeInsets.only(right: a == actions.last ? 0 : 10),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
        const SizedBox(height: 12),
        _summaryCard(Icons.phone_missed_rounded, 'Pending Calls',
            '$_pendingCalls calls need follow-up', const Color(0xFFE65100)),
        _summaryCard(Icons.leaderboard_rounded, 'Active Leads',
            '$_leadsCount leads in pipeline', _primary),
        if (widget.isManager)
          _summaryCard(Icons.bar_chart_rounded, 'Team Performance',
              'View detailed reports', const Color(0xFF6A1B9A)),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
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
