import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../login_screen.dart';
import '../../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminDashboardScreen({super.key, required this.userData});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
  String get userRole => widget.userData['role'] ?? 'admin';

  // ── Menu groups matching the web sidebar ──────────────
  final List<_MenuGroup> _menuGroups = const [
    _MenuGroup(label: '', items: [
      _MenuItem('Dashboard', Icons.dashboard_rounded, 'dashboard'),
    ]),
    _MenuGroup(label: 'Common', items: [
      _MenuItem('Announcements',   Icons.campaign_rounded,        'announcements'),
      _MenuItem('Birthday Calendar', Icons.cake_rounded,          'birthdays'),
      _MenuItem('Holidays',        Icons.beach_access_rounded,    'holidays'),
      _MenuItem('Leaves',          Icons.event_available_rounded, 'leaves'),
    ]),
    _MenuGroup(label: 'ASE Technologies', items: [
      _MenuItem('Employees',  Icons.people_rounded,          'ase-employees'),
      _MenuItem('Calls',      Icons.phone_rounded,           'ase-customers'),
      _MenuItem('Leads',      Icons.leaderboard_rounded,     'ase-leads'),
      _MenuItem('Reports',    Icons.bar_chart_rounded,       'ase-reports'),
      _MenuItem('Activity',   Icons.timeline_rounded,        'ase-activity'),
    ]),
    _MenuGroup(label: 'Eswari Group', items: [
      _MenuItem('Employees',            Icons.people_rounded,          'eswari-employees'),
      _MenuItem('Calls',                Icons.phone_rounded,           'customers'),
      _MenuItem('Leads',                Icons.leaderboard_rounded,     'leads'),
      _MenuItem('Conversion Analytics', Icons.trending_up_rounded,     'conversion-analytics'),
      _MenuItem('Tasks',                Icons.task_alt_rounded,        'tasks'),
      _MenuItem('Projects',             Icons.folder_special_rounded,  'projects'),
      _MenuItem('Reports',              Icons.bar_chart_rounded,       'reports'),
      _MenuItem('Activity',             Icons.timeline_rounded,        'activity'),
    ]),
    _MenuGroup(label: 'Eswari Capital', items: [
      _MenuItem('Employees', Icons.people_rounded,         'capital-employees'),
      _MenuItem('Calls',     Icons.phone_rounded,          'capital-customers'),
      _MenuItem('Loans',     Icons.account_balance_rounded,'capital-loans'),
      _MenuItem('Services',  Icons.miscellaneous_services_rounded, 'capital-services'),
      _MenuItem('Tasks',     Icons.task_alt_rounded,       'capital-tasks'),
      _MenuItem('Tools',     Icons.calculate_rounded,      'capital-tools'),
      _MenuItem('Reports',   Icons.bar_chart_rounded,      'capital-reports'),
      _MenuItem('Activity',  Icons.timeline_rounded,       'capital-activity'),
    ]),
    _MenuGroup(label: 'System Management', items: [
      _MenuItem('Employees',     Icons.badge_rounded,       'users'),
      _MenuItem('Pending Users', Icons.pending_actions_rounded, 'pending-users'),
      _MenuItem('Companies',     Icons.business_rounded,    'companies'),
      _MenuItem('Branding',      Icons.palette_rounded,     'branding'),
    ]),
    _MenuGroup(label: '', items: [
      _MenuItem('Settings', Icons.settings_rounded, 'settings'),
    ]),
  ];

  String _currentRoute = 'dashboard';

  void _navigate(String route) {
    setState(() => _currentRoute = route);
    Navigator.pop(context); // close drawer
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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

  // ── AppBar ─────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        _routeTitle(_currentRoute),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Drawer ─────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A237E),
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _menuGroups.map((group) => _buildMenuGroup(group)).toList(),
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
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_center_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eswari CRM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(_MenuGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              group.label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ...group.items.map((item) => _buildDrawerItem(item)),
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
                color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
                size: 20),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.75),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text('Admin',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded,
                color: Colors.white.withOpacity(0.7), size: 20),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────
  Widget _buildBody() {
    if (_currentRoute == 'dashboard') return _buildDashboard();
    return _buildPlaceholder(_routeTitle(_currentRoute));
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          _buildWelcomeBanner(),
          const SizedBox(height: 20),

          // Stats grid
          const Text('Overview',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 12),
          _buildStatsGrid(),
          const SizedBox(height: 20),

          // Quick actions
          const Text('Quick Actions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 20),

          // Module cards
          const Text('Modules',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 12),
          _buildModuleCards(),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
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
                Text(
                  'Welcome back,',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  userName.isEmpty ? 'Admin' : userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Administrator',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatCard('Employees',   '—', Icons.people_rounded,          const Color(0xFF3949AB)),
      _StatCard('Leads',       '—', Icons.leaderboard_rounded,     const Color(0xFF00897B)),
      _StatCard('Tasks',       '—', Icons.task_alt_rounded,        const Color(0xFFE65100)),
      _StatCard('Pending',     '—', Icons.pending_actions_rounded, const Color(0xFFC62828)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatCard s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(s.value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: s.color)),
              Text(s.label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Add Employee', Icons.person_add_rounded,    const Color(0xFF3949AB), 'users'),
      _QuickAction('New Lead',     Icons.add_chart_rounded,     const Color(0xFF00897B), 'leads'),
      _QuickAction('New Task',     Icons.add_task_rounded,      const Color(0xFFE65100), 'tasks'),
      _QuickAction('Announcement', Icons.campaign_rounded,      const Color(0xFF6A1B9A), 'announcements'),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: actions
          .map((a) => GestureDetector(
                onTap: () => setState(() => _currentRoute = a.route),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(a.icon, color: a.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(a.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black87)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildModuleCards() {
    final modules = [
      _ModuleCard('ASE Technologies', Icons.computer_rounded,       const Color(0xFF1565C0), ['Calls', 'Leads', 'Reports']),
      _ModuleCard('Eswari Group',     Icons.business_rounded,       const Color(0xFF2E7D32), ['Calls', 'Leads', 'Tasks']),
      _ModuleCard('Eswari Capital',   Icons.account_balance_rounded,const Color(0xFF6A1B9A), ['Loans', 'Services', 'Tools']),
      _ModuleCard('HR & People',      Icons.people_alt_rounded,     const Color(0xFFE65100), ['Employees', 'Leaves', 'Holidays']),
    ];

    return Column(
      children: modules.map((m) => _buildModuleCard(m)).toList(),
    );
  }

  Widget _buildModuleCard(_ModuleCard m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: m.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(m.icon, color: m.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: m.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: m.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    fontSize: 10, color: m.color)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 8),
          Text('Coming soon',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  String _routeTitle(String route) {
    const titles = {
      'dashboard':           'Dashboard',
      'announcements':       'Announcements',
      'birthdays':           'Birthday Calendar',
      'holidays':            'Holidays',
      'leaves':              'Leaves',
      'ase-employees':       'ASE Employees',
      'ase-customers':       'ASE Calls',
      'ase-leads':           'ASE Leads',
      'ase-reports':         'ASE Reports',
      'ase-activity':        'ASE Activity',
      'eswari-employees':    'Eswari Employees',
      'customers':           'Calls',
      'leads':               'Leads',
      'conversion-analytics':'Conversion Analytics',
      'tasks':               'Tasks',
      'projects':            'Projects',
      'reports':             'Reports',
      'activity':            'Activity',
      'capital-employees':   'Capital Employees',
      'capital-customers':   'Capital Calls',
      'capital-loans':       'Loans',
      'capital-services':    'Services',
      'capital-tasks':       'Capital Tasks',
      'capital-tools':       'Tools',
      'capital-reports':     'Capital Reports',
      'capital-activity':    'Capital Activity',
      'users':               'Employees',
      'pending-users':       'Pending Users',
      'companies':           'Companies',
      'branding':            'Branding',
      'settings':            'Settings',
    };
    return titles[route] ?? route;
  }
}

// ── Data models ────────────────────────────────────────────
class _MenuGroup {
  final String label;
  final List<_MenuItem> items;
  const _MenuGroup({required this.label, required this.items});
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String route;
  const _MenuItem(this.label, this.icon, this.route);
}

class _StatCard {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
}

class _QuickAction {
  final String label, route;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}

class _ModuleCard {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> tags;
  const _ModuleCard(this.title, this.icon, this.color, this.tags);
}
