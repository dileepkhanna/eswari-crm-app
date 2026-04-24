import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ActivityScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;

  const ActivityScreen({
    super.key,
    required this.userData,
    required this.isManager,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF1565C0);
  
  bool _loading = true;
  String? _error;
  
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _users = [];
  
  // Filters
  String _searchQuery = '';
  String _selectedUserId = 'all';
  String _selectedModule = 'all';
  String _selectedAction = 'all';
  DateTimeRange? _dateRange;
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Module icons
  final Map<String, IconData> _moduleIcons = {
    'leads': Icons.trending_up,
    'customers': Icons.people,
    'tasks': Icons.task_alt,
    'projects': Icons.business,
    'leaves': Icons.event_available,
    'users': Icons.person,
    'reports': Icons.bar_chart,
    'announcements': Icons.campaign,
  };
  
  // Action colors
  final Map<String, Color> _actionColors = {
    'created': Colors.green,
    'create': Colors.green,
    'updated': Colors.blue,
    'update': Colors.blue,
    'deleted': Colors.red,
    'delete': Colors.red,
    'converted': Colors.purple,
    'convert': Colors.purple,
    'approved': Colors.green,
    'approve': Colors.green,
    'rejected': Colors.red,
    'reject': Colors.red,
    'viewed': Colors.grey,
    'view': Colors.grey,
    'assigned': Colors.orange,
    'assign': Colors.orange,
    'completed': Colors.green,
    'complete': Colors.green,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchActivityData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivityData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // Fetch activity logs
      final activityRes = await ApiService.get('/activity-logs/');
      final activityData = activityRes['data'];
      
      List activities;
      if (activityData is Map && activityData.containsKey('results')) {
        activities = activityData['results'] as List;
      } else if (activityData is List) {
        activities = activityData;
      } else {
        activities = [];
      }
      
      _activities = activities.map((a) {
        return {
          'id': (a['id'] ?? 0).toString(),
          'user_id': (a['user'] ?? 0).toString(),
          'user_name': (a['user_name'] ?? 'Unknown').toString(),
          'user_role': (a['user_role'] ?? '').toString(),
          'module': (a['module'] ?? 'other').toString(),
          'action': (a['action'] ?? '').toString(),
          'details': (a['details'] ?? '').toString(),
          'created_at': (a['created_at'] ?? DateTime.now().toIso8601String()).toString(),
        };
      }).where((a) => (a['created_at'] as String).isNotEmpty).toList();
      
      // Fetch users for filter
      final usersRes = await ApiService.get('/auth/users/');
      final usersData = usersRes['data'];
      
      List users;
      if (usersData is Map && usersData.containsKey('results')) {
        users = usersData['results'] as List;
      } else if (usersData is List) {
        users = usersData;
      } else {
        users = [];
      }
      
      _users = users.map((u) {
        final firstName = (u['first_name'] ?? '').toString();
        final lastName = (u['last_name'] ?? '').toString();
        final name = '$firstName $lastName'.trim();
        
        return {
          'id': (u['id'] ?? 0).toString(),
          'name': name.isEmpty ? (u['username'] ?? 'Unknown').toString() : name,
          'role': (u['role'] ?? '').toString(),
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load activity data: ${e.toString()}';
        });
      }
    }
  }
  
  List<Map<String, dynamic>> get _filteredActivities {
    return _activities.where((activity) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          activity['user_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          activity['details'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      // User filter
      final matchesUser = _selectedUserId == 'all' || activity['user_id'] == _selectedUserId;
      
      // Module filter
      final matchesModule = _selectedModule == 'all' || activity['module'] == _selectedModule;
      
      // Action filter
      final matchesAction = _selectedAction == 'all' || activity['action'] == _selectedAction;
      
      // Date filter
      bool matchesDate = true;
      if (_dateRange != null) {
        try {
          final activityDate = DateTime.parse(activity['created_at']);
          matchesDate = activityDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                       activityDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        } catch (_) {
          matchesDate = true;
        }
      }
      
      return matchesSearch && matchesUser && matchesModule && matchesAction && matchesDate;
    }).toList();
  }
  
  List<Map<String, dynamic>> _getActivitiesByModule(String module) {
    return _filteredActivities.where((a) => a['module'] == module).toList();
  }
  
  Set<String> get _uniqueActions {
    return _activities.map((a) => a['action'].toString()).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Activity Log', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchActivityData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'All (${_filteredActivities.length})'),
            Tab(text: 'Leads (${_getActivitiesByModule('leads').length})'),
            Tab(text: 'Customers (${_getActivitiesByModule('customers').length})'),
            Tab(text: 'Tasks (${_getActivitiesByModule('tasks').length})'),
            Tab(text: 'Leaves (${_getActivitiesByModule('leaves').length})'),
            Tab(text: 'Other (${_filteredActivities.where((a) => !['leads', 'customers', 'tasks', 'leaves'].contains(a['module'])).length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildFiltersSection(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActivityList(_filteredActivities),
                          _buildActivityList(_getActivitiesByModule('leads')),
                          _buildActivityList(_getActivitiesByModule('customers')),
                          _buildActivityList(_getActivitiesByModule('tasks')),
                          _buildActivityList(_getActivitiesByModule('leaves')),
                          _buildActivityList(_filteredActivities.where((a) => 
                            !['leads', 'customers', 'tasks', 'leaves'].contains(a['module'])
                          ).toList()),
                        ],
                      ),
                    ),
                  ],
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
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchActivityData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
  
  Widget _buildFiltersSection() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or details...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  'User',
                  _selectedUserId == 'all' ? 'All' : _users.firstWhere(
                    (u) => u['id'] == _selectedUserId,
                    orElse: () => {'name': 'Unknown'},
                  )['name'],
                  Icons.person,
                  () => _showUserFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Module',
                  _selectedModule == 'all' ? 'All' : _selectedModule,
                  Icons.category,
                  () => _showModuleFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Action',
                  _selectedAction == 'all' ? 'All' : _selectedAction,
                  Icons.bolt,
                  () => _showActionFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Date',
                  _dateRange == null ? 'All time' : 'Custom',
                  Icons.calendar_today,
                  () => _showDateRangePicker(),
                ),
                const SizedBox(width: 8),
                if (_selectedUserId != 'all' || _selectedModule != 'all' || 
                    _selectedAction != 'all' || _dateRange != null)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'Showing ${_filteredActivities.length} of ${_activities.length} activities',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _primary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: _primary),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityList(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No activities found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchActivityData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          return _buildActivityCard(activities[index]);
        },
      ),
    );
  }
  
  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final module = activity['module'] as String;
    final action = activity['action'] as String;
    final icon = _moduleIcons[module] ?? Icons.info;
    final actionColor = _actionColors[action] ?? Colors.grey;
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(activity['created_at']);
    } catch (_) {
      createdAt = DateTime.now();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: _primary),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User and action
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: activity['user_name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: action,
                          style: TextStyle(
                            color: actionColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: activity['details']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Metadata
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMetaChip(
                        _formatTimeAgo(createdAt),
                        Icons.access_time,
                        Colors.grey,
                      ),
                      _buildMetaChip(
                        DateFormat('MMM dd, HH:mm').format(createdAt),
                        Icons.calendar_today,
                        Colors.grey,
                      ),
                      _buildMetaChip(
                        module,
                        Icons.category,
                        Colors.blue,
                      ),
                      _buildMetaChip(
                        activity['user_role'],
                        Icons.person,
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetaChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM dd').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  void _showUserFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('All Users'),
              trailing: _selectedUserId == 'all' ? const Icon(Icons.check, color: _primary) : null,
              onTap: () {
                setState(() => _selectedUserId = 'all');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.1),
                      child: Text(
                        user['name'][0].toUpperCase(),
                        style: const TextStyle(color: _primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['role'], style: const TextStyle(fontSize: 12)),
                    trailing: _selectedUserId == user['id'] ? const Icon(Icons.check, color: _primary) : null,
                    onTap: () {
                      setState(() => _selectedUserId = user['id']);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showModuleFilter() {
    final modules = ['all', 'leads', 'customers', 'tasks', 'leaves', 'projects', 'users', 'reports'];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Module',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...modules.map((module) {
              final icon = module == 'all' ? Icons.apps : (_moduleIcons[module] ?? Icons.info);
              return ListTile(
                leading: Icon(icon),
                title: Text(module == 'all' ? 'All Modules' : module[0].toUpperCase() + module.substring(1)),
                trailing: _selectedModule == module ? const Icon(Icons.check, color: _primary) : null,
                onTap: () {
                  setState(() => _selectedModule = module);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  void _showActionFilter() {
    final actions = ['all', ..._uniqueActions];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Action',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return ListTile(
                    leading: Icon(Icons.bolt, color: _actionColors[action] ?? Colors.grey),
                    title: Text(action == 'all' ? 'All Actions' : action[0].toUpperCase() + action.substring(1)),
                    trailing: _selectedAction == action ? const Icon(Icons.check, color: _primary) : null,
                    onTap: () {
                      setState(() => _selectedAction = action);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _selectedUserId = 'all';
      _selectedModule = 'all';
      _selectedAction = 'all';
      _dateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }
}
