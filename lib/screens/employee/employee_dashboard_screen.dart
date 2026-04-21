import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../config/company_config.dart';
import '../../utils/greeting_utils.dart';
import '../../widgets/announcement_popup.dart';
import '../login_screen.dart';
import '../leaves/leaves_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EmployeeDashboardScreen({super.key, required this.userData});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentRoute = 'dashboard';
  late AnimationController _animationController;

  // Stats
  int _myLeads = 0;
  int _myTasks = 0;
  int _myLeaves = 0;
  int _reminders = 0;
  int _activeTasks = 0;
  bool _loading = true;

  // Recent data
  List<dynamic> _recentLeads = [];
  List<dynamic> _recentTasks = [];
  List<dynamic> _upcomingReminders = [];

  String get userName =>
      '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim();
  String get designation => widget.userData['designation'] ?? '';
  String get managerName => widget.userData['manager_name'] ?? '';
  String get userRole => widget.userData['role'] ?? 'employee';

  String get companyCode {
    final company = widget.userData['company'];
    if (company is Map && company['code'] != null) {
      return company['code'].toString();
    }
    final info = widget.userData['company_info'];
    if (info is Map && info['code'] != null) {
      return info['code'].toString();
    }
    for (final val in widget.userData.values) {
      if (val is Map && val['code'] != null && val['name'] != null) {
        return val['code'].toString();
      }
    }
    return '';
  }

  String get companyName {
    final company = widget.userData['company'];
    if (company is Map) return (company['name'] ?? '').toString();
    final info = widget.userData['company_info'];
    if (info is Map) return (info['name'] ?? '').toString();
    return CompanyConfig.get(companyCode).name;
  }

  bool get isASE => companyCode == 'ASE' || companyCode == 'ASE_TECH';
  bool get isEswari => companyCode == 'ESWARI' || companyCode == 'ESWARI_GROUP';
  bool get isCapital => companyCode == 'ESWARI_CAP';

  CompanyConfig get company => CompanyConfig.get(companyCode);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.forward();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        ApiService.get('${ApiConfig.leads}?page_size=5'),
        ApiService.get('${ApiConfig.tasks}?page_size=5'),
        ApiService.get('${ApiConfig.leaves}?page_size=1'),
      ]);

      if (mounted) {
        final leadsData = results[0]['data'];
        final tasksData = results[1]['data'];
        final leavesData = results[2]['data'];

        // Handle paginated responses
        final leads = leadsData is Map && leadsData.containsKey('results')
            ? leadsData['results']
            : leadsData;
        final tasks = tasksData is Map && tasksData.containsKey('results')
            ? tasksData['results']
            : tasksData;

        setState(() {
          _myLeads = leadsData is Map ? (leadsData['count'] ?? 0) : (leads?.length ?? 0);
          _myTasks = tasksData is Map ? (tasksData['count'] ?? 0) : (tasks?.length ?? 0);
          _myLeaves = leavesData is Map ? (leavesData['count'] ?? 0) : 0;

          _recentLeads = (leads as List?) ?? [];
          _recentTasks = (tasks as List?) ?? [];

          // Calculate active tasks and reminders
          _activeTasks = _recentTasks.where((t) => t['status'] != 'completed').length;
          _reminders = _recentLeads
              .where((l) =>
                  l['follow_up_date'] != null &&
                  DateTime.parse(l['follow_up_date']).isBefore(DateTime.now().add(const Duration(days: 1))))
              .length;

          _loading = false;
        });
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(String route) {
    Navigator.pop(context); // Close drawer first
    
    if (route == 'leaves') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeavesScreen(userData: widget.userData),
        ),
      );
    } else {
      setState(() => _currentRoute = route);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (_currentRoute == 'dashboard') ...[
                      _buildManagerCard(),
                      _buildStatsGrid(),
                      _buildQuickActions(),
                      _buildRecentActivity(),
                      const SizedBox(height: 80),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Announcement popup
          if (_currentRoute == 'dashboard') const AnnouncementPopup(),
        ],
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: company.primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchDashboardData,
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                company.primaryColor,
                company.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    getGreeting(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (designation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      designation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagerCard() {
    if (managerName.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: company.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: company.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reporting Manager',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  managerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _buildStatCard(
            'My Leads',
            _myLeads.toString(),
            Icons.people_outline_rounded,
            const Color(0xFF1565C0),
            0,
          ),
          _buildStatCard(
            'Active Tasks',
            _activeTasks.toString(),
            Icons.check_circle_outline_rounded,
            const Color(0xFF2E7D32),
            50,
          ),
          _buildStatCard(
            'Reminders',
            _reminders.toString(),
            Icons.notifications_active_outlined,
            const Color(0xFFF57C00),
            100,
          ),
          _buildStatCard(
            'Leave Status',
            _myLeaves > 0 ? '$_myLeaves Pending' : 'All Clear',
            Icons.event_available_outlined,
            const Color(0xFF7B1FA2),
            150,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, int delay) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                'Add Lead',
                Icons.person_add_rounded,
                const Color(0xFF1565C0),
                () {},
              ),
              _buildQuickActionButton(
                'New Task',
                Icons.add_task_rounded,
                const Color(0xFF2E7D32),
                () {},
              ),
              _buildQuickActionButton(
                'Apply Leave',
                Icons.event_rounded,
                const Color(0xFF7B1FA2),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeavesScreen(userData: widget.userData),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      children: [
        _buildRecentLeads(),
        _buildRecentTasks(),
      ],
    );
  }

  Widget _buildRecentLeads() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Leads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_recentLeads.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No leads yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentLeads.length > 3 ? 3 : _recentLeads.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final lead = _recentLeads[index];
                return _buildLeadItem(lead);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLeadItem(Map<String, dynamic> lead) {
    final name = lead['name'] ?? 'Unknown';
    final phone = lead['phone'] ?? '';
    final status = lead['status'] ?? 'new';
    final requirementType = lead['requirement_type'] ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: company.primaryColor.withOpacity(0.1),
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: company.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(phone),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(status),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTasks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_recentTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No tasks yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTasks.length > 3 ? 3 : _recentTasks.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final task = _recentTasks[index];
                return _buildTaskItem(task);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final title = task['title'] ?? 'Untitled Task';
    final status = task['status'] ?? 'pending';
    final dueDate = task['due_date'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.task_alt_rounded,
          color: _getStatusColor(status),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: dueDate != null
          ? Text('Due: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(dueDate))}')
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(status),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'pending':
        return const Color(0xFF1565C0);
      case 'in_progress':
      case 'contacted':
        return const Color(0xFFF57C00);
      case 'completed':
      case 'converted':
        return const Color(0xFF2E7D32);
      case 'lost':
      case 'cancelled':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
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
              children: [
                _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', 'dashboard'),
                _buildDrawerItem(Icons.people_rounded, 'Leads', 'leads'),
                _buildDrawerItem(Icons.task_rounded, 'Tasks', 'tasks'),
                _buildDrawerItem(Icons.event_rounded, 'Leaves', 'leaves'),
                _buildDrawerItem(Icons.campaign_rounded, 'Announcements', 'announcements'),
                _buildDrawerItem(Icons.settings_rounded, 'Settings', 'settings'),
              ],
            ),
          ),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            company.primaryColor,
            company.primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: company.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (designation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              designation,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              companyName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String route) {
    final isSelected = _currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.1),
      onTap: () => _navigate(route),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: Colors.white),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        onTap: _logout,
      ),
    );
  }

  String _routeTitle(String route) {
    switch (route) {
      case 'dashboard':
        return 'Dashboard';
      case 'leads':
        return 'My Leads';
      case 'tasks':
        return 'My Tasks';
      case 'leaves':
        return 'Leave Requests';
      case 'announcements':
        return 'Announcements';
      case 'settings':
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }
}
