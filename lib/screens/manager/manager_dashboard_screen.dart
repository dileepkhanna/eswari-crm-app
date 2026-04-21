import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../config/company_config.dart';
import '../../utils/greeting_utils.dart';
import '../login_screen.dart';
import '../eswari/eswari_calls_tab.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ManagerDashboardScreen({super.key, required this.userData});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentRoute = 'dashboard';

  int _leadsCount    = 0;
  int _tasksCount    = 0;
  int _pendingLeaves = 0;
  int _teamCount     = 0;
  bool _loading      = true;

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();

  String get companyCode {
    // Priority 1: company map set by login screen
    final company = widget.userData['company'];
    if (company is Map && company['code'] != null) {
      return company['code'].toString();
    }
    // Priority 2: company_info directly in userData
    final info = widget.userData['company_info'];
    if (info is Map && info['code'] != null) {
      return info['code'].toString();
    }
    // Priority 3: check all keys for any map with 'code'
    for (final val in widget.userData.values) {
      if (val is Map && val['code'] != null && val['name'] != null) {
        return val['code'].toString();
      }
    }
    debugPrint('COMPANY DEBUG: userData keys = ${widget.userData.keys.toList()}');
    debugPrint('COMPANY DEBUG: company field = ${widget.userData['company']}');
    debugPrint('COMPANY DEBUG: company_info = ${widget.userData['company_info']}');
    return '';
  }

  String get companyName {
    final company = widget.userData['company'];
    if (company is Map) return (company['name'] ?? '').toString();
    final info = widget.userData['company_info'];
    if (info is Map) return (info['name'] ?? '').toString();
    return CompanyConfig.get(companyCode).name;
  }

  bool get isASE      => companyCode == 'ASE' || companyCode == 'ASE_TECH';
  bool get isEswari   => companyCode == 'ESWARI' || companyCode == 'ESWARI_GROUP';
  bool get isCapital  => companyCode == 'ESWARI_CAP';

  CompanyConfig get company => CompanyConfig.get(companyCode);

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.get('${ApiConfig.leads}?page_size=1'),
        ApiService.get('${ApiConfig.tasks}?page_size=1'),
        ApiService.get('${ApiConfig.leaves}?status=pending&page_size=1'),
        ApiService.get(ApiConfig.users),
      ]);
      if (mounted) {
        setState(() {
          _leadsCount    = results[0]['data']?['count'] ?? 0;
          _tasksCount    = results[1]['data']?['count'] ?? 0;
          _pendingLeaves = results[2]['data']?['count'] ?? 0;
          final users    = results[3]['data'];
          _teamCount     = users is List ? users.length : (users?['count'] ?? 0);
          _loading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(String route) {
    setState(() => _currentRoute = route);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ── Menu: Common items (all companies) ────────────────
  List<_MenuItem> get _commonItems => const [
    _MenuItem('Announcements', Icons.campaign_rounded,        'announcements'),
    _MenuItem('Holidays',      Icons.beach_access_rounded,    'holidays'),
    _MenuItem('Leaves',        Icons.event_available_rounded, 'leaves'),
  ];

  // ── Menu: ASE Technologies ─────────────────────────────
  List<_MenuItem> get _aseItems => const [
    _MenuItem('Calls',    Icons.phone_rounded,       'ase-customers'),
    _MenuItem('Leads',    Icons.leaderboard_rounded, 'ase-leads'),
    _MenuItem('Reports',  Icons.bar_chart_rounded,   'ase-reports'),
    _MenuItem('Activity', Icons.timeline_rounded,    'ase-activity'),
  ];

  // ── Menu: Eswari Group ─────────────────────────────────
  List<_MenuItem> get _eswariItems => const [
    _MenuItem('Calls',                Icons.phone_rounded,          'customers'),
    _MenuItem('Leads',                Icons.leaderboard_rounded,    'leads'),
    _MenuItem('Conversion Analytics', Icons.trending_up_rounded,    'conversion-analytics'),
    _MenuItem('Tasks',                Icons.task_alt_rounded,       'tasks'),
    _MenuItem('Projects',             Icons.folder_special_rounded, 'projects'),
    _MenuItem('Reports',              Icons.bar_chart_rounded,      'reports'),
    _MenuItem('Activity',             Icons.timeline_rounded,       'activity'),
  ];

  // ── Menu: Eswari Capital ───────────────────────────────
  List<_MenuItem> get _capitalItems => const [
    _MenuItem('Calls',    Icons.phone_rounded,              'capital-customers'),
    _MenuItem('Loans',    Icons.account_balance_rounded,    'capital-loans'),
    _MenuItem('Services', Icons.miscellaneous_services_rounded, 'capital-services'),
    _MenuItem('Tasks',    Icons.task_alt_rounded,           'capital-tasks'),
    _MenuItem('Tools',    Icons.calculate_rounded,          'capital-tools'),
    _MenuItem('Reports',  Icons.bar_chart_rounded,          'capital-reports'),
    _MenuItem('Activity', Icons.timeline_rounded,           'capital-activity'),
  ];

  // ── Team items ─────────────────────────────────────────
  List<_MenuItem> get _teamItems => const [
    _MenuItem('My Team', Icons.groups_rounded, 'team'),
  ];

  List<_MenuGroup> get _menuGroups {
    final companySpecific = isASE
        ? _aseItems
        : isCapital
            ? _capitalItems
            : _eswariItems;

    final companyLabel = isASE
        ? 'ASE Technologies'
        : isCapital
            ? 'Eswari Capital'
            : 'Eswari Group';

    return [
      _MenuGroup('', [const _MenuItem('Dashboard', Icons.dashboard_rounded, 'dashboard')]),
      _MenuGroup('Common', [..._commonItems, ..._teamItems]),
      _MenuGroup(companyLabel, companySpecific),
      _MenuGroup('', [const _MenuItem('Settings', Icons.settings_rounded, 'settings')]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: company.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(_routeTitle(_currentRoute),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchStats),
        IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: company.primaryColor,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _menuGroups.map(_buildMenuGroup).toList(),
            ),
          ),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15))),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              padding: const EdgeInsets.all(6),
              child: Image.asset(company.logoAsset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName,
                      style: const TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text(userName,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(_MenuGroup group) {
    if (group.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(group.label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
        ...group.items.map(_buildDrawerItem),
      ],
    );
  }

  Widget _buildDrawerItem(_MenuItem item) {
    final isActive = _currentRoute == item.route;
    return InkWell(
      onTap: () => _navigate(item.route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(item.icon,
                color: isActive ? Colors.white : Colors.white.withOpacity(0.65), size: 20),
            const SizedBox(width: 12),
            Text(item.label,
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15)))),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    style: const TextStyle(color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text('Manager',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.white.withOpacity(0.7), size: 20),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentRoute == 'dashboard') return _buildDashboard();
    
    // Eswari Group Calls Screen
    if (_currentRoute == 'customers' && isEswari) {
      return EswariCallsTab(
        userData: widget.userData,
        isManager: true, // Manager mode - read-only with masked contact info
      );
    }
    
    return _buildPlaceholder(_routeTitle(_currentRoute));
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildTeamSection(),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 20),
            _buildModuleCards(),
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
        gradient: LinearGradient(
          colors: [company.primaryColor, company.accentColor],
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
                Text('${getGreeting()},',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 4),
                Text(userName.isEmpty ? 'Manager' : userName,
                    style: const TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip('Manager', Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    _chip(companyName, Colors.white.withOpacity(0.15)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: Image.asset(company.logoAsset, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
  );

  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('My Leads',      _leadsCount,    Icons.leaderboard_rounded,     company.primaryColor),
      _StatItem('Active Tasks',  _tasksCount,    Icons.task_alt_rounded,        const Color(0xFF2E7D32)),
      _StatItem('Pending Leaves',_pendingLeaves, Icons.pending_actions_rounded, const Color(0xFFE65100)),
      _StatItem('Team Members',  _teamCount,     Icons.groups_rounded,          const Color(0xFF6A1B9A)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: company.primaryColor)),
            if (_loading) SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: company.primaryColor)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
          children: stats.map(_buildStatCard).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatItem s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: s.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${s.value}', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.bold, color: s.color)),
              Text(s.label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: company.primaryColor)),
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
                color: company.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: company.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded, size: 14, color: company.primaryColor),
                  const SizedBox(width: 4),
                  Text('$name', style: TextStyle(fontSize: 12, color: company.primaryColor)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = isASE
        ? [
            _QuickAction('New Lead',    Icons.add_chart_rounded,      company.primaryColor, 'ase-leads'),
            _QuickAction('New Call',    Icons.phone_callback_rounded,       company.accentColor,  'ase-customers'),
            _QuickAction('Team Leaves', Icons.event_available_rounded,const Color(0xFFE65100), 'leaves'),
            _QuickAction('Reports',     Icons.bar_chart_rounded,      const Color(0xFF6A1B9A), 'ase-reports'),
          ]
        : isCapital
            ? [
                _QuickAction('New Call',    Icons.phone_callback_rounded,       company.primaryColor, 'capital-customers'),
                _QuickAction('New Loan',    Icons.account_balance_rounded,company.accentColor,  'capital-loans'),
                _QuickAction('Team Leaves', Icons.event_available_rounded,const Color(0xFFE65100), 'leaves'),
                _QuickAction('Reports',     Icons.bar_chart_rounded,      const Color(0xFF6A1B9A), 'capital-reports'),
              ]
            : [
                _QuickAction('New Lead',    Icons.add_chart_rounded,      company.primaryColor, 'leads'),
                _QuickAction('New Task',    Icons.add_task_rounded,       company.accentColor,  'tasks'),
                _QuickAction('Team Leaves', Icons.event_available_rounded,const Color(0xFFE65100), 'leaves'),
                _QuickAction('Reports',     Icons.bar_chart_rounded,      const Color(0xFF6A1B9A), 'reports'),
              ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
            color: company.primaryColor)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          children: actions.map((a) => GestureDetector(
            onTap: () => setState(() => _currentRoute = a.route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: a.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(a.icon, color: a.color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(a.label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.black87)),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildModuleCards() {
    final modules = isASE
        ? [
            _ModuleCard('Calls & Leads',    Icons.phone_rounded,       company.primaryColor, 'ase-customers'),
            _ModuleCard('Reports',          Icons.bar_chart_rounded,   company.accentColor,  'ase-reports'),
            _ModuleCard('Activity',         Icons.timeline_rounded,    const Color(0xFF6A1B9A), 'ase-activity'),
            _ModuleCard('Announcements',    Icons.campaign_rounded,    const Color(0xFFE65100), 'announcements'),
          ]
        : isCapital
            ? [
                _ModuleCard('Calls',         Icons.phone_rounded,              company.primaryColor, 'capital-customers'),
                _ModuleCard('Loans',         Icons.account_balance_rounded,    company.accentColor,  'capital-loans'),
                _ModuleCard('Services',      Icons.miscellaneous_services_rounded, const Color(0xFF2E7D32), 'capital-services'),
                _ModuleCard('Announcements', Icons.campaign_rounded,           const Color(0xFFE65100), 'announcements'),
              ]
            : [
                _ModuleCard('Leads & Calls',    Icons.leaderboard_rounded,    company.primaryColor, 'leads'),
                _ModuleCard('Tasks & Projects', Icons.task_alt_rounded,       company.accentColor,  'tasks'),
                _ModuleCard('Team & Leaves',    Icons.groups_rounded,         const Color(0xFF6A1B9A), 'team'),
                _ModuleCard('Announcements',    Icons.campaign_rounded,       const Color(0xFFE65100), 'announcements'),
              ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
            color: company.primaryColor)),
        const SizedBox(height: 12),
        ...modules.map((m) => GestureDetector(
          onTap: () => setState(() => _currentRoute = m.route),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: m.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(m.icon, color: m.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(m.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
              color: company.primaryColor)),
          const SizedBox(height: 8),
          Text('Coming soon', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  String _routeTitle(String route) {
    const t = {
      'dashboard': 'Dashboard', 'leads': 'Leads', 'tasks': 'Tasks',
      'projects': 'Projects', 'customers': 'Customers', 'team': 'My Team',
      'leaves': 'Leaves', 'reports': 'Reports', 'activity': 'Activity',
      'announcements': 'Announcements', 'holidays': 'Holidays', 'settings': 'Settings',
      'ase-customers': 'ASE Calls', 'ase-leads': 'ASE Leads',
      'ase-reports': 'ASE Reports', 'ase-activity': 'ASE Activity',
      'conversion-analytics': 'Conversion Analytics',
      'capital-customers': 'Capital Calls', 'capital-loans': 'Loans',
      'capital-services': 'Services', 'capital-tasks': 'Capital Tasks',
      'capital-tools': 'Tools', 'capital-reports': 'Capital Reports',
      'capital-activity': 'Capital Activity',
    };
    return t[route] ?? route;
  }
}

class _MenuGroup {
  final String label;
  final List<_MenuItem> items;
  const _MenuGroup(this.label, this.items);
}
class _MenuItem {
  final String label;
  final IconData icon;
  final String route;
  const _MenuItem(this.label, this.icon, this.route);
}
class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}
class _QuickAction {
  final String label, route;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}
class _ModuleCard {
  final String title, route;
  final IconData icon;
  final Color color;
  const _ModuleCard(this.title, this.icon, this.color, this.route);
}
