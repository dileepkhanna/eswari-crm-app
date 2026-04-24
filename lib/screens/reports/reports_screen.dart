import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;

  const ReportsScreen({
    super.key,
    required this.userData,
    required this.isManager,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1565C0);
  
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  
  // Overview data
  int _totalLeads = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _totalLeaves = 0;
  int _approvedLeaves = 0;
  
  // Performance data
  List<Map<String, dynamic>> _teamPerformance = [];
  

  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchReportsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isASE {
    final code = (widget.userData['company']?['code'] ?? '').toString().toUpperCase();
    return code.contains('ASE');
  }

  String get _leadsEndpoint => _isASE ? '/ase-leads/?page_size=1' : '/leads/?page_size=1';
  String get _callsEndpoint => _isASE ? '/ase/customers/?page_size=1' : '/leads/?page_size=1';

  Future<void> _fetchReportsData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('📊 Reports: Starting data fetch...');

      final results = await Future.wait([
        ApiService.get(_leadsEndpoint),
        ApiService.get('/tasks/?page_size=1'),
        ApiService.get('/leaves/?page_size=1'),
        ApiService.get('/auth/users/'),
      ]);

      print('📊 Reports: Received ${results.length} responses');

      if (mounted) {
        final leadsData = results[0]['data'];
        _totalLeads = leadsData is Map ? (leadsData['count'] ?? 0) : 0;

        final tasksData = results[1]['data'];
        if (tasksData is Map) {
          _totalTasks = tasksData['count'] ?? 0;
          final completedRes = await ApiService.get('/tasks/?status=completed&page_size=1');
          _completedTasks = completedRes['data']?['count'] ?? 0;
        }

        final leavesData = results[2]['data'];
        if (leavesData is Map) {
          _totalLeaves = leavesData['count'] ?? 0;
          final approvedRes = await ApiService.get('/leaves/?status=approved&page_size=1');
          _approvedLeaves = approvedRes['data']?['count'] ?? 0;
        }

        final usersData = results[3]['data'];
        final users = usersData is List ? usersData : (usersData?['results'] ?? []);
        await _calculateTeamPerformance(users);

        setState(() => _loading = false);
      }
    } catch (e, stackTrace) {
      print('❌ Reports: Error fetching data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports data.\n\nError: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _calculateTeamPerformance(List<dynamic> users) async {
    final performance = <Map<String, dynamic>>[];

    for (final user in users) {
      try {
        final userId = user['id'];
        final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();

        final leadsRes = await ApiService.get('${_leadsEndpoint.replaceAll('?page_size=1', '')}?created_by=$userId&page_size=1');
        final tasksRes = await ApiService.get('/tasks/?assigned_to=$userId&page_size=1');
        final completedRes = await ApiService.get('/tasks/?assigned_to=$userId&status=completed&page_size=1');

        performance.add({
          'name': name,
          'leads': leadsRes['data']?['count'] ?? 0,
          'tasks': tasksRes['data']?['count'] ?? 0,
          'completed': completedRes['data']?['count'] ?? 0,
        });
      } catch (e) {
        continue;
      }
    }

    _teamPerformance = performance;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchReportsData,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildPerformanceTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReportsData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics
          const Text(
            'Key Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard(
                'Total Leads',
                _totalLeads.toString(),
                Icons.people_outline,
                Colors.blue,
              ),
              _buildMetricCard(
                'Total Tasks',
                _totalTasks.toString(),
                Icons.task_outlined,
                Colors.green,
              ),
              _buildMetricCard(
                'Completed Tasks',
                _completedTasks.toString(),
                Icons.check_circle_outline,
                Colors.purple,
              ),
              _buildMetricCard(
                'Approved Leaves',
                _approvedLeaves.toString(),
                Icons.event_available_outlined,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Insights
          const Text(
            'Quick Insights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInsightCard(
            'Task Completion Rate',
            _totalTasks > 0 
                ? '${((_completedTasks / _totalTasks) * 100).toStringAsFixed(1)}%'
                : '0%',
            Icons.trending_up,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            'Leave Approval Rate',
            _totalLeaves > 0
                ? '${((_approvedLeaves / _totalLeaves) * 100).toStringAsFixed(1)}%'
                : '0%',
            Icons.check_circle,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    if (_teamPerformance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No performance data available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teamPerformance.length,
      itemBuilder: (context, index) {
        final member = _teamPerformance[index];
        return _buildPerformanceCard(member);
      },
    );
  }



  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return ClipRect(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(Map<String, dynamic> member) {
    final name = member['name'] as String;
    final leads = member['leads'] as int;
    final tasks = member['tasks'] as int;
    final completed = member['completed'] as int;
    final completionRate = tasks > 0 ? (completed / tasks * 100).toStringAsFixed(0) : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _primary.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completionRate%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Leads', leads, Icons.people_outline, Colors.blue),
              ),
              Expanded(
                child: _buildStatItem('Tasks', tasks, Icons.task_outlined, Colors.orange),
              ),
              Expanded(
                child: _buildStatItem('Done', completed, Icons.check_circle_outline, Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
