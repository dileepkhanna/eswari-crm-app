import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import '../../services/api_service.dart';

class EswariLeadsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final VoidCallback? onTaskConverted;
  final Function(VoidCallback)? onRefreshRequested;
  
  const EswariLeadsTab({
    super.key,
    required this.userData,
    required this.isManager,
    this.onTaskConverted,
    this.onRefreshRequested,
  });

  @override
  State<EswariLeadsTab> createState() => _EswariLeadsTabState();
}

class _EswariLeadsTabState extends State<EswariLeadsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _leads = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Advanced filters
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    // Register refresh callback with parent
    widget.onRefreshRequested?.call(fetchLeads);
    fetchLeads();
    _fetchCreators();
    _fetchProjects(); // Fetch projects for detail view
  }
  String _requirementTypeFilter = '';
  String _bhkFilter = '';
  String _sourceFilter = '';
  String _createdByFilter = '';
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  
  // Sorting
  String _sortBy = '-created_at'; // Default: newest first
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 50;
  
  // Available creators (for filter)
  List<Map<String, dynamic>> _creators = [];
  
  // Available projects (for lead form)
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = false;

  static const Color _primary = Color(0xFF1565C0);

  final _statusColors = const {
    'new':            Color(0xFF1565C0),
    'hot':            Color(0xFFD32F2F),
    'warm':           Color(0xFFF57C00),
    'cold':           Color(0xFF0288D1),
    'not_interested': Color(0xFF757575),
    'reminder':       Color(0xFF6A1B9A),
  };

  final _statusLabels = const {
    'new':            'New',
    'hot':            'Hot',
    'warm':           'Warm',
    'cold':           'Cold',
    'not_interested': 'Not Interested',
    'reminder':       'Reminder',
  };
  
  static const _requirementTypeLabels = {
    'villa': 'Villa',
    'apartment': 'Apartment',
    'house': 'House',
    'plot': 'Plot',
  };
  
  static const _bhkLabels = {
    '1': '1 BHK',
    '2': '2 BHK',
    '3': '3 BHK',
    '4': '4 BHK',
    '5+': '5+ BHK',
  };
  
  static const _sourceLabels = {
    'call': 'Call',
    'walk_in': 'Walk-in',
    'website': 'Website',
    'referral': 'Referral',
    'customer_conversion': 'Customer Conversion',
  };

  @override
  bool get wantKeepAlive => true;
  
  Future<void> _fetchProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final res = await ApiService.get('/projects/');
      if (mounted && res['success'] == true) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  // Helper function to scan media and make file visible
  Future<void> _scanMediaFile(String filePath) async {
    if (Platform.isAndroid) {
      try {
        // Use media scanner to make file visible immediately
        final result = await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$filePath'
        ]);
        print('Media scan result: ${result.stdout}');
      } catch (e) {
        print('Media scan error: $e');
      }
    }
  }
  
  // Helper function to open file
  Future<void> _openFile(String filePath, BuildContext context) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _fetchCreators() async {
    try {
      final res = await ApiService.get('/accounts/users/?role=employee');
      if (mounted && res['success'] == true) {
        setState(() {
          _creators = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
        });
      }
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> fetchLeads() async {
    print('Fetching leads...'); // Debug
    setState(() => _loading = true);
    try {
      String url = '/leads/?page=$_currentPage&page_size=$_pageSize';
      
      // Apply filters
      if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
      if (_requirementTypeFilter.isNotEmpty) url += '&requirement_type=$_requirementTypeFilter';
      if (_bhkFilter.isNotEmpty) url += '&bhk_requirement=$_bhkFilter';
      if (_sourceFilter.isNotEmpty) url += '&source=$_sourceFilter';
      if (_createdByFilter.isNotEmpty) url += '&created_by=$_createdByFilter';
      if (_search.isNotEmpty) url += '&search=$_search';
      
      // Apply date range filter
      if (_startDateFilter != null) {
        url += '&created_after=${DateFormat('yyyy-MM-dd').format(_startDateFilter!)}';
      }
      if (_endDateFilter != null) {
        url += '&created_before=${DateFormat('yyyy-MM-dd').format(_endDateFilter!)}';
      }
      
      // Apply sorting
      if (_sortBy.isNotEmpty) url += '&ordering=$_sortBy';

      print('Fetching from URL: $url'); // Debug
      final res = await ApiService.get(url);
      print('API Response: $res'); // Debug
      
      if (mounted) {
        final data = res['data'];
        final leads = data?['results'] ?? [];
        print('Leads count: ${leads.length}'); // Debug
        print('First lead: ${leads.isNotEmpty ? leads[0] : "none"}'); // Debug
        
        setState(() {
          _leads = leads;
          _totalCount = data?['count'] ?? 0;
          _totalPages = (_totalCount / _pageSize).ceil();
          _loading = false;
        });
        
        print('State updated. Total leads: $_totalCount'); // Debug
      }
    } catch (e) {
      print('Error fetching leads: $e'); // Debug
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = '';
      _requirementTypeFilter = '';
      _bhkFilter = '';
      _sourceFilter = '';
      _createdByFilter = '';
      _startDateFilter = null;
      _endDateFilter = null;
      _search = '';
      _searchCtrl.clear();
      _currentPage = 1;
    });
    fetchLeads();
  }
  
  bool get _hasActiveFilters {
    return _statusFilter.isNotEmpty ||
        _requirementTypeFilter.isNotEmpty ||
        _bhkFilter.isNotEmpty ||
        _sourceFilter.isNotEmpty ||
        _createdByFilter.isNotEmpty ||
        _startDateFilter != null ||
        _endDateFilter != null ||
        _search.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      children: [
        Column(
          children: [
            _buildSearchBar(),
            if (_hasActiveFilters) _buildActiveFilters(),
            _buildActionRow(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _leads.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: fetchLeads,
                          color: _primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _leads.length,
                            itemBuilder: (_, i) => _buildLeadCard(_leads[i]),
                          ),
                        ),
            ),
            if (_totalPages > 1) _buildPagination(),
          ],
        ),
        // Floating Add Lead Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _showAddLeadForm,
            backgroundColor: _primary,
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
            label: const Text('Add Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            elevation: 4,
          ),
        ),
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
                hintText: 'Search by company or contact...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          fetchLeads();
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
                if (v.isEmpty) fetchLeads();
              },
              onSubmitted: (_) => fetchLeads(),
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
      builder: (_) => _LeadFilterSheet(
        statusFilter: _statusFilter,
        requirementTypeFilter: _requirementTypeFilter,
        bhkFilter: _bhkFilter,
        sourceFilter: _sourceFilter,
        createdByFilter: _createdByFilter,
        startDateFilter: _startDateFilter,
        endDateFilter: _endDateFilter,
        creators: _creators,
        isManager: widget.isManager,
        onApply: (status, requirementType, bhk, source, createdBy, startDate, endDate) {
          setState(() {
            _statusFilter = status;
            _requirementTypeFilter = requirementType;
            _bhkFilter = bhk;
            _sourceFilter = source;
            _createdByFilter = createdBy;
            _startDateFilter = startDate;
            _endDateFilter = endDate;
            _currentPage = 1;
          });
          fetchLeads();
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
          fetchLeads();
        },
      ),
    );
  }

  
  Widget _buildActiveFilters() {
    final filters = <String>[];
    if (_statusFilter.isNotEmpty) filters.add(_statusLabels[_statusFilter] ?? _statusFilter);
    if (_requirementTypeFilter.isNotEmpty) filters.add(_requirementTypeLabels[_requirementTypeFilter] ?? _requirementTypeFilter);
    if (_bhkFilter.isNotEmpty) filters.add(_bhkLabels[_bhkFilter] ?? _bhkFilter);
    if (_sourceFilter.isNotEmpty) filters.add(_sourceLabels[_sourceFilter] ?? _sourceFilter);
    if (_createdByFilter.isNotEmpty) {
      final creator = _creators.firstWhere(
        (c) => c['id'].toString() == _createdByFilter,
        orElse: () => {'username': 'Creator'},
      );
      filters.add(creator['username'] ?? 'Creator');
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: filters.map((f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withOpacity(0.3)),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showTemplateOptions,
              icon: const Icon(Icons.file_download_rounded, size: 16),
              label: const Text('Template', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A1B9A),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _importFromExcel,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Import', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showExportOptions,
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
        ],
      ),
    );
  }
  
  Widget _buildPagination() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _pageSize + 1}–${(_currentPage * _pageSize).clamp(0, _totalCount)} of $_totalCount leads',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                onPressed: _currentPage > 1 ? () {
                  setState(() => _currentPage = 1);
                  fetchLeads();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1 ? () {
                  setState(() => _currentPage--);
                  fetchLeads();
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < _totalPages ? () {
                  setState(() => _currentPage++);
                  fetchLeads();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                onPressed: _currentPage < _totalPages ? () {
                  setState(() => _currentPage = _totalPages);
                  fetchLeads();
                } : null,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final status  = lead['status'] ?? 'new';
    final color   = _statusColors[status] ?? _primary;
    final name = lead['name'] ?? 'Unknown Lead';
    final phone   = widget.isManager ? _maskPhone(lead['phone'] ?? '') : (lead['phone'] ?? '');
    final requirementType = lead['requirement_type'] ?? '';
    final bhk = lead['bhk_requirement'] ?? '';
    final budgetMin = double.tryParse(lead['budget_min']?.toString() ?? '0') ?? 0.0;
    final budgetMax = double.tryParse(lead['budget_max']?.toString() ?? '0') ?? 0.0;
    final location = lead['preferred_location'] ?? '';
    final assignedProjects = lead['assigned_projects'] as List? ?? [];
    final assignedToName = lead['assigned_to_name'] ?? '';
    final source = lead['source'] ?? '';
    final followUpDate = lead['follow_up_date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, color: color, size: 22),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            if (requirementType.isNotEmpty && bhk.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.home_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$bhk BHK ${_requirementTypeLabels[requirementType] ?? requirementType}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            if (budgetMin > 0 && budgetMax > 0) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.attach_money_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '\$${budgetMin.toStringAsFixed(0)} - \$${budgetMax.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (source.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.source_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _sourceLabels[source] ?? source.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (assignedToName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned: $assignedToName',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (followUpDate != null && followUpDate.toString().isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 12, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Follow-up: ${followUpDate.toString().split('T')[0]}',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (assignedProjects.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📁 ${assignedProjects.length} Project${assignedProjects.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: _primary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabels[status] ?? status,
                  style: TextStyle(fontSize: 10, color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        onTap: () => _showLeadDetail(lead),
      ),
    );
  }
  
  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    final start = phone.substring(0, 2);
    final end = phone.substring(phone.length - 2);
    return '$start${'*' * (phone.length - 4)}$end';
  }
  
  // ── Download Template ──────────────────────────────────────────────────────
  Future<void> _showTemplateOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Template Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.download_rounded, color: Color(0xFF6A1B9A)),
              title: const Text('Download'),
              subtitle: const Text('Save template to device'),
              onTap: () {
                Navigator.pop(context);
                _downloadTemplate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF6A1B9A)),
              title: const Text('Share'),
              subtitle: const Text('Share template file'),
              onTap: () {
                Navigator.pop(context);
                _shareTemplate();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      
      final sheet = excel['Template'];

      // Only required fields: Name and Phone
      final headers = [
        'Name*', 'Phone*'
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_leads_template_$timestamp.xlsx';
      final filePath = '${dir!.path}/$fileName';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      // Scan media to make file visible immediately
      await _scanMediaFile(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Template downloaded successfully!', 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('📁 ${dir.path}', style: const TextStyle(fontSize: 11)),
                Text('📄 $fileName', style: const TextStyle(fontSize: 11)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => _openFile(filePath, context),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template download error: $e'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  Future<void> _shareTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      
      final sheet = excel['Template'];

      // Only required fields: Name and Phone
      final headers = [
        'Name*', 'Phone*'
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_leads_template_$timestamp.xlsx';
      final filePath = '${dir.path}/$fileName';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Leads Import Template',
        text: 'Use this template to import leads into Eswari CRM',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Import from Excel ──────────────────────────────────────────────────────
  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final bytes = File(path).readAsBytesSync();
      final excel = xl.Excel.decodeBytes(bytes);

      final leads = <Map<String, dynamic>>[];
      
      // Process the Template sheet
      for (final tableName in excel.tables.keys) {
        final table = excel.tables[tableName];
        if (table == null) continue;
        
        print('Processing sheet: $tableName with ${table.rows.length} rows');
        
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          
          // Skip empty rows
          if (row.isEmpty) continue;
          
          // Check if all cells are empty
          bool allEmpty = true;
          for (final cell in row) {
            if (cell?.value != null && cell!.value.toString().trim().isNotEmpty) {
              allEmpty = false;
              break;
            }
          }
          if (allEmpty) continue;
          
          final name = row.length > 0 ? (row[0]?.value?.toString().trim() ?? '') : '';
          var phone = row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '';
          
          // Remove .0 from phone numbers (Excel treats numbers as floats)
          if (phone.endsWith('.0')) {
            phone = phone.substring(0, phone.length - 2);
          }
          
          print('Row $i: Name = "$name", Phone = "$phone"');
          
          // Skip if required fields are empty or example data
          if (name.isEmpty || phone.isEmpty || name == 'Example Name') continue;
          
          leads.add({
            'name': name,  // Map to 'name' field for Lead model
            'phone': phone,
            // Optional fields with defaults
            'email': '',
            'address': '',
            'requirement_type': 'apartment',
            'bhk_requirement': '2',
            'budget_min': 0,
            'budget_max': 0,
            'preferred_location': '',
            'status': 'new',
            'source': 'website',
            'description': '',
            'follow_up_date': null,
          });
          print('Added lead: ${leads.last}');
        }
        break;
      }

      print('Total leads to import: ${leads.length}');

      if (leads.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid rows found. Please ensure:\n• Name and Phone columns have values\n• You are using the Template sheet\n• Remove or modify the example row'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Importing ${leads.length} leads...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final res = await ApiService.post('/leads/bulk_import/', {'leads': leads});
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        final ok = res['success'] == true;
        final imported = res['data']?['imported'] ?? 0;
        final errors = res['data']?['errors'] ?? [];
        
        String msg;
        if (ok) {
          if (errors.isEmpty) {
            msg = '✅ Successfully imported $imported leads!';
          } else {
            // Show detailed error information
            final errorDetails = (errors as List).take(3).map((e) {
              if (e is Map) {
                final company = e['company_name'] ?? e['phone'] ?? 'Unknown';
                final reason = e['error'] ?? 'Unknown error';
                return '• $company: $reason';
              }
              return '• $e';
            }).join('\n');
            
            msg = '✅ Imported $imported leads\n⚠️ ${errors.length} skipped:\n$errorDetails';
            if (errors.length > 3) {
              msg += '\n... and ${errors.length - 3} more';
            }
          }
        } else {
          msg = '❌ Import failed: ${res['data']?['detail'] ?? 'Unknown error'}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? Colors.green : Colors.red,
            duration: Duration(seconds: errors.isEmpty ? 3 : 8),
          ),
        );
        if (ok && imported > 0) fetchLeads();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import error: $e\n\nPlease check:\n• File format is correct\n• Name and Phone columns have values\n• Remove the example row before importing'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
  }

  // ── Export to Excel ────────────────────────────────────────────────────────
  Future<void> _showExportOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.download_rounded, color: Color(0xFF2E7D32)),
              title: const Text('Download'),
              subtitle: Text('Save $_totalCount leads to device'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF2E7D32)),
              title: const Text('Share'),
              subtitle: Text('Share $_totalCount leads file'),
              onTap: () {
                Navigator.pop(context);
                _shareExport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      // Fetch all pages
      List<dynamic> allLeads = [];
      int page = 1;
      while (true) {
        String url = '/leads/?page=$page&page_size=200';
        if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
        if (_requirementTypeFilter.isNotEmpty) url += '&requirement_type=$_requirementTypeFilter';
        if (_bhkFilter.isNotEmpty) url += '&bhk_requirement=$_bhkFilter';
        if (_sourceFilter.isNotEmpty) url += '&source=$_sourceFilter';
        if (_search.isNotEmpty) url += '&search=$_search';
        
        final res = await ApiService.get(url);
        final results = res['data']?['results'] ?? [];
        allLeads.addAll(results);
        
        if (res['data']?['next'] == null) break;
        page++;
      }

      final excel = xl.Excel.createExcel();
      
      final sheet = excel['Leads'];

      final headers = [
        'Name', 'Phone', 'Email', 'Address',
        'Requirement Type', 'BHK', 'Budget Min', 'Budget Max',
        'Preferred Location', 'Source', 'Status',
        'Description', 'Assigned To', 'Created By', 'Created At'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }

      for (int i = 0; i < allLeads.length; i++) {
        final l = allLeads[i] as Map<String, dynamic>;
        
        final row = [
          l['name'] ?? '',
          l['phone'] ?? '',
          l['email'] ?? '',
          l['address'] ?? '',
          _requirementTypeLabels[l['requirement_type']] ?? l['requirement_type'] ?? '',
          l['bhk_requirement'] ?? '',
          l['budget_min']?.toString() ?? '',
          l['budget_max']?.toString() ?? '',
          l['preferred_location'] ?? '',
          _sourceLabels[l['source']] ?? l['source'] ?? '',
          _statusLabels[l['status']] ?? l['status'] ?? '',
          l['description'] ?? '',
          l['assigned_to_name'] ?? '',
          l['created_by_name'] ?? '',
          l['created_at'] ?? '',
        ];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir!.path}/eswari_leads_export_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${allLeads.length} leads to Downloads folder'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _shareExport() async {
    try {
      // Fetch all pages
      final allLeads = <Map<String, dynamic>>[];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        final res = await ApiService.get('/leads/?page=$currentPage&page_size=100');
        if (res['data'] != null) {
          final results = res['data']['results'] as List;
          allLeads.addAll(results.cast<Map<String, dynamic>>());
          hasMore = res['data']['next'] != null;
          currentPage++;
        } else {
          break;
        }
      }

      final excel = xl.Excel.createExcel();
      final sheet = excel['Leads'];

      final headers = [
        'Company', 'Contact', 'Email', 'Phone', 'Website', 'Industry',
        'Budget', 'Status', 'Priority', 'Goals', 'Notes', 'Created'
      ];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }

      for (int i = 0; i < allLeads.length; i++) {
        final lead = allLeads[i];
        final rowData = [
          lead['company_name'] ?? '',
          lead['contact_person'] ?? '',
          lead['email'] ?? '',
          lead['phone'] ?? '',
          lead['website'] ?? '',
          lead['industry'] ?? '',
          lead['budget_amount']?.toString() ?? '',
          lead['status'] ?? '',
          lead['priority'] ?? '',
          lead['marketing_goals'] ?? '',
          lead['notes'] ?? '',
          lead['created_at'] != null
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(lead['created_at']))
              : '',
        ];

        for (int j = 0; j < rowData.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(rowData[j]);
        }
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/eswari_leads_export_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Leads Export',
        text: 'Exported ${allLeads.length} leads from Eswari CRM',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _showAddLeadForm() {
    showDialog(
      context: context,
      builder: (_) => _AddLeadDialog(
        userData: widget.userData,
        onSave: () {
          // Reset to page 1 and refresh to show new lead
          setState(() {
            _currentPage = 1;
          });
          // Small delay to ensure backend has processed the lead
          Future.delayed(const Duration(milliseconds: 500), () {
            fetchLeads();
          });
        },
      ),
    );
  }

  void _showEditLeadForm(Map<String, dynamic> lead) {
    showDialog(
      context: context,
      builder: (_) => _EditLeadDialog(
        userData: widget.userData,
        lead: lead,
        onSave: () {
          // Reset to page 1 and refresh to show updated lead
          setState(() {
            _currentPage = 1;
          });
          // Small delay to ensure backend has processed the update
          Future.delayed(const Duration(milliseconds: 500), () {
            fetchLeads();
          });
        },
      ),
    );
  }

  void _showLeadDetail(Map<String, dynamic> lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LeadDetailSheet(
        lead: lead,
        projects: _projects, // Pass projects list to detail sheet
        onRefresh: fetchLeads,
        onEdit: () {
          Navigator.pop(context);
          _showEditLeadForm(lead);
        },
        onDelete: () async {
          Navigator.pop(context);
          await _deleteLead(lead);
        },
        onConvertToTask: () async {
          Navigator.pop(context);
          await _showConvertToTaskDialog(lead);
        },
      ),
    );
  }
  
  Future<void> _showConvertToTaskDialog(Map<String, dynamic> lead) async {
    showDialog(
      context: context,
      builder: (_) => _ConvertToTaskDialog(
        lead: lead,
        projects: _projects,
        userData: widget.userData,
        onSuccess: () {
          fetchLeads(); // Refresh leads list
          widget.onTaskConverted?.call(); // Refresh tasks tab
        },
      ),
    );
  }
  
  Future<void> _deleteLead(Map<String, dynamic> lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete "${lead['name'] ?? 'this lead'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final id = lead['id'];
      final res = await ApiService.request(
        endpoint: '/leads/$id/',
        method: 'DELETE',
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          fetchLeads();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['detail'] ?? 'Failed to delete'}'),
              backgroundColor: Colors.red,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No leads found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _LeadDetailSheet extends StatelessWidget {
  final Map<String, dynamic> lead;
  final List<Map<String, dynamic>> projects;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConvertToTask;
  
  const _LeadDetailSheet({
    required this.lead,
    required this.projects,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onConvertToTask,
  });

  static const Color _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final name = lead['name'] ?? 'Unknown Lead';
    final phone = lead['phone'] ?? '';
    final email = lead['email'] ?? '';
    final address = lead['address'] ?? '';
    final status = lead['status'] ?? 'new';
    final requirementType = lead['requirement_type'] ?? '';
    final bhk = lead['bhk_requirement'] ?? '';
    final budgetMin = double.tryParse(lead['budget_min']?.toString() ?? '0') ?? 0.0;
    final budgetMax = double.tryParse(lead['budget_max']?.toString() ?? '0') ?? 0.0;
    final preferredLocation = lead['preferred_location'] ?? '';
    final source = lead['source'] ?? '';
    final description = lead['description'] ?? '';
    final assignedProjects = lead['assigned_projects'] as List? ?? [];
    final assignedTo = lead['assigned_to_name'] ?? '';
    final createdBy = lead['created_by_name'] ?? '';
    final followUpDate = lead['follow_up_date'] ?? '';

    final _requirementTypeLabels = const {
      'villa': 'Villa',
      'apartment': 'Apartment',
      'house': 'House',
      'plot': 'Plot',
    };

    final _statusLabels = const {
      'new': 'New',
      'hot': 'Hot',
      'warm': 'Warm',
      'cold': 'Cold',
      'not_interested': 'Not Interested',
      'reminder': 'Reminder',
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: _primary),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            
            // Quick action buttons
            if (phone.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(phone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(phone),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            
            if (email.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendEmail(email),
                  icon: const Icon(Icons.email, size: 18),
                  label: const Text('Send Email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Lead Information
            _row('Status', _statusLabels[status] ?? status, theme),
            
            // Quick Status Change Dropdown
            const SizedBox(height: 12),
            const Text(
              'Change Status',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
                  items: _statusLabels.entries.map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: (newStatus) {
                    if (newStatus != null && newStatus != status) {
                      _updateLeadStatus(context, lead, newStatus);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            if (phone.isNotEmpty) _row('Phone', phone, theme),
            if (email.isNotEmpty) _row('Email', email, theme),
            if (address.isNotEmpty) _row('Address', address, theme),
            
            if (requirementType.isNotEmpty || bhk.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Property Requirements',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              if (requirementType.isNotEmpty)
                _row('Type', _requirementTypeLabels[requirementType] ?? requirementType, theme),
              if (bhk.isNotEmpty) _row('BHK', '$bhk BHK', theme),
              if (budgetMin > 0 || budgetMax > 0)
                _row(
                  'Budget',
                  '\$${budgetMin.toStringAsFixed(0)} - \$${budgetMax.toStringAsFixed(0)}',
                  theme,
                ),
              if (preferredLocation.isNotEmpty)
                _row('Preferred Location', preferredLocation, theme),
            ],
            
            if (assignedProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Assigned Projects',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              ...assignedProjects.map((p) {
                String projectName = 'Project';
                String projectLocation = '';
                
                // If p is already a Map with full project details
                if (p is Map) {
                  projectName = p['name']?.toString() ?? 'Project ${p['id'] ?? ''}';
                  projectLocation = p['location']?.toString() ?? '';
                } 
                // If p is just an ID (int or String), look it up in the projects list
                else if (p is int || p is String) {
                  final projectId = p.toString();
                  final matchedProject = projects.firstWhere(
                    (proj) => proj['id'].toString() == projectId,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (matchedProject.isNotEmpty) {
                    projectName = matchedProject['name']?.toString() ?? 'Project #$projectId';
                    projectLocation = matchedProject['location']?.toString() ?? '';
                  } else {
                    projectName = 'Project #$projectId';
                  }
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(isDark ? 0.15 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primary.withOpacity(isDark ? 0.3 : 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 16, color: _primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              projectName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            if (projectLocation.isNotEmpty)
                              Text(
                                projectLocation,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            if (source.isNotEmpty) ...[
              const SizedBox(height: 12),
              _row('Lead Source', source.replaceAll('_', ' ').toUpperCase(), theme),
            ],
            
            if (followUpDate.isNotEmpty) ...[
              const SizedBox(height: 12),
              _row('Follow-up Date', followUpDate.split('T')[0], theme),
            ],
            
            if (assignedTo.isNotEmpty) _row('Assigned To', assignedTo, theme),
            if (createdBy.isNotEmpty) _row('Created By', createdBy, theme),
            
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Description / Notes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConvertToTask,
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Convert to Task'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
  Widget _row(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
  
  void _makePhoneCall(String phone) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (_) {}
  }
  
  void _openWhatsApp(String phone) async {
    try {
      // Remove any non-digit characters from phone number
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
  
  void _sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    } catch (_) {}
  }
  
  void _updateLeadStatus(BuildContext context, Map<String, dynamic> lead, String newStatus) async {
    try {
      final leadId = lead['id'];
      final res = await ApiService.request(
        endpoint: '/leads/$leadId/',
        method: 'PATCH',
        body: {'status': newStatus},
      );
      
      final statusLabels = const {
        'new': 'New',
        'hot': 'Hot',
        'warm': 'Warm',
        'cold': 'Cold',
        'not_interested': 'Not Interested',
        'reminder': 'Reminder',
      };
      
      if (res['success'] == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Status updated to ${statusLabels[newStatus]}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          onRefresh(); // Refresh the list
          Navigator.pop(context); // Close the detail sheet
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _LeadFilterSheet - Filter Bottom Sheet for Leads
// ─────────────────────────────────────────────────────────────────────────────
class _LeadFilterSheet extends StatefulWidget {
  final String statusFilter;
  final String requirementTypeFilter;
  final String bhkFilter;
  final String sourceFilter;
  final String createdByFilter;
  final DateTime? startDateFilter;
  final DateTime? endDateFilter;
  final List<Map<String, dynamic>> creators;
  final bool isManager;
  final Function(String, String, String, String, String, DateTime?, DateTime?) onApply;
  final VoidCallback onClear;

  const _LeadFilterSheet({
    required this.statusFilter,
    required this.requirementTypeFilter,
    required this.bhkFilter,
    required this.sourceFilter,
    required this.createdByFilter,
    required this.startDateFilter,
    required this.endDateFilter,
    required this.creators,
    required this.isManager,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_LeadFilterSheet> createState() => _LeadFilterSheetState();
}

class _LeadFilterSheetState extends State<_LeadFilterSheet> {
  late String _status;
  late String _requirementType;
  late String _bhk;
  late String _source;
  late String _createdBy;
  DateTime? _startDate;
  DateTime? _endDate;

  static const Color _primary = Color(0xFF1565C0);

  static const _statusOptions = [
    ('', 'All Status'),
    ('new', 'New'),
    ('hot', 'Hot'),
    ('warm', 'Warm'),
    ('cold', 'Cold'),
    ('not_interested', 'Not Interested'),
    ('reminder', 'Reminder'),
  ];

  static const _requirementTypeOptions = [
    ('', 'All Types'),
    ('villa', 'Villa'),
    ('apartment', 'Apartment'),
    ('house', 'House'),
    ('plot', 'Plot'),
  ];

  static const _bhkOptions = [
    ('', 'All BHK'),
    ('1', '1 BHK'),
    ('2', '2 BHK'),
    ('3', '3 BHK'),
    ('4', '4 BHK'),
    ('5+', '5+ BHK'),
  ];

  static const _sourceOptions = [
    ('', 'All Sources'),
    ('call', 'Call'),
    ('walk_in', 'Walk-in'),
    ('website', 'Website'),
    ('referral', 'Referral'),
    ('customer_conversion', 'Customer Conversion'),
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _requirementType = widget.requirementTypeFilter;
    _bhk = widget.bhkFilter;
    _source = widget.sourceFilter;
    _createdBy = widget.createdByFilter;
    _startDate = widget.startDateFilter;
    _endDate = widget.endDateFilter;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'Filter Leads',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Filters
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Status
                  _buildSectionTitle('Status', Icons.flag_rounded),
                  const SizedBox(height: 8),
                  _buildStatusChips(),
                  const SizedBox(height: 20),

                  // Requirement Type
                  _buildSectionTitle('Requirement Type', Icons.home_rounded),
                  const SizedBox(height: 8),
                  _buildRequirementTypeChips(),
                  const SizedBox(height: 20),

                  // BHK
                  _buildSectionTitle('BHK Requirement', Icons.bed_rounded),
                  const SizedBox(height: 8),
                  _buildBhkChips(),
                  const SizedBox(height: 20),

                  // Source
                  _buildSectionTitle('Lead Source', Icons.source_rounded),
                  const SizedBox(height: 8),
                  _buildSourceChips(),
                  const SizedBox(height: 20),

                  // Created By (only for managers)
                  if (widget.isManager) ...[
                    _buildSectionTitle('Created By', Icons.person_rounded),
                    const SizedBox(height: 8),
                    _buildCreatedByDropdown(),
                    const SizedBox(height: 20),
                  ],

                  // Date Range Filter
                  _buildSectionTitle('Date Range', Icons.date_range_rounded),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                            }
                          },
                          onClear: _startDate != null ? () => setState(() => _startDate = null) : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateButton(
                          label: 'End Date',
                          date: _endDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: _startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                            }
                          },
                          onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Apply button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_status, _requirementType, _bhk, _source, _createdBy, _startDate, _endDate);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _statusOptions.map((opt) {
        final isSelected = _status == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _status = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _primary : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRequirementTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _requirementTypeOptions.map((opt) {
        final isSelected = _requirementType == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _requirementType = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _primary : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBhkChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _bhkOptions.map((opt) {
        final isSelected = _bhk == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _bhk = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _primary : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSourceChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sourceOptions.map((opt) {
        final isSelected = _source == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _source = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _primary : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreatedByDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _createdBy.isEmpty ? '' : _createdBy,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
          items: [
            const DropdownMenuItem(value: '', child: Text('All Creators')),
            ...widget.creators.map((c) => DropdownMenuItem(
              value: c['id'].toString(),
              child: Text(c['username'] ?? c['email'] ?? 'User ${c['id']}'),
            )),
          ],
          onChanged: (v) => setState(() => _createdBy = v ?? ''),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date == null ? 'Select' : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      color: date == null ? Colors.grey[500] : Colors.black87,
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.clear_rounded, size: 16, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddLeadDialog - Add Lead Form Dialog (Eswari Group - Real Estate)
// ─────────────────────────────────────────────────────────────────────────────
class _AddLeadDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onSave;

  const _AddLeadDialog({
    required this.userData,
    required this.onSave,
  });

  @override
  State<_AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<_AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _preferredLocationCtrl = TextEditingController();
  final _customSourceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _requirementType = 'apartment';
  String _bhk = '2';
  String _status = 'new';
  String _source = 'website';
  List<String> _selectedProjects = [];
  DateTime? _followUpDate;
  bool _loading = false;
  bool _loadingProjects = false;
  List<Map<String, dynamic>> _projects = [];

  static const Color _primary = Color(0xFF1565C0);

  static const _sourceOptions = [
    ('call', 'Call'),
    ('walk_in', 'Walk-in'),
    ('website', 'Website'),
    ('referral', 'Referral'),
    ('customer_conversion', 'Customer Conversion'),
    ('custom', 'Custom'),
  ];

  @override
  void initState() {
    super.initState();
    print('=== ADD LEAD DIALOG INITIALIZED ==='); // Debug log
    _fetchProjects();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _preferredLocationCtrl.dispose();
    _customSourceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final res = await ApiService.get('/projects/');
      if (mounted && res['success'] == true) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate reminder status requires follow-up date
    if (_status == 'reminder' && _followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reminder date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate custom source
    if (_source == 'custom' && _customSourceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom lead source'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final companyId = widget.userData['company']?['id'];
      if (companyId == null) {
        throw Exception('Company ID not found in user data');
      }

      // Prepare final source value
      final finalSource = _source == 'custom' ? _customSourceCtrl.text.trim() : _source;

      final body = {
        'company': companyId,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? '' : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? '' : _addressCtrl.text.trim(),
        'requirement_type': _requirementType,
        'bhk_requirement': _bhk,
        'budget_min': _budgetMinCtrl.text.trim().isEmpty ? 0 : double.tryParse(_budgetMinCtrl.text.trim()) ?? 0,
        'budget_max': _budgetMaxCtrl.text.trim().isEmpty ? 0 : double.tryParse(_budgetMaxCtrl.text.trim()) ?? 0,
        'preferred_location': _preferredLocationCtrl.text.trim().isEmpty ? '' : _preferredLocationCtrl.text.trim(),
        'source': finalSource,
        'status': _status,
        'assigned_to': widget.userData['id'], // Auto-assign to current user
        'assigned_projects': _selectedProjects.isNotEmpty ? _selectedProjects : [],
        'follow_up_date': _followUpDate?.toIso8601String(),
        'description': _descriptionCtrl.text.trim().isEmpty ? '' : _descriptionCtrl.text.trim(),
      };

      print('Creating lead with body: $body'); // Debug log
      print('Company ID: $companyId'); // Debug log
      print('Assigned to user ID: ${widget.userData['id']}'); // Debug log

      final res = await ApiService.post('/leads/', body);

      print('API Response: $res'); // Debug log
      print('Response status: ${res['status']}'); // Debug log
      print('Response success: ${res['success']}'); // Debug log
      print('Response data: ${res['data']}'); // Debug log

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Lead created successfully! Refreshing list...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onSave();
          Navigator.pop(context);
        } else {
          // Extract detailed error message
          String errorMsg = 'Failed to create lead';
          if (res['data'] != null) {
            if (res['data'] is Map) {
              final data = res['data'] as Map;
              
              // Check for non_field_errors (like unique constraint violations)
              if (data['non_field_errors'] != null) {
                final errors = data['non_field_errors'];
                if (errors is List && errors.isNotEmpty) {
                  errorMsg = errors[0].toString();
                  // Make it more user-friendly
                  if (errorMsg.contains('phone') && errorMsg.contains('unique')) {
                    errorMsg = 'A lead with this phone number already exists. Please use a different phone number.';
                  }
                }
              }
              // Check for detail field
              else if (data['detail'] != null) {
                errorMsg = data['detail'].toString();
              } 
              // Check for error field
              else if (data['error'] != null) {
                errorMsg = data['error'].toString();
              } 
              // Try to get field-specific errors
              else {
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
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Exception creating lead: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.95, // 95% of screen width for better visibility
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 500),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Add New Lead',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Basic Information
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Full Name *',
                      hint: 'Enter full name',
                      icon: Icons.person_rounded,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number *',
                      hint: 'Enter phone number',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'Enter email address (optional)',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressCtrl,
                      label: 'Address',
                      hint: 'Enter address (optional)',
                      icon: Icons.location_on_rounded,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),
                    // Lead Source
                    _buildSectionHeader('Lead Source'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Source',
                      value: _source,
                      items: _sourceOptions,
                      onChanged: (v) => setState(() => _source = v!),
                    ),
                    if (_source == 'custom') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _customSourceCtrl,
                        label: 'Custom Source *',
                        hint: 'e.g., Facebook Ad, Trade Show, LinkedIn',
                        validator: (v) => _source == 'custom' && (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Property Requirements
                    _buildSectionHeader('Property Requirements'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Requirement Type',
                            value: _requirementType,
                            items: const [
                              ('villa', 'Villa'),
                              ('apartment', 'Apartment'),
                              ('house', 'House'),
                              ('plot', 'Plot'),
                            ],
                            onChanged: (v) => setState(() => _requirementType = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'BHK Requirement',
                            value: _bhk,
                            items: const [
                              ('1', '1 BHK'),
                              ('2', '2 BHK'),
                              ('3', '3 BHK'),
                              ('4', '4 BHK'),
                              ('5+', '5+ BHK'),
                            ],
                            onChanged: (v) => setState(() => _bhk = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _budgetMinCtrl,
                            label: 'Minimum Budget (\$)',
                            hint: 'e.g., 100000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _budgetMaxCtrl,
                            label: 'Maximum Budget (\$)',
                            hint: 'e.g., 500000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _preferredLocationCtrl,
                      label: 'Preferred Location',
                      hint: 'e.g., Downtown, Suburb Area',
                    ),

                    const SizedBox(height: 20),
                    // Assigned Projects
                    _buildSectionHeader('Assigned Projects'),
                    const SizedBox(height: 12),
                    if (_loadingProjects)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      )
                    else if (_projects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'No projects available',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedProjects.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Selected: ${_selectedProjects.length}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _selectedProjects.clear()),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _projects.length,
                                itemBuilder: (_, i) {
                                  final project = _projects[i];
                                  final projectId = project['id'].toString();
                                  final isSelected = _selectedProjects.contains(projectId);
                                  return CheckboxListTile(
                                    title: Text(
                                      project['name'] ?? 'Project ${project['id']}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: project['location'] != null
                                        ? Text(
                                            project['location'],
                                            style: const TextStyle(fontSize: 11),
                                          )
                                        : null,
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedProjects.add(projectId);
                                        } else {
                                          _selectedProjects.remove(projectId);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    // Lead Management
                    _buildSectionHeader('Lead Management'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Status',
                      value: _status,
                      items: const [
                        ('new', 'New'),
                        ('hot', 'Hot'),
                        ('warm', 'Warm'),
                        ('cold', 'Cold'),
                        ('not_interested', 'Not Interested'),
                        ('reminder', 'Reminder'),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: _status == 'reminder' ? 'Follow-up Date *' : 'Follow-up Date',
                      value: _followUpDate,
                      onChanged: (date) => setState(() => _followUpDate = date),
                      enabled: _status == 'reminder',
                    ),
                    if (_status == 'reminder' && _followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Reminder will appear on ${DateFormat('MMMM d, yyyy').format(_followUpDate!)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 20),
                    // Description / Notes
                    _buildSectionHeader('Description / Notes'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionCtrl,
                      label: 'Additional Notes',
                      hint: 'Add any additional notes or comments...',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () {
                        print('=== CREATE LEAD BUTTON PRESSED ==='); // Debug log
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Create Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _primary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
        prefixIcon: icon != null ? Icon(icon, color: _primary, size: 20) : null,
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<(String, String)> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
              items: items.map((item) => DropdownMenuItem(
                value: item.$1,
                child: Text(item.$2, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required void Function(DateTime?) onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: enabled ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value == null
                        ? 'mm/dd/yyyy'
                        : DateFormat('MM/dd/yyyy').format(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ),
                if (value != null && enabled)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _EditLeadDialog - Edit Lead Form Dialog (Eswari Group - Real Estate)
// ─────────────────────────────────────────────────────────────────────────────
class _EditLeadDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> lead;
  final VoidCallback onSave;

  const _EditLeadDialog({
    required this.userData,
    required this.lead,
    required this.onSave,
  });

  @override
  State<_EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends State<_EditLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _preferredLocationCtrl = TextEditingController();
  final _customSourceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _requirementType = 'apartment';
  String _bhk = '2';
  String _status = 'new';
  String _source = 'website';
  List<String> _selectedProjects = [];
  DateTime? _followUpDate;
  bool _loading = false;
  bool _loadingProjects = false;
  List<Map<String, dynamic>> _projects = [];

  static const Color _primary = Color(0xFF1565C0);

  static const _sourceOptions = [
    ('call', 'Call'),
    ('walk_in', 'Walk-in'),
    ('website', 'Website'),
    ('referral', 'Referral'),
    ('customer_conversion', 'Customer Conversion'),
    ('custom', 'Custom'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _populateFields();
  }

  void _populateFields() {
    // Basic fields
    _nameCtrl.text = widget.lead['name'] ?? '';
    _phoneCtrl.text = widget.lead['phone'] ?? '';
    _emailCtrl.text = widget.lead['email'] ?? '';
    _addressCtrl.text = widget.lead['address'] ?? '';
    
    // Property requirements
    _requirementType = widget.lead['requirement_type'] ?? 'apartment';
    _bhk = widget.lead['bhk_requirement'] ?? '2';
    
    // Budget
    final budgetMin = widget.lead['budget_min'];
    final budgetMax = widget.lead['budget_max'];
    if (budgetMin != null && budgetMin != 0) {
      _budgetMinCtrl.text = budgetMin.toString();
    }
    if (budgetMax != null && budgetMax != 0) {
      _budgetMaxCtrl.text = budgetMax.toString();
    }
    
    _preferredLocationCtrl.text = widget.lead['preferred_location'] ?? '';
    
    // Source - check if it's a standard source or custom
    final leadSource = widget.lead['source'] ?? 'website';
    final isStandardSource = ['call', 'walk_in', 'website', 'referral', 'customer_conversion'].contains(leadSource);
    if (isStandardSource) {
      _source = leadSource;
    } else {
      _source = 'custom';
      _customSourceCtrl.text = leadSource;
    }
    
    // Status and follow-up
    _status = widget.lead['status'] ?? 'new';
    if (widget.lead['follow_up_date'] != null) {
      try {
        _followUpDate = DateTime.parse(widget.lead['follow_up_date']);
      } catch (_) {}
    }
    
    // Description
    _descriptionCtrl.text = widget.lead['description'] ?? '';
    
    // Assigned projects - handle both array and single project
    // Convert all project IDs to strings for consistent comparison
    final assignedProjects = widget.lead['assigned_projects'];
    if (assignedProjects != null && assignedProjects is List) {
      _selectedProjects = assignedProjects.map((p) {
        // Handle both Map objects and plain IDs
        if (p is Map) {
          return p['id'].toString();
        }
        return p.toString();
      }).toList();
      print('Populated selected projects: $_selectedProjects'); // Debug log
    } else if (widget.lead['assigned_project'] != null && widget.lead['assigned_project'] != 'none') {
      _selectedProjects = [widget.lead['assigned_project'].toString()];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _preferredLocationCtrl.dispose();
    _customSourceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final res = await ApiService.get('/projects/');
      if (mounted && res['success'] == true) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate reminder status requires follow-up date
    if (_status == 'reminder' && _followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reminder date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate custom source
    if (_source == 'custom' && _customSourceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom lead source'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final leadId = widget.lead['id'];
      if (leadId == null) {
        throw Exception('Lead ID not found');
      }

      // Prepare final source value
      final finalSource = _source == 'custom' ? _customSourceCtrl.text.trim() : _source;

      final body = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? '' : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? '' : _addressCtrl.text.trim(),
        'requirement_type': _requirementType,
        'bhk_requirement': _bhk,
        'budget_min': _budgetMinCtrl.text.trim().isEmpty ? 0 : double.tryParse(_budgetMinCtrl.text.trim()) ?? 0,
        'budget_max': _budgetMaxCtrl.text.trim().isEmpty ? 0 : double.tryParse(_budgetMaxCtrl.text.trim()) ?? 0,
        'preferred_location': _preferredLocationCtrl.text.trim().isEmpty ? '' : _preferredLocationCtrl.text.trim(),
        'source': finalSource,
        'status': _status,
        'assigned_to': widget.lead['assigned_to'] ?? widget.userData['id'], // Keep existing or assign to current user
        'assigned_projects': _selectedProjects.isNotEmpty ? _selectedProjects : [],
        'follow_up_date': _followUpDate?.toIso8601String(),
        'description': _descriptionCtrl.text.trim().isEmpty ? '' : _descriptionCtrl.text.trim(),
      };

      print('Updating lead $leadId with body: $body'); // Debug log

      final res = await ApiService.request(
        endpoint: '/leads/$leadId/',
        method: 'PUT',
        body: body,
      );

      print('API Response: $res'); // Debug log

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Lead updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onSave();
          Navigator.pop(context);
        } else {
          // Extract detailed error message
          String errorMsg = 'Failed to update lead';
          if (res['data'] != null) {
            if (res['data'] is Map) {
              final data = res['data'] as Map;
              if (data['detail'] != null) {
                errorMsg = data['detail'].toString();
              } else if (data['error'] != null) {
                errorMsg = data['error'].toString();
              } else {
                // Try to get field-specific errors
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
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Exception updating lead: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.95, // 95% of screen width for better visibility
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 500),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Lead',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Basic Information
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Full Name *',
                      hint: 'Enter full name',
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number *',
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      hint: 'Enter email address (optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressCtrl,
                      label: 'Address',
                      hint: 'Enter address (optional)',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),
                    // Lead Source
                    _buildSectionHeader('Lead Source'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Source',
                      value: _source,
                      items: _sourceOptions,
                      onChanged: (v) => setState(() => _source = v!),
                    ),
                    if (_source == 'custom') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _customSourceCtrl,
                        label: 'Custom Source *',
                        hint: 'e.g., Facebook Ad, Trade Show, LinkedIn',
                        validator: (v) => _source == 'custom' && (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Property Requirements
                    _buildSectionHeader('Property Requirements'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Requirement Type',
                            value: _requirementType,
                            items: const [
                              ('villa', 'Villa'),
                              ('apartment', 'Apartment'),
                              ('house', 'House'),
                              ('plot', 'Plot'),
                            ],
                            onChanged: (v) => setState(() => _requirementType = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            label: 'BHK Requirement',
                            value: _bhk,
                            items: const [
                              ('1', '1 BHK'),
                              ('2', '2 BHK'),
                              ('3', '3 BHK'),
                              ('4', '4 BHK'),
                              ('5+', '5+ BHK'),
                            ],
                            onChanged: (v) => setState(() => _bhk = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _budgetMinCtrl,
                            label: 'Minimum Budget (\$)',
                            hint: 'e.g., 100000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _budgetMaxCtrl,
                            label: 'Maximum Budget (\$)',
                            hint: 'e.g., 500000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _preferredLocationCtrl,
                      label: 'Preferred Location',
                      hint: 'e.g., Downtown, Suburb Area',
                    ),

                    const SizedBox(height: 20),
                    // Assigned Projects
                    _buildSectionHeader('Assigned Projects'),
                    const SizedBox(height: 12),
                    if (_loadingProjects)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      )
                    else if (_projects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'No projects available',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedProjects.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Selected: ${_selectedProjects.length}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _selectedProjects.clear()),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _projects.length,
                                itemBuilder: (_, i) {
                                  final project = _projects[i];
                                  final projectId = project['id'].toString();
                                  final isSelected = _selectedProjects.contains(projectId);
                                  return CheckboxListTile(
                                    title: Text(
                                      project['name'] ?? 'Project ${project['id']}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: project['location'] != null
                                        ? Text(
                                            project['location'],
                                            style: const TextStyle(fontSize: 11),
                                          )
                                        : null,
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedProjects.add(projectId);
                                        } else {
                                          _selectedProjects.remove(projectId);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    // Lead Management
                    _buildSectionHeader('Lead Management'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Status',
                      value: _status,
                      items: const [
                        ('new', 'New'),
                        ('hot', 'Hot'),
                        ('warm', 'Warm'),
                        ('cold', 'Cold'),
                        ('not_interested', 'Not Interested'),
                        ('reminder', 'Reminder'),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: _status == 'reminder' ? 'Follow-up Date *' : 'Follow-up Date',
                      value: _followUpDate,
                      onChanged: (date) => setState(() => _followUpDate = date),
                      enabled: _status == 'reminder',
                    ),
                    if (_status == 'reminder' && _followUpDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Reminder will appear on ${DateFormat('MMMM d, yyyy').format(_followUpDate!)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 20),
                    // Description / Notes
                    _buildSectionHeader('Description / Notes'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionCtrl,
                      label: 'Additional Notes',
                      hint: 'Add any additional notes or comments...',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Update Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _primary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
        prefixIcon: icon != null ? Icon(icon, color: _primary, size: 20) : null,
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<(String, String)> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
              items: items.map((item) => DropdownMenuItem(
                value: item.$1,
                child: Text(item.$2, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required void Function(DateTime?) onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: enabled ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value == null
                        ? 'mm/dd/yyyy'
                        : DateFormat('MM/dd/yyyy').format(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ),
                if (value != null && enabled)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _SortSheet - Sort Bottom Sheet for Leads
// ─────────────────────────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final String currentSort;
  final Function(String) onApply;

  const _SortSheet({
    required this.currentSort,
    required this.onApply,
  });

  static const Color _primary = Color(0xFF1565C0);

  static const _sortOptions = [
    ('-created_at', 'Newest First', Icons.new_releases_rounded),
    ('created_at', 'Oldest First', Icons.history_rounded),
    ('name', 'Name (A-Z)', Icons.sort_by_alpha_rounded),
    ('-name', 'Name (Z-A)', Icons.sort_by_alpha_rounded),
    ('status', 'Status', Icons.flag_rounded),
    ('-budget_max', 'Budget (High to Low)', Icons.attach_money_rounded),
    ('budget_max', 'Budget (Low to High)', Icons.attach_money_rounded),
    ('-follow_up_date', 'Follow-up Date (Latest)', Icons.event_rounded),
    ('follow_up_date', 'Follow-up Date (Earliest)', Icons.event_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.sort_rounded, color: _primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Sort By',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Sort options
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sortOptions.length,
            itemBuilder: (_, i) {
              final option = _sortOptions[i];
              final isSelected = currentSort == option.$1;
              return ListTile(
                leading: Icon(
                  option.$3,
                  color: isSelected ? _primary : Colors.grey[600],
                ),
                title: Text(
                  option.$2,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? _primary : Colors.black87,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: _primary)
                    : null,
                onTap: () {
                  onApply(option.$1);
                  Navigator.pop(context);
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _ConvertToTaskDialog - Convert Lead to Task Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConvertToTaskDialog extends StatefulWidget {
  final Map<String, dynamic> lead;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic> userData;
  final VoidCallback onSuccess;

  const _ConvertToTaskDialog({
    required this.lead,
    required this.projects,
    required this.userData,
    required this.onSuccess,
  });

  @override
  State<_ConvertToTaskDialog> createState() => _ConvertToTaskDialogState();
}

class _ConvertToTaskDialogState extends State<_ConvertToTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  
  String _status = 'in_progress';
  String _priority = 'medium';
  String? _selectedProject;
  DateTime? _visitDate;
  bool _loading = false;

  static const Color _primary = Color(0xFF1565C0);

  static const _statusOptions = [
    ('in_progress', 'In Progress'),
    ('site_visit', 'Site Visit'),
    ('family_visit', 'Family Visit'),
    ('perfect_family_visit', 'Perfect Family Visit'),
    ('completed', 'Completed'),
    ('rejected', 'Rejected'),
  ];

  static const _priorityOptions = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('urgent', 'Urgent'),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill notes with lead description
    _notesCtrl.text = widget.lead['description'] ?? '';
    
    // Set default project if available
    if (widget.projects.isNotEmpty) {
      _selectedProject = widget.projects[0]['id'].toString();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a project'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final companyId = widget.userData['company']?['id'];
      if (companyId == null) {
        throw Exception('Company ID not found');
      }

      final taskData = {
        'title': 'Task for ${widget.lead['name'] ?? 'Lead'}',
        'description': _notesCtrl.text.trim(),
        'lead': widget.lead['id'],
        'status': _status,
        'priority': _priority,
        'project': int.parse(_selectedProject!),
        'company': companyId,
        'assigned_to': widget.userData['id'],
        'due_date': _visitDate?.toIso8601String(),
      };

      print('Creating task with data: $taskData'); // Debug log

      final res = await ApiService.post('/tasks/', taskData);

      print('API Response: $res'); // Debug log

      if (mounted) {
        if (res['success'] == true) {
          // Close dialog first
          Navigator.pop(context);
          
          // Then call onSuccess to refresh the list
          widget.onSuccess();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Lead "${widget.lead['name']}" converted to task successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Extract error message
          String errorMsg = 'Failed to convert lead to task';
          if (res['data'] != null) {
            if (res['data'] is Map) {
              final data = res['data'] as Map;
              if (data['detail'] != null) {
                errorMsg = data['detail'].toString();
              } else if (data['error'] != null) {
                errorMsg = data['error'].toString();
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Exception converting lead to task: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.95,
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Convert to Task',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Fill in the task details for "convert"',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Assigned Project
                    _buildLabel('Assigned Project'),
                    const SizedBox(height: 8),
                    _buildProjectDropdown(),
                    
                    const SizedBox(height: 20),
                    // Status
                    _buildLabel('Status'),
                    const SizedBox(height: 8),
                    _buildStatusDropdown(),
                    
                    const SizedBox(height: 20),
                    // Priority
                    _buildLabel('Priority'),
                    const SizedBox(height: 8),
                    _buildPriorityDropdown(),
                    
                    const SizedBox(height: 20),
                    // Visit Date
                    _buildLabel('Visit Date'),
                    const SizedBox(height: 8),
                    _buildDateField(),
                    
                    const SizedBox(height: 20),
                    // Notes
                    _buildLabel('Notes'),
                    const SizedBox(height: 8),
                    _buildNotesField(),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Convert to Task', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProject,
          isExpanded: true,
          hint: const Text('No project', style: TextStyle(color: Colors.grey)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: [
            const DropdownMenuItem(value: null, child: Text('No project')),
            ...widget.projects.map((p) => DropdownMenuItem(
              value: p['id'].toString(),
              child: Text(p['name']?.toString() ?? 'Project ${p['id']}'),
            )),
          ],
          onChanged: (v) => setState(() => _selectedProject = v),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: _statusOptions.map((item) => DropdownMenuItem(
            value: item.$1,
            child: Text(item.$2),
          )).toList(),
          onChanged: (v) => setState(() => _status = v!),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _priority,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: _priorityOptions.map((item) => DropdownMenuItem(
            value: item.$1,
            child: Text(item.$2),
          )).toList(),
          onChanged: (v) => setState(() => _priority = v!),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _visitDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _visitDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _visitDate == null
                    ? 'Pick a date'
                    : DateFormat('MMM d, yyyy').format(_visitDate!),
                style: TextStyle(
                  fontSize: 15,
                  color: _visitDate == null ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            if (_visitDate != null)
              GestureDetector(
                onTap: () => setState(() => _visitDate = null),
                child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Add notes about this task...',
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}


