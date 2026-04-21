import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';

class EswariTasksTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final Function(VoidCallback)? onRefreshRequested;
  
  const EswariTasksTab({
    super.key,
    required this.userData,
    required this.isManager,
    this.onRefreshRequested,
  });

  @override
  State<EswariTasksTab> createState() => _EswariTasksTabState();
}

class _EswariTasksTabState extends State<EswariTasksTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _tasks = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Filters
  String _statusFilter = '';
  String _priorityFilter = '';
  String _projectFilter = '';
  String _assignedToFilter = '';
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  
  // Sorting
  String _sortBy = '-created_at'; // Default: newest first
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 50;
  
  // Available data for filters
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _users = [];

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    // Register refresh callback with parent
    widget.onRefreshRequested?.call(fetchTasks);
    fetchTasks();
    _fetchProjects();
    _fetchUsers();
  }

  final _statusColors = const {
    'in_progress':           Color(0xFF1976D2),
    'site_visit':            Color(0xFFF57C00),
    'family_visit':          Color(0xFF7B1FA2),
    'perfect_family_visit':  Color(0xFF388E3C),
    'completed':             Color(0xFF2E7D32),
    'rejected':              Color(0xFF757575),
  };

  final _statusLabels = const {
    'in_progress':           'In Progress',
    'site_visit':            'Site Visit',
    'family_visit':          'Family Visit',
    'perfect_family_visit':  'Perfect Family Visit',
    'completed':             'Completed',
    'rejected':              'Rejected',
  };
  
  final _priorityColors = const {
    'low':    Color(0xFF4CAF50),
    'medium': Color(0xFFFFA726),
    'high':   Color(0xFFFF5722),
    'urgent': Color(0xFFD32F2F),
  };
  
  final _priorityLabels = const {
    'low':    'Low',
    'medium': 'Medium',
    'high':   'High',
    'urgent': 'Urgent',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _fetchProjects() async {
    try {
      final res = await ApiService.get('/projects/');
      if (mounted && res['success'] == true) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
        });
      }
    } catch (_) {}
  }
  
  Future<void> _fetchUsers() async {
    try {
      final res = await ApiService.get('/accounts/users/');
      if (mounted && res['success'] == true) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
        });
      }
    } catch (_) {}
  }

  Future<void> fetchTasks() async {
    setState(() => _loading = true);
    try {
      String url = '/tasks/?page=$_currentPage&page_size=$_pageSize';
      
      // Apply filters
      if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
      if (_priorityFilter.isNotEmpty) url += '&priority=$_priorityFilter';
      if (_projectFilter.isNotEmpty) url += '&project=$_projectFilter';
      if (_assignedToFilter.isNotEmpty) url += '&assigned_to=$_assignedToFilter';
      if (_search.isNotEmpty) url += '&search=$_search';
      
      // Apply date range filter
      if (_startDateFilter != null) {
        url += '&created_at__gte=${DateFormat('yyyy-MM-dd').format(_startDateFilter!)}';
      }
      if (_endDateFilter != null) {
        url += '&created_at__lte=${DateFormat('yyyy-MM-dd').format(_endDateFilter!)}';
      }
      
      // Apply sorting
      if (_sortBy.isNotEmpty) url += '&ordering=$_sortBy';

      final res = await ApiService.get(url);
      
      if (mounted) {
        final data = res['data'];
        final tasks = data?['results'] ?? [];
        
        setState(() {
          _tasks = tasks;
          _totalCount = data?['count'] ?? 0;
          _totalPages = (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = '';
      _priorityFilter = '';
      _projectFilter = '';
      _assignedToFilter = '';
      _startDateFilter = null;
      _endDateFilter = null;
      _search = '';
      _searchCtrl.clear();
      _currentPage = 1;
    });
    fetchTasks();
  }
  
  bool get _hasActiveFilters {
    return _statusFilter.isNotEmpty ||
        _priorityFilter.isNotEmpty ||
        _projectFilter.isNotEmpty ||
        _assignedToFilter.isNotEmpty ||
        _startDateFilter != null ||
        _endDateFilter != null ||
        _search.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Column(
      children: [
        _buildSearchBar(),
        if (_hasActiveFilters) _buildActiveFilters(),
        _buildActionRow(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _tasks.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: fetchTasks,
                      color: _primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tasks.length,
                        itemBuilder: (_, i) => _buildTaskCard(_tasks[i]),
                      ),
                    ),
        ),
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          fetchTasks();
                        })
                    : null,
                filled: true,
                fillColor: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                if (v.isEmpty) fetchTasks();
              },
              onSubmitted: (_) => fetchTasks(),
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          Container(
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.sort_rounded, color: _primary),
              onPressed: _showSortSheet,
              tooltip: 'Sort',
            ),
          ),
          const SizedBox(width: 8),
          // Filter button with badge
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? _primary : (isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : const Color(0xFFF5F6FA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _hasActiveFilters ? Colors.white : _primary,
                  ),
                  onPressed: _showFilterSheet,
                ),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskFilterSheet(
        statusFilter: _statusFilter,
        priorityFilter: _priorityFilter,
        projectFilter: _projectFilter,
        assignedToFilter: _assignedToFilter,
        startDateFilter: _startDateFilter,
        endDateFilter: _endDateFilter,
        projects: _projects,
        users: _users,
        onApply: (status, priority, project, assignedTo, startDate, endDate) {
          setState(() {
            _statusFilter = status;
            _priorityFilter = priority;
            _projectFilter = project;
            _assignedToFilter = assignedTo;
            _startDateFilter = startDate;
            _endDateFilter = endDate;
            _currentPage = 1;
          });
          fetchTasks();
        },
        onClear: _clearFilters,
      ),
    );
  }
  
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SortSheet(
        currentSort: _sortBy,
        onApply: (sortBy) {
          setState(() {
            _sortBy = sortBy;
            _currentPage = 1;
          });
          fetchTasks();
        },
      ),
    );
  }

  Widget _buildActiveFilters() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final filters = <String>[];
    if (_statusFilter.isNotEmpty) filters.add(_statusLabels[_statusFilter] ?? _statusFilter);
    if (_priorityFilter.isNotEmpty) filters.add(_priorityLabels[_priorityFilter] ?? _priorityFilter);
    if (_projectFilter.isNotEmpty) {
      final project = _projects.firstWhere(
        (p) => p['id'].toString() == _projectFilter,
        orElse: () => {'name': 'Project'},
      );
      filters.add(project['name'] ?? 'Project');
    }
    if (_assignedToFilter.isNotEmpty) {
      final user = _users.firstWhere(
        (u) => u['id'].toString() == _assignedToFilter,
        orElse: () => {'username': 'User'},
      );
      filters.add(user['username'] ?? 'User');
    }
    if (_startDateFilter != null || _endDateFilter != null) {
      String dateRange = '';
      if (_startDateFilter != null && _endDateFilter != null) {
        dateRange = '${DateFormat('MMM d').format(_startDateFilter!)} - ${DateFormat('MMM d').format(_endDateFilter!)}';
      } else if (_startDateFilter != null) {
        dateRange = 'From ${DateFormat('MMM d').format(_startDateFilter!)}';
      } else if (_endDateFilter != null) {
        dateRange = 'Until ${DateFormat('MMM d').format(_endDateFilter!)}';
      }
      if (dateRange.isNotEmpty) filters.add(dateRange);
    }
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: filters.map((f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Text(
            f,
            style: const TextStyle(fontSize: 11, color: _primary, fontWeight: FontWeight.w600),
          ),
        )).toList(),
      ),
    );
  }
  
  Widget _buildActionRow() {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('Export ($_totalCount)', style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareExcel,
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Share', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPagination() {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _pageSize + 1}–${(_currentPage * _pageSize).clamp(0, _totalCount)} of $_totalCount tasks',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.first_page_rounded, color: theme.colorScheme.onSurface),
                onPressed: _currentPage > 1 ? () {
                  setState(() => _currentPage = 1);
                  fetchTasks();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurface),
                onPressed: _currentPage > 1 ? () {
                  setState(() => _currentPage--);
                  fetchTasks();
                } : null,
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface),
                onPressed: _currentPage < _totalPages ? () {
                  setState(() => _currentPage++);
                  fetchTasks();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: Icon(Icons.last_page_rounded, color: theme.colorScheme.onSurface),
                onPressed: _currentPage < _totalPages ? () {
                  setState(() => _currentPage = _totalPages);
                  fetchTasks();
                } : null,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final status = task['status'] ?? 'in_progress';
    final priority = task['priority'] ?? 'medium';
    final statusColor = _statusColors[status] ?? _primary;
    final priorityColor = _priorityColors[priority] ?? Colors.grey;
    
    final lead = task['lead_detail'] ?? {};
    final leadName = lead['name'] ?? 'Unknown Lead';
    final leadPhone = widget.isManager ? _maskPhone(lead['phone'] ?? '') : (lead['phone'] ?? '');
    
    final project = task['project_detail'];
    final projectName = project != null ? project['name'] ?? 'No Project' : 'No Project';
    
    final assignedTo = task['assigned_to_detail'];
    final assignedToName = assignedTo != null ? assignedTo['username'] ?? '' : '';
    
    final dueDate = task['due_date'];
    final createdAt = task['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.task_alt_rounded, color: statusColor, size: 22),
        ),
        title: Text(
          leadName,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadPhone.isNotEmpty)
              Text(leadPhone, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    projectName,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (assignedToName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned: $assignedToName',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if (dueDate != null && dueDate.toString().isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 12, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Visit: ${dueDate.toString().split('T')[0]}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: priorityColor.withOpacity(isDark ? 0.4 : 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 10, color: priorityColor),
                      const SizedBox(width: 3),
                      Text(
                        _priorityLabels[priority] ?? priority,
                        style: TextStyle(
                          fontSize: 10,
                          color: priorityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabels[status] ?? status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showTaskDetail(task),
      ),
    );
  }
  
  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final start = phone.substring(0, 2);
    final end = phone.substring(phone.length - 2);
    return '$start${'*' * (phone.length - 4)}$end';
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // Export to Excel
  Future<void> _exportToExcel() async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required to export files'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Exporting tasks...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Fetch all tasks (no pagination)
      final res = await ApiService.get('/tasks/?page_size=10000');
      if (res['success'] != true) throw Exception('Failed to fetch tasks');
      
      final allTasks = List<Map<String, dynamic>>.from(res['data']?['results'] ?? []);
      
      if (allTasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tasks to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final excel = xl.Excel.createExcel();
      final sheet = excel['Tasks'];

      // Headers with styling
      final headers = [
        'Lead Name', 'Phone', 'Email', 'Status', 'Priority', 'Project',
        'Assigned To', 'Visit Date', 'Created At', 'Updated At'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }

      // Data rows
      for (int i = 0; i < allTasks.length; i++) {
        final task = allTasks[i];
        final lead = task['lead_detail'] ?? {};
        final project = task['project_detail'];
        final assignedTo = task['assigned_to_detail'];
        
        final row = [
          lead['name'] ?? '',
          widget.isManager ? _maskPhone(lead['phone'] ?? '') : (lead['phone'] ?? ''),
          lead['email'] ?? '',
          _statusLabels[task['status']] ?? task['status'] ?? '',
          _priorityLabels[task['priority']] ?? task['priority'] ?? '',
          project != null ? project['name'] ?? '' : '',
          assignedTo != null ? assignedTo['username'] ?? '' : '',
          task['due_date']?.toString().split('T')[0] ?? '',
          task['created_at']?.toString().split('T')[0] ?? '',
          task['updated_at']?.toString().split('T')[0] ?? '',
        ];
        
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
      }

      // Save file
      Directory? dir;
      if (Platform.isAndroid) {
        // Try Downloads folder first
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          // Fallback to app directory
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_tasks_$timestamp.xlsx';
      final filePath = '${dir!.path}/$fileName';
      
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Exported ${allTasks.length} tasks to ${Platform.isAndroid ? "Downloads" : "Documents"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(filePath, fileName),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Share Excel file
  Future<void> _shareExcel() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Preparing file to share...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Fetch all tasks
      final res = await ApiService.get('/tasks/?page_size=10000');
      if (res['success'] != true) throw Exception('Failed to fetch tasks');
      
      final allTasks = List<Map<String, dynamic>>.from(res['data']?['results'] ?? []);
      
      if (allTasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tasks to share'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final excel = xl.Excel.createExcel();
      final sheet = excel['Tasks'];

      // Headers
      final headers = [
        'Lead Name', 'Phone', 'Email', 'Status', 'Priority', 'Project',
        'Assigned To', 'Visit Date', 'Created At', 'Updated At'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }

      // Data rows
      for (int i = 0; i < allTasks.length; i++) {
        final task = allTasks[i];
        final lead = task['lead_detail'] ?? {};
        final project = task['project_detail'];
        final assignedTo = task['assigned_to_detail'];
        
        final row = [
          lead['name'] ?? '',
          widget.isManager ? _maskPhone(lead['phone'] ?? '') : (lead['phone'] ?? ''),
          lead['email'] ?? '',
          _statusLabels[task['status']] ?? task['status'] ?? '',
          _priorityLabels[task['priority']] ?? task['priority'] ?? '',
          project != null ? project['name'] ?? '' : '',
          assignedTo != null ? assignedTo['username'] ?? '' : '',
          task['due_date']?.toString().split('T')[0] ?? '',
          task['created_at']?.toString().split('T')[0] ?? '',
          task['updated_at']?.toString().split('T')[0] ?? '',
        ];
        
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_tasks_$timestamp.xlsx';
      final filePath = '${tempDir.path}/$fileName';
      
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Tasks Export',
        text: 'Eswari Group Tasks - ${allTasks.length} tasks exported on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Share existing file
  Future<void> _shareFile(String filePath, String fileName) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Tasks Export',
        text: 'Eswari Group Tasks exported on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TaskDetailSheet(
        task: task,
        isManager: widget.isManager,
        projects: _projects,
        onEdit: () {
          Navigator.pop(context);
          _showEditTaskForm(task);
        },
        onStatusChange: (newStatus) async {
          try {
            final res = await ApiService.request(
              endpoint: '/tasks/${task['id']}/',
              method: 'PATCH',
              body: {'status': newStatus},
            );
            
            if (res['success'] == true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Status updated successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              fetchTasks();
            } else {
              throw Exception('Failed to update status');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditTaskForm(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (_) => _EditTaskDialog(
        task: task,
        projects: _projects,
        onSave: () {
          Navigator.pop(context);
          fetchTasks();
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Filter Sheet Widget
// ══════════════════════════════════════════════════════════════════════════════

class _TaskFilterSheet extends StatefulWidget {
  final String statusFilter;
  final String priorityFilter;
  final String projectFilter;
  final String assignedToFilter;
  final DateTime? startDateFilter;
  final DateTime? endDateFilter;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> users;
  final Function(String, String, String, String, DateTime?, DateTime?) onApply;
  final VoidCallback onClear;

  const _TaskFilterSheet({
    required this.statusFilter,
    required this.priorityFilter,
    required this.projectFilter,
    required this.assignedToFilter,
    required this.startDateFilter,
    required this.endDateFilter,
    required this.projects,
    required this.users,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<_TaskFilterSheet> {
  late String _status;
  late String _priority;
  late String _project;
  late String _assignedTo;
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _priority = widget.priorityFilter;
    _project = widget.projectFilter;
    _assignedTo = widget.assignedToFilter;
    _startDate = widget.startDateFilter;
    _endDate = widget.endDateFilter;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Tasks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  // Status Filter
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('All', _status == '', () => setState(() => _status = '')),
                      _buildFilterChip('In Progress', _status == 'in_progress', () => setState(() => _status = 'in_progress')),
                      _buildFilterChip('Site Visit', _status == 'site_visit', () => setState(() => _status = 'site_visit')),
                      _buildFilterChip('Family Visit', _status == 'family_visit', () => setState(() => _status = 'family_visit')),
                      _buildFilterChip('Perfect Family Visit', _status == 'perfect_family_visit', () => setState(() => _status = 'perfect_family_visit')),
                      _buildFilterChip('Completed', _status == 'completed', () => setState(() => _status = 'completed')),
                      _buildFilterChip('Rejected', _status == 'rejected', () => setState(() => _status = 'rejected')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Priority Filter
                  const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('All', _priority == '', () => setState(() => _priority = '')),
                      _buildFilterChip('Low', _priority == 'low', () => setState(() => _priority = 'low')),
                      _buildFilterChip('Medium', _priority == 'medium', () => setState(() => _priority = 'medium')),
                      _buildFilterChip('High', _priority == 'high', () => setState(() => _priority = 'high')),
                      _buildFilterChip('Urgent', _priority == 'urgent', () => setState(() => _priority = 'urgent')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Project Filter
                  const Text('Project', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _project.isEmpty ? null : _project,
                    decoration: const InputDecoration(
                      hintText: 'Select project',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Projects')),
                      ...widget.projects.map((p) => DropdownMenuItem(
                        value: p['id'].toString(),
                        child: Text(p['name'] ?? ''),
                      )),
                    ],
                    onChanged: (v) => setState(() => _project = v ?? ''),
                  ),
                  const SizedBox(height: 20),
                  
                  // Assigned To Filter
                  const Text('Assigned To', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _assignedTo.isEmpty ? null : _assignedTo,
                    decoration: const InputDecoration(
                      hintText: 'Select user',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Users')),
                      ...widget.users.map((u) => DropdownMenuItem(
                        value: u['id'].toString(),
                        child: Text(u['username'] ?? ''),
                      )),
                    ],
                    onChanged: (v) => setState(() => _assignedTo = v ?? ''),
                  ),
                  const SizedBox(height: 20),
                  
                  // Date Range Filter
                  const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _startDate = date);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            _startDate != null
                                ? DateFormat('MMM d, yyyy').format(_startDate!)
                                : 'Start Date',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _endDate = date);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            _endDate != null
                                ? DateFormat('MMM d, yyyy').format(_endDate!)
                                : 'End Date',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('Clear Dates'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_status, _priority, _project, _assignedTo, _startDate, _endDate);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF1565C0).withOpacity(0.2),
      checkmarkColor: const Color(0xFF1565C0),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1565C0) : Colors.grey[700],
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sort Sheet Widget
// ══════════════════════════════════════════════════════════════════════════════

class _SortSheet extends StatelessWidget {
  final String currentSort;
  final Function(String) onApply;

  const _SortSheet({required this.currentSort, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort By',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSortOption(context, 'Newest First', '-created_at'),
          _buildSortOption(context, 'Oldest First', 'created_at'),
          _buildSortOption(context, 'Status', 'status'),
          _buildSortOption(context, 'Priority (High to Low)', '-priority'),
          _buildSortOption(context, 'Priority (Low to High)', 'priority'),
          _buildSortOption(context, 'Visit Date (Latest)', '-due_date'),
          _buildSortOption(context, 'Visit Date (Earliest)', 'due_date'),
        ],
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String label, String value) {
    final selected = currentSort == value;
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: value,
        groupValue: currentSort,
        onChanged: (v) {
          if (v != null) {
            onApply(v);
            Navigator.pop(context);
          }
        },
        activeColor: const Color(0xFF1565C0),
      ),
      selected: selected,
      onTap: () {
        onApply(value);
        Navigator.pop(context);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Task Detail Sheet Widget
// ══════════════════════════════════════════════════════════════════════════════

class _TaskDetailSheet extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isManager;
  final List<Map<String, dynamic>> projects;
  final VoidCallback onEdit;
  final Function(String) onStatusChange;

  const _TaskDetailSheet({
    required this.task,
    required this.isManager,
    required this.projects,
    required this.onEdit,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final lead = task['lead_detail'] ?? {};
    final leadName = lead['name'] ?? 'Unknown Lead';
    final leadPhone = isManager ? _maskPhone(lead['phone'] ?? '') : (lead['phone'] ?? '');
    final leadEmail = lead['email'] ?? '';
    final leadAddress = lead['address'] ?? '';
    
    final requirementType = lead['requirement_type'] ?? '';
    final bhk = lead['bhk_requirement'] ?? '';
    final budgetMin = double.tryParse(lead['budget_min']?.toString() ?? '0') ?? 0.0;
    final budgetMax = double.tryParse(lead['budget_max']?.toString() ?? '0') ?? 0.0;
    final preferredLocation = lead['preferred_location'] ?? '';
    
    final project = task['project_detail'];
    final projectName = project != null ? project['name'] ?? 'No Project' : 'No Project';
    final projectLocation = project != null ? project['location'] ?? '' : '';
    
    final assignedTo = task['assigned_to_detail'];
    final assignedToName = assignedTo != null ? assignedTo['username'] ?? '' : '';
    
    final status = task['status'] ?? 'in_progress';
    final priority = task['priority'] ?? 'medium';
    final dueDate = task['due_date'];
    final createdAt = task['created_at'];
    final updatedAt = task['updated_at'];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leadName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Task Details',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                    foregroundColor: const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  // Contact Information
                  _buildSection(
                    'Contact Information',
                    Icons.contact_phone_rounded,
                    [
                      if (leadPhone.isNotEmpty)
                        _buildInfoRow(Icons.phone_rounded, 'Phone', leadPhone, isClickable: !isManager, onTap: () => _launchURL('tel:$leadPhone')),
                      if (leadEmail.isNotEmpty)
                        _buildInfoRow(Icons.email_rounded, 'Email', leadEmail, isClickable: true, onTap: () => _launchURL('mailto:$leadEmail')),
                      if (leadAddress.isNotEmpty)
                        _buildInfoRow(Icons.location_on_rounded, 'Address', leadAddress),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Property Requirements
                  if (!isManager && (requirementType.isNotEmpty || bhk.isNotEmpty || budgetMin > 0))
                    _buildSection(
                      'Property Requirements',
                      Icons.home_rounded,
                      [
                        if (requirementType.isNotEmpty)
                          _buildInfoRow(Icons.apartment_rounded, 'Type', requirementType.replaceAll('_', ' ').toUpperCase()),
                        if (bhk.isNotEmpty)
                          _buildInfoRow(Icons.bed_rounded, 'BHK', '$bhk BHK'),
                        if (budgetMin > 0 && budgetMax > 0)
                          _buildInfoRow(Icons.attach_money_rounded, 'Budget', '₹${budgetMin.toStringAsFixed(0)} - ₹${budgetMax.toStringAsFixed(0)}'),
                        if (preferredLocation.isNotEmpty)
                          _buildInfoRow(Icons.location_city_rounded, 'Preferred Location', preferredLocation),
                      ],
                    ),
                  
                  if (!isManager && (requirementType.isNotEmpty || bhk.isNotEmpty || budgetMin > 0))
                    const SizedBox(height: 20),
                  
                  // Task Details
                  _buildSection(
                    'Task Details',
                    Icons.task_alt_rounded,
                    [
                      _buildInfoRow(Icons.business_rounded, 'Project', projectLocation.isNotEmpty ? '$projectName - $projectLocation' : projectName),
                      _buildInfoRow(Icons.person_outline_rounded, 'Assigned To', assignedToName.isNotEmpty ? assignedToName : 'Unassigned'),
                      if (dueDate != null && dueDate.toString().isNotEmpty)
                        _buildInfoRow(Icons.event_rounded, 'Visit Date', dueDate.toString().split('T')[0]),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Status & Priority with Quick Change
                  _buildSection(
                    'Status & Priority',
                    Icons.flag_rounded,
                    [
                      _buildStatusRow(context, status),
                      _buildPriorityRow(priority),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Timeline
                  _buildSection(
                    'Timeline',
                    Icons.schedule_rounded,
                    [
                      _buildInfoRow(Icons.add_circle_outline_rounded, 'Created', createdAt?.toString().split('T')[0] ?? ''),
                      _buildInfoRow(Icons.update_rounded, 'Last Updated', updatedAt?.toString().split('T')[0] ?? ''),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  if (!isManager && leadPhone.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL('tel:$leadPhone'),
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL('https://wa.me/${leadPhone.replaceAll(RegExp(r'[^\d]'), '')}'),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isManager && leadEmail.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchURL('mailto:$leadEmail'),
                        icon: const Icon(Icons.email_rounded, size: 18),
                        label: const Text('Send Email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isClickable = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isClickable ? const Color(0xFF1565C0) : Colors.black87,
                        decoration: isClickable ? TextDecoration.underline : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isClickable)
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String currentStatus) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: currentStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'site_visit', child: Text('Site Visit')),
                DropdownMenuItem(value: 'family_visit', child: Text('Family Visit')),
                DropdownMenuItem(value: 'perfect_family_visit', child: Text('Perfect Family Visit')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (newStatus) {
                if (newStatus != null && newStatus != currentStatus) {
                  onStatusChange(newStatus);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityRow(String priority) {
    final priorityColors = {
      'low': const Color(0xFF4CAF50),
      'medium': const Color(0xFFFFA726),
      'high': const Color(0xFFFF5722),
      'urgent': const Color(0xFFD32F2F),
    };
    
    final priorityLabels = {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'urgent': 'Urgent',
    };
    
    final color = priorityColors[priority] ?? Colors.grey;
    final label = priorityLabels[priority] ?? priority;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_rounded, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final start = phone.substring(0, 2);
    final end = phone.substring(phone.length - 2);
    return '$start${'*' * (phone.length - 4)}$end';
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit Task Dialog Widget
// ══════════════════════════════════════════════════════════════════════════════

class _EditTaskDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> projects;
  final VoidCallback onSave;

  const _EditTaskDialog({
    required this.task,
    required this.projects,
    required this.onSave,
  });

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late String _status;
  late String _priority;
  late String _project;
  DateTime? _dueDate;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.task['status'] ?? 'in_progress';
    _priority = widget.task['priority'] ?? 'medium';
    _project = widget.task['project']?.toString() ?? '';
    
    final dueDateStr = widget.task['due_date'];
    if (dueDateStr != null && dueDateStr.toString().isNotEmpty) {
      try {
        _dueDate = DateTime.parse(dueDateStr.toString());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final body = {
        'status': _status,
        'priority': _priority,
        'project': _project.isEmpty ? null : int.tryParse(_project),
        'due_date': _dueDate?.toIso8601String(),
      };
      
      print('Updating task with body: $body');
      
      final res = await ApiService.request(
        endpoint: '/tasks/${widget.task['id']}/',
        method: 'PATCH',
        body: body,
      );
      
      print('API Response: $res');
      
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Task updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onSave();
        } else {
          // Extract error message
          String errorMsg = 'Failed to update task';
          final data = res['data'];
          if (data is Map) {
            if (data.containsKey('detail')) {
              errorMsg = data['detail'].toString();
            } else if (data.containsKey('error')) {
              errorMsg = data['error'].toString();
            } else {
              // Field-specific errors
              final errors = <String>[];
              data.forEach((key, value) {
                if (value is List && value.isNotEmpty) {
                  errors.add('$key: ${value[0]}');
                } else if (value is String) {
                  errors.add('$key: $value');
                }
              });
              if (errors.isNotEmpty) {
                errorMsg = errors.join(', ');
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.task['lead_detail'] ?? {};
    final leadName = lead['name'] ?? 'Unknown Lead';
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Task',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leadName,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project
                    const Text('Project', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _project.isEmpty ? null : _project,
                      decoration: const InputDecoration(
                        hintText: 'Select project',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('No project')),
                        ...widget.projects.map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text('${p['name']} - ${p['location'] ?? ''}'),
                        )),
                      ],
                      onChanged: (v) => setState(() => _project = v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    
                    // Status
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'site_visit', child: Text('Site Visit')),
                        DropdownMenuItem(value: 'family_visit', child: Text('Family Visit')),
                        DropdownMenuItem(value: 'perfect_family_visit', child: Text('Perfect Family Visit')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'in_progress'),
                    ),
                    const SizedBox(height: 16),
                    
                    // Priority
                    const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                    ),
                    const SizedBox(height: 16),
                    
                    // Visit Date
                    const Text('Visit Date', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => _dueDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              _dueDate != null
                                  ? DateFormat('MMM d, yyyy').format(_dueDate!)
                                  : 'Select visit date',
                              style: TextStyle(
                                color: _dueDate != null ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_dueDate != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear Date'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Update Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



