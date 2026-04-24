import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ASECallsTab
// ─────────────────────────────────────────────────────────────────────────────
class ASECallsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final VoidCallback? onLeadConverted;
  
  const ASECallsTab({
    super.key,
    required this.userData,
    required this.isManager,
    this.onLeadConverted,
  });

  @override
  State<ASECallsTab> createState() => _ASECallsTabState();
}

class _ASECallsTabState extends State<ASECallsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _calls = [];
  bool _loading = true;
  String _filter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Advanced filters
  String _statusFilter = 'all';
  String _callTypeFilter = 'all'; // all, overdue, today, upcoming
  DateTime? _dateFilter;
  String _assigneeFilter = 'all';
  List<String> _serviceFilter = [];
  
  // Status counts for filter badges
  Map<String, int> _statusCounts = {};
  
  // Available assignees (fetched from API)
  List<Map<String, dynamic>> _assignees = [];

  static const Color _primary = Color(0xFF1565C0);

  static const _statusColors = {
    'pending': Color(0xFFE65100),
    'answered': Color(0xFF2E7D32),
    'not_answered': Color(0xFFC62828),
    'busy': Color(0xFFF57F17),
    'not_interested': Color(0xFF757575),
    'custom': Color(0xFF6A1B9A),
  };

  static const _statusLabels = {
    'pending': 'Pending',
    'answered': 'Answered',
    'not_answered': 'Not Answered',
    'busy': 'Busy',
    'not_interested': 'Not Interested',
    'custom': 'Custom',
  };

  static const _serviceLabels = {
    'seo': 'SEO',
    'social_media': 'Social Media',
    'content_marketing': 'Content Marketing',
    'ppc': 'PPC',
    'email_marketing': 'Email Marketing',
    'web_design': 'Web Design',
    'branding': 'Branding',
    'analytics': 'Analytics',
    'influencer': 'Influencer',
    'video_marketing': 'Video Marketing',
    'custom': 'Custom',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCalls();
    _fetchAssignees();
  }
  
  Future<void> _fetchAssignees() async {
    try {
      final res = await ApiService.get('/accounts/users/?role=ase');
      if (mounted && res['success'] == true) {
        setState(() {
          _assignees = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? []
          );
        });
      }
    } catch (_) {
      // Silently fail, assignee filter will just show empty
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCalls() async {
    setState(() => _loading = true);
    try {
      String url = '/ase/customers/?page_size=500';  // Increased to show more calls
      
      // Apply filters
      if (_statusFilter != 'all') url += '&call_status=$_statusFilter';
      if (_search.isNotEmpty) url += '&search=$_search';
      if (_assigneeFilter != 'all') url += '&assigned_to=$_assigneeFilter';
      if (_dateFilter != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_dateFilter!);
        url += '&scheduled_date=$dateStr';
      }

      final res = await ApiService.get(url);
      if (mounted) {
        var list = (res['data']?['results'] ?? []) as List<dynamic>;
        
        // Apply client-side filters
        if (_callTypeFilter != 'all') {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          list = list.where((c) {
            final scheduledStr = c['scheduled_date'];
            if (scheduledStr == null) return _callTypeFilter == 'all';
            
            try {
              final scheduled = DateTime.parse(scheduledStr);
              final scheduledDate = DateTime(scheduled.year, scheduled.month, scheduled.day);
              
              switch (_callTypeFilter) {
                case 'overdue':
                  return scheduledDate.isBefore(today) && c['call_status'] == 'pending';
                case 'today':
                  return scheduledDate.isAtSameMomentAs(today);
                case 'upcoming':
                  return scheduledDate.isAfter(today);
                default:
                  return true;
              }
            } catch (_) {
              return false;
            }
          }).toList();
        }
        
        // Filter by service interests
        if (_serviceFilter.isNotEmpty) {
          list = list.where((c) {
            final services = c['service_interests'] as List? ?? [];
            return _serviceFilter.any((sf) => services.contains(sf));
          }).toList();
        }
        
        // Build status counts
        final counts = <String, int>{'all': list.length};
        for (final c in list) {
          final s = (c['call_status'] ?? 'pending') as String;
          counts[s] = (counts[s] ?? 0) + 1;
        }
        setState(() {
          _calls = list;
          _statusCounts = counts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = 'all';
      _callTypeFilter = 'all';
      _dateFilter = null;
      _assigneeFilter = 'all';
      _serviceFilter = [];
      _search = '';
      _searchCtrl.clear();
    });
    _fetchCalls();
  }
  
  bool get _hasActiveFilters {
    return _statusFilter != 'all' ||
        _callTypeFilter != 'all' ||
        _dateFilter != null ||
        _assigneeFilter != 'all' ||
        _serviceFilter.isNotEmpty ||
        _search.isNotEmpty;
  }

  // ── Import from Excel/CSV ──────────────────────────────────────────────────
  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final bytes = File(path).readAsBytesSync();
      final excel = xl.Excel.decodeBytes(bytes);

      final customers = <Map<String, dynamic>>[];
      for (final table in excel.tables.values) {
        // Skip header row (index 0)
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final name = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          final phone = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
          final email = row.length > 2 ? (row[2]?.value?.toString() ?? '') : '';
          final company = row.length > 3 ? (row[3]?.value?.toString() ?? '') : '';
          final notes = row.length > 4 ? (row[4]?.value?.toString() ?? '') : '';
          final servicesStr = row.length > 5 ? (row[5]?.value?.toString() ?? '') : '';
          
          if (name.isEmpty && phone.isEmpty) continue;
          
          // Parse service interests
          List<String> serviceInterests = [];
          if (servicesStr.isNotEmpty) {
            serviceInterests = servicesStr
                .split(',')
                .map((s) => s.trim().toLowerCase())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          
          customers.add({
            'name': name,
            'phone': phone,
            'email': email,
            'company_name': company,
            'notes': notes,
            if (serviceInterests.isNotEmpty) 'service_interests': serviceInterests,
          });
        }
        break; // Only first sheet
      }

      if (customers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid rows found in file.')),
          );
        }
        return;
      }

      final res = await ApiService.post(
          '/ase/customers/bulk_import/', {'customers': customers});
      if (mounted) {
        final ok = res['success'] == true;
        final msg = ok
            ? 'Imported ${customers.length} customers successfully.'
            : 'Import failed: ${res['data']?['detail'] ?? 'Unknown error'}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
        if (ok) _fetchCalls();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Download Template ──────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Template'];

      // Header row with instructions
      final headers = [
        'Name', 'Phone*', 'Email', 'Company Name', 'Notes', 'Service Interests (comma-separated)'
      ];
      
      // Add headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }

      // Add example row
      final exampleRow = [
        'John Doe',
        '+1234567890',
        'john@example.com',
        'ABC Corp',
        'Interested in SEO services',
        'seo,social_media,content_marketing'
      ];
      for (int j = 0; j < exampleRow.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1))
            .value = xl.TextCellValue(exampleRow[j]);
      }

      // Add instructions sheet
      final instructionsSheet = excel['Instructions'];
      final instructions = [
        ['ASE Tech Calls Import Template'],
        [''],
        ['Required Fields:'],
        ['- Phone: Phone number (REQUIRED - must be unique)'],
        [''],
        ['Optional Fields:'],
        ['- Name: Customer name'],
        ['- Email: Customer email address'],
        ['- Company Name: Customer company name'],
        ['- Notes: Any additional notes'],
        ['- Service Interests: Comma-separated list of services'],
        [''],
        ['Available Service Interests:'],
        ['seo, social_media, content_marketing, ppc, email_marketing,'],
        ['web_design, branding, analytics, influencer, video_marketing, custom'],
      ];

      for (int i = 0; i < instructions.length; i++) {
        for (int j = 0; j < instructions[i].length; j++) {
          instructionsSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
              .value = xl.TextCellValue(instructions[i][j]);
        }
      }

      // Save to Downloads directory
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
      final filePath = '${dir!.path}/ase_calls_template_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template saved to Downloads folder'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Template download error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Export to Excel ────────────────────────────────────────────────────────
  Future<void> _exportToExcel() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Calls'];

      // Header row
      final headers = [
        'Name', 'Phone', 'Email', 'Company', 'Status', 'Custom Status',
        'Service Interests', 'Custom Services', 'Assigned To', 'Scheduled Date',
        'Notes', 'Created At', 'Is Converted'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }

      // Data rows
      for (int i = 0; i < _calls.length; i++) {
        final c = _calls[i] as Map<String, dynamic>;
        
        // Format service interests
        String servicesStr = '';
        if (c['service_interests'] != null && c['service_interests'] is List) {
          servicesStr = (c['service_interests'] as List).join(', ');
        }
        
        final row = [
          c['name'] ?? '',
          c['phone'] ?? '',
          c['email'] ?? '',
          c['company_name'] ?? '',
          _statusLabels[c['call_status']] ?? (c['call_status'] ?? ''),
          c['custom_call_status'] ?? '',
          servicesStr,
          c['custom_services'] ?? '',
          c['assigned_to_name'] ?? '',
          c['scheduled_date'] ?? '',
          c['notes'] ?? '',
          c['created_at'] ?? '',
          c['is_converted'] == true ? 'Yes' : 'No',
        ];
        for (int j = 0; j < row.length; j++) {
          sheet
              .cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
      }

      // Save to Downloads directory
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
      final filePath = '${dir!.path}/calls_export_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${_calls.length} calls to Downloads folder'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            _buildSearchBar(),
            _buildCallsView(),
          ],
        ),
        // Floating Add Call Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _showAddCallForm,
            backgroundColor: _primary,
            icon: const Icon(Icons.phone_rounded, color: Colors.white),
            label: const Text('Add Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
              decoration: InputDecoration(
                hintText: 'Search by name, phone or company...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _primary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _fetchCalls();
                        })
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                if (v.isEmpty) _fetchCalls();
              },
              onSubmitted: (_) => _fetchCalls(),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button with badge
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? _primary : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
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

  Widget _buildCallsView() {
    return Expanded(
      child: Column(
        children: [
          // Stats bar
          _buildStatsBar(),
          // Import / Export action row
          _buildActionRow(),
          // Active filters display
          if (_hasActiveFilters) _buildActiveFilters(),
          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary))
                : _calls.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _fetchCalls,
                        color: _primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _calls.length,
                          itemBuilder: (_, i) => _buildCallCard(_calls[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActiveFilters() {
    final theme = Theme.of(context);
    
    final filters = <String>[];
    if (_statusFilter != 'all') filters.add(_statusLabels[_statusFilter] ?? _statusFilter);
    if (_callTypeFilter != 'all') filters.add(_callTypeFilter.toUpperCase());
    if (_dateFilter != null) filters.add(DateFormat('MMM dd').format(_dateFilter!));
    if (_assigneeFilter != 'all') {
      final assignee = _assignees.firstWhere(
        (a) => a['id'].toString() == _assigneeFilter,
        orElse: () => {'username': 'Assignee'},
      );
      filters.add(assignee['username'] ?? 'Assignee');
    }
    if (_serviceFilter.isNotEmpty) {
      filters.add('${_serviceFilter.length} service${_serviceFilter.length > 1 ? 's' : ''}');
    }
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
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
          ),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final theme = Theme.of(context);
    
    final total = _statusCounts['all'] ?? _calls.length;
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.phone_rounded, size: 16, color: _primary),
          const SizedBox(width: 6),
          Text(
            'Total: $total calls',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primary),
          ),
          const Spacer(),
          if (_filter != 'all') ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (_statusColors[_filter] ?? _primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_statusLabels[_filter] ?? _filter}: ${_statusCounts[_filter] ?? 0}',
                style: TextStyle(
                    fontSize: 11,
                    color: _statusColors[_filter] ?? _primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
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
              onPressed: _downloadTemplate,
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
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export', style: TextStyle(fontSize: 13)),
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        statusFilter: _statusFilter,
        callTypeFilter: _callTypeFilter,
        dateFilter: _dateFilter,
        assigneeFilter: _assigneeFilter,
        serviceFilter: _serviceFilter,
        assignees: _assignees,
        onApply: (status, callType, date, assignee, services) {
          setState(() {
            _statusFilter = status;
            _callTypeFilter = callType;
            _dateFilter = date;
            _assigneeFilter = assignee;
            _serviceFilter = services;
          });
          _fetchCalls();
        },
        onClear: _clearFilters,
      ),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> call) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final status = call['call_status'] ?? 'pending';
    final color = _statusColors[status] ?? _primary;
    final name = call['name'] ?? 'Unknown';
    final phone = call['phone'] ?? '';
    final company = call['company_name'] ?? '';
    final services = call['service_interests'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, color: color, size: 22),
        ),
        title: Text(name,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: theme.colorScheme.onSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              Text(phone,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            if (company.isNotEmpty)
              Text(company,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: services.take(3).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _serviceLabels[s.toString()] ?? s.toString(),
                    style: TextStyle(fontSize: 9, color: _primary.withOpacity(0.8)),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  _statusLabels[status] ??
                      status.replaceAll('_', ' '),
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
            if (call['is_converted'] == true) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Colors.green),
                    SizedBox(width: 3),
                    Text('Lead', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            if (call['assigned_to_name'] != null && call['is_converted'] != true) ...[
              const SizedBox(height: 4),
              Text(call['assigned_to_name'].toString(),
                  style: TextStyle(
                      fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
        onTap: () => _showCallDetail(call),
      ),
    );
  }

  void _showCallDetail(Map<String, dynamic> call) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CallDetailSheet(
        call: call,
        onRefresh: _fetchCalls,
        onLeadConverted: widget.onLeadConverted,
        onEdit: () {
          Navigator.pop(context); // Close detail sheet
          _showEditCallForm(call); // Open edit form
        },
        onDelete: () async {
          Navigator.pop(context); // Close detail sheet
          await _deleteCall(call);
        },
      ),
    );
  }

  void _showEditCallForm(Map<String, dynamic> call) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CallFormSheet(
        call: call,
        onSaved: _fetchCalls,
        userData: widget.userData,
      ),
    );
  }

  Future<void> _deleteCall(Map<String, dynamic> call) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Call'),
        content: Text('Are you sure you want to delete ${call['name'] ?? call['phone']}?'),
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
      final id = call['id'];
      final res = await ApiService.request(
        endpoint: '/ase/customers/$id/',
        method: 'DELETE',
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchCalls();
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

  void _showAddCallForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CallFormSheet(
        onSaved: _fetchCalls,
        userData: widget.userData,
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_missed_rounded,
              size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No calls found',
              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showAddCallForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CallFormSheet  (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────
class _CallFormSheet extends StatefulWidget {
  final Map<String, dynamic>? call; // null = add, non-null = edit
  final VoidCallback onSaved;
  final Map<String, dynamic> userData;
  const _CallFormSheet({this.call, required this.onSaved, required this.userData});

  @override
  State<_CallFormSheet> createState() => _CallFormSheetState();
}

class _CallFormSheetState extends State<_CallFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _customStatusCtrl;
  late final TextEditingController _customServicesCtrl;

  String _callStatus = 'pending';
  DateTime? _scheduledDate;
  List<String> _serviceInterests = [];
  bool _saving = false;

  static const Color _primary = Color(0xFF1565C0);

  static const _callStatusOptions = [
    'pending',
    'answered',
    'not_answered',
    'busy',
    'not_interested',
    'custom',
  ];

  static const _serviceOptions = [
    'seo',
    'social_media',
    'content_marketing',
    'ppc',
    'email_marketing',
    'web_design',
    'branding',
    'analytics',
    'influencer',
    'video_marketing',
    'custom',
  ];

  static const _serviceLabels = {
    'seo': 'SEO',
    'social_media': 'Social Media',
    'content_marketing': 'Content Marketing',
    'ppc': 'PPC',
    'email_marketing': 'Email Marketing',
    'web_design': 'Web Design',
    'branding': 'Branding',
    'analytics': 'Analytics',
    'influencer': 'Influencer',
    'video_marketing': 'Video Marketing',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    final c = widget.call;
    _nameCtrl = TextEditingController(text: c?['name'] ?? '');
    _phoneCtrl = TextEditingController(text: c?['phone'] ?? '');
    _emailCtrl = TextEditingController(text: c?['email'] ?? '');
    _companyCtrl = TextEditingController(text: c?['company_name'] ?? '');
    _notesCtrl = TextEditingController(text: c?['notes'] ?? '');
    _customStatusCtrl =
        TextEditingController(text: c?['custom_call_status'] ?? '');
    _customServicesCtrl =
        TextEditingController(text: c?['custom_services'] ?? '');
    _callStatus = c?['call_status'] ?? 'pending';
    if (c?['service_interests'] != null) {
      _serviceInterests =
          List<String>.from(c!['service_interests'] as List);
    }
    if (c?['scheduled_date'] != null) {
      try {
        _scheduledDate = DateTime.parse(c!['scheduled_date'] as String);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    _customStatusCtrl.dispose();
    _customServicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'phone': _phoneCtrl.text.trim(), // REQUIRED
      };
      
      // Add company ID from userData (REQUIRED by backend)
      final company = widget.userData['company'];
      if (company is Map && company['id'] != null) {
        body['company'] = company['id'];
      }
      
      // Add optional fields only if they have values
      if (_nameCtrl.text.trim().isNotEmpty) {
        body['name'] = _nameCtrl.text.trim();
      }
      if (_emailCtrl.text.trim().isNotEmpty) {
        body['email'] = _emailCtrl.text.trim();
      }
      if (_companyCtrl.text.trim().isNotEmpty) {
        body['company_name'] = _companyCtrl.text.trim();
      }
      if (_notesCtrl.text.trim().isNotEmpty) {
        body['notes'] = _notesCtrl.text.trim();
      }
      
      // Call status
      body['call_status'] = _callStatus;
      if (_callStatus == 'custom' && _customStatusCtrl.text.trim().isNotEmpty) {
        body['custom_call_status'] = _customStatusCtrl.text.trim();
      }
      
      // Service interests
      if (_serviceInterests.isNotEmpty) {
        body['service_interests'] = _serviceInterests;
      }
      if (_serviceInterests.contains('custom') && _customServicesCtrl.text.trim().isNotEmpty) {
        body['custom_services'] = _customServicesCtrl.text.trim();
      }
      
      // Scheduled date
      if (_scheduledDate != null) {
        body['scheduled_date'] = DateFormat('yyyy-MM-dd').format(_scheduledDate!);
      }

      final Map<String, dynamic> res;
      if (widget.call == null) {
        res = await ApiService.post('/ase/customers/', body);
      } else {
        final id = widget.call!['id'];
        res = await ApiService.request(
            endpoint: '/ase/customers/$id/',
            method: 'PATCH',
            body: body);
      }

      if (mounted) {
        if (res['success'] == true) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.call == null
                  ? 'Call added successfully.'
                  : 'Call updated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Show detailed error message
          String errorMsg = 'Unknown error';
          if (res['data'] != null) {
            if (res['data'] is Map) {
              final errors = res['data'] as Map;
              if (errors['detail'] != null) {
                errorMsg = errors['detail'].toString();
              } else {
                // Show field-specific errors
                final errorList = <String>[];
                errors.forEach((key, value) {
                  if (value is List) {
                    errorList.add('$key: ${value.join(', ')}');
                  } else {
                    errorList.add('$key: $value');
                  }
                });
                errorMsg = errorList.join('\n');
              }
            } else {
              errorMsg = res['data'].toString();
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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
              duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.call != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Call' : 'Add New Call',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Name (optional)
                _field(_nameCtrl, 'Name', Icons.person_rounded),
                const SizedBox(height: 12),

                // Phone (REQUIRED)
                _field(_phoneCtrl, 'Phone', Icons.phone_rounded,
                    keyboardType: TextInputType.phone, required: true),
                const SizedBox(height: 12),

                // Email
                _field(_emailCtrl, 'Email', Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),

                // Company
                _field(_companyCtrl, 'Company Name',
                    Icons.business_rounded),
                const SizedBox(height: 12),

                // Call Status dropdown
                _buildCallStatusDropdown(),
                const SizedBox(height: 12),

                // Custom call status (conditional)
                if (_callStatus == 'custom') ...[
                  _field(_customStatusCtrl, 'Custom Status Label',
                      Icons.label_rounded),
                  const SizedBox(height: 12),
                ],

                // Scheduled Date
                _buildDateField(),
                const SizedBox(height: 12),

                // Service Interests
                _buildServiceInterests(),
                const SizedBox(height: 12),

                // Custom services (conditional)
                if (_serviceInterests.contains('custom')) ...[
                  _field(_customServicesCtrl, 'Custom Service Details',
                      Icons.miscellaneous_services_rounded),
                  const SizedBox(height: 12),
                ],

                // Notes
                _field(_notesCtrl, 'Notes', Icons.notes_rounded,
                    maxLines: 3),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(isEdit ? 'Update' : 'Save',
                            style: const TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }

  Widget _buildCallStatusDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: _callStatus,
      decoration: InputDecoration(
        labelText: 'Call Status',
        prefixIcon:
            const Icon(Icons.flag_rounded, color: _primary, size: 20),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: _callStatusOptions
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _callStatus = v);
      },
    );
  }

  Widget _buildDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'Scheduled Date',
            prefixIcon: const Icon(Icons.calendar_today_rounded,
                color: _primary, size: 20),
            hintText: _scheduledDate == null
                ? 'Select date'
                : DateFormat('dd MMM yyyy').format(_scheduledDate!),
            filled: false,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primary, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          controller: TextEditingController(
            text: _scheduledDate == null
                ? ''
                : DateFormat('dd MMM yyyy').format(_scheduledDate!),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInterests() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Interests',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _serviceOptions.map((s) {
            final selected = _serviceInterests.contains(s);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _serviceInterests.remove(s);
                  } else {
                    _serviceInterests.add(s);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? _primary
                      : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? _primary
                          : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                ),
                child: Text(
                  _serviceLabels[s] ?? s,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CallDetailSheet  (View + Notes + Call Logs)
// ─────────────────────────────────────────────────────────────────────────────
class _CallDetailSheet extends StatefulWidget {
  final Map<String, dynamic> call;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLeadConverted;
  
  const _CallDetailSheet({
    required this.call,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    this.onLeadConverted,
  });

  @override
  State<_CallDetailSheet> createState() => _CallDetailSheetState();
}

class _CallDetailSheetState extends State<_CallDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _notes = [];
  List<dynamic> _logs = [];
  bool _loadingNotes = true;
  bool _loadingLogs = true;
  final _noteCtrl = TextEditingController();
  bool _addingNote = false;

  static const Color _primary = Color(0xFF1565C0);

  static const _statusColors = {
    'pending': Color(0xFFE65100),
    'answered': Color(0xFF2E7D32),
    'not_answered': Color(0xFFC62828),
    'busy': Color(0xFFF57F17),
    'not_interested': Color(0xFF757575),
    'custom': Color(0xFF6A1B9A),
  };

  static const _statusLabels = {
    'pending': 'Pending',
    'answered': 'Answered',
    'not_answered': 'Not Answered',
    'busy': 'Busy',
    'not_interested': 'Not Interested',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchNotes();
    _fetchLogs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    setState(() => _loadingNotes = true);
    try {
      final id = widget.call['id'];
      final res = await ApiService.get('/ase/customers/$id/notes_history/');
      if (mounted) {
        setState(() {
          _notes = res['data'] is List
              ? res['data'] as List
              : (res['data']?['results'] ?? []);
          _loadingNotes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final id = widget.call['id'];
      final res = await ApiService.get('/ase/customers/$id/call_logs/');
      if (mounted) {
        setState(() {
          _logs = res['data'] is List
              ? res['data'] as List
              : (res['data']?['results'] ?? []);
          _loadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final status = call['call_status'] ?? 'pending';
    final color = _statusColors[status] ?? _primary;
    final name = call['name'] ?? 'Unknown';
    final phone = call['phone'] ?? '';
    final email = call['email'] ?? '';
    final company = call['company_name'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.person_rounded,
                          color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface)),
                          if (company.isNotEmpty)
                            Text(company,
                                style: TextStyle(
                                    fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // Action buttons
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: _primary),
                      onPressed: widget.onEdit,
                      tooltip: 'Edit',
                    ),
                    if (call['is_converted'] != true)
                      IconButton(
                        icon: const Icon(Icons.trending_up_rounded, color: Colors.green),
                        onPressed: () => _showConvertDialog(call),
                        tooltip: 'Convert to Lead',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick Status Change
                _buildQuickStatusChange(call),
                const SizedBox(height: 12),
                // Quick Action Buttons (Call & WhatsApp)
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
                const SizedBox(height: 12),
                if (phone.isNotEmpty)
                  _infoRow(Icons.phone_rounded, phone),
                if (email.isNotEmpty)
                  _infoRow(Icons.email_rounded, email),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            labelColor: _primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: _primary,
            tabs: const [
              Tab(text: 'Details'),
              Tab(text: 'Notes'),
              Tab(text: 'Call Logs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildDetailsTab(call),
                _buildNotesTab(),
                _buildCallLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusChange(Map<String, dynamic> call) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentStatus = call['call_status'] ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, size: 18, color: _primary),
          const SizedBox(width: 10),
          const Text('Status:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: currentStatus,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _statusLabels.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (newStatus) async {
                if (newStatus != null && newStatus != currentStatus) {
                  await _updateCallStatus(call['id'], newStatus);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCallStatus(int callId, String newStatus) async {
    try {
      final res = await ApiService.request(
        endpoint: '/ase/customers/$callId/',
        method: 'PATCH',
        body: {'call_status': newStatus},
      );
      if (mounted && res['success'] == true) {
        setState(() {
          widget.call['call_status'] = newStatus;
        });
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConvertDialog(Map<String, dynamic> call) {
    final contactCtrl = TextEditingController(text: call['name'] ?? '');
    final companyCtrl = TextEditingController(text: call['company_name'] ?? '');
    final websiteCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final currentAgencyCtrl = TextEditingController();
    final goalsCtrl = TextEditingController(text: call['notes'] ?? '');
    final customServicesCtrl = TextEditingController(text: call['custom_services'] ?? '');
    
    String selectedIndustry = 'technology';
    String selectedStatus = 'new';
    String selectedPriority = 'medium';
    List<String> selectedServices = List<String>.from(call['service_interests'] ?? []);
    bool hasWebsite = false;
    bool hasSocialMedia = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Convert to Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Information Section
                  const Text('Company Information', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contactCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contact Person *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: companyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Company Name *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedIndustry,
                    decoration: InputDecoration(
                      labelText: 'Industry *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'technology', child: Text('Technology')),
                      DropdownMenuItem(value: 'healthcare', child: Text('Healthcare')),
                      DropdownMenuItem(value: 'finance', child: Text('Finance')),
                      DropdownMenuItem(value: 'retail', child: Text('Retail & E-commerce')),
                      DropdownMenuItem(value: 'real_estate', child: Text('Real Estate')),
                      DropdownMenuItem(value: 'education', child: Text('Education')),
                      DropdownMenuItem(value: 'hospitality', child: Text('Hospitality & Tourism')),
                      DropdownMenuItem(value: 'manufacturing', child: Text('Manufacturing')),
                      DropdownMenuItem(value: 'professional_services', child: Text('Professional Services')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => selectedIndustry = v ?? 'technology'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: websiteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Website',
                      hintText: 'https://example.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  
                  // Service Interests Section
                  const SizedBox(height: 20),
                  const Text('Service Interests *', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'seo', 'social_media', 'content_marketing', 'ppc', 
                      'email_marketing', 'web_design', 'branding', 'analytics',
                      'influencer', 'video_marketing', 'custom'
                    ].map((s) {
                      final labels = {
                        'seo': 'SEO',
                        'social_media': 'Social Media',
                        'content_marketing': 'Content Marketing',
                        'ppc': 'PPC',
                        'email_marketing': 'Email Marketing',
                        'web_design': 'Web Design',
                        'branding': 'Branding',
                        'analytics': 'Analytics',
                        'influencer': 'Influencer',
                        'video_marketing': 'Video Marketing',
                        'custom': 'Custom',
                      };
                      final selected = selectedServices.contains(s);
                      return FilterChip(
                        label: Text(labels[s]!, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        selectedColor: const Color(0xFF1565C0).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF1565C0),
                        onSelected: (bool value) {
                          setState(() {
                            if (value) {
                              selectedServices.add(s);
                            } else {
                              selectedServices.remove(s);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedServices.contains('custom')) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customServicesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Custom Services',
                        hintText: 'Specify other services...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                  
                  // Budget & Marketing Section
                  const SizedBox(height: 20),
                  const Text('Budget & Marketing', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: budgetCtrl,
                    decoration: InputDecoration(
                      labelText: 'Budget Amount (Monthly)',
                      hintText: 'e.g., ₹2,00,000 per month',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currentAgencyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Current SEO Agency',
                      hintText: 'Current agency name (if any)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Has existing website', style: TextStyle(fontSize: 14)),
                    value: hasWebsite,
                    onChanged: (v) => setState(() => hasWebsite = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text('Has social media presence', style: TextStyle(fontSize: 14)),
                    value: hasSocialMedia,
                    onChanged: (v) => setState(() => hasSocialMedia = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Marketing Goals',
                      hintText: 'Describe their marketing goals and objectives...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  
                  // Lead Classification Section
                  const SizedBox(height: 20),
                  const Text('Lead Classification', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Lead Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New Lead')),
                      DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                      DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
                    ],
                    onChanged: (v) => setState(() => selectedStatus = v ?? 'new'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (v) => setState(() => selectedPriority = v ?? 'medium'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: () {
                if (companyCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Company name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (selectedServices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one service interest'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _convertToLead(call, {
                  'company_name': companyCtrl.text.trim(),
                  'industry': selectedIndustry,
                  'service_interests': selectedServices,
                  'custom_services': customServicesCtrl.text.trim(),
                  'budget_amount': budgetCtrl.text.trim(),
                  'current_seo_agency': currentAgencyCtrl.text.trim(),
                  'marketing_goals': goalsCtrl.text.trim(),
                  'website': websiteCtrl.text.trim(),
                  'has_website': hasWebsite,
                  'has_social_media': hasSocialMedia,
                  'status': selectedStatus,
                  'priority': selectedPriority,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Convert to Lead', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertToLead(Map<String, dynamic> call, Map<String, dynamic> leadData) async {
    try {
      // Prepare lead data matching the backend's convert_to_lead endpoint
      final body = {
        'company_name': leadData['company_name'],
        'industry': leadData['industry'],
        'service_interests': leadData['service_interests'], // Already a list
        'budget_amount': leadData['budget_amount'],
        'marketing_goals': leadData['marketing_goals'],
        'website': leadData['website'],
        'has_website': leadData['has_website'],
        'has_social_media': leadData['has_social_media'],
        'current_seo_agency': leadData['current_seo_agency'],
        'status': leadData['status'],
        'priority': leadData['priority'],
      };
      
      // Remove empty strings to avoid validation errors
      body.removeWhere((key, value) => value is String && value.trim().isEmpty);
      
      // Use the customer's convert_to_lead endpoint (not direct lead creation)
      final res = await ApiService.post('/ase/customers/${call['id']}/convert_to_lead/', body);
      
      if (mounted) {
        if (res['success'] == true) {
          // Refresh calls list via callback
          widget.onRefresh();
          
          // Notify parent to refresh leads tab
          widget.onLeadConverted?.call();
          
          Navigator.pop(context); // Close detail sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Successfully converted to lead! Lead ID: ${res['data']?['lead_id']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          String errorMsg = 'Failed to convert';
          if (res['data'] != null) {
            if (res['data']['error'] != null) {
              errorMsg = res['data']['error'].toString();
            } else if (res['data']['details'] != null) {
              errorMsg = res['data']['details'].toString();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting to lead: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _makePhoneCall(String phone) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone call'),
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

  void _openWhatsApp(String phone) async {
    try {
      // Remove any non-digit characters from phone
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
      
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed'),
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

  Widget _infoRow(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> call) {
    final theme = Theme.of(context);
    
    final services = call['service_interests'] as List? ?? [];
    final scheduledDate = call['scheduled_date'];
    final notes = call['notes'] ?? '';
    final customStatus = call['custom_call_status'] ?? '';
    final customServices = call['custom_services'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (call['assigned_to_name'] != null)
            _detailRow('Assigned To', call['assigned_to_name'].toString()),
          if (scheduledDate != null)
            _detailRow('Scheduled', scheduledDate.toString()),
          if (customStatus.isNotEmpty)
            _detailRow('Custom Status', customStatus),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Service Interests',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: services
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _primary.withOpacity(0.2)),
                        ),
                        child: Text(s.toString().replaceAll('_', ' '),
                            style: const TextStyle(
                                fontSize: 11, color: _primary)),
                      ))
                  .toList(),
            ),
          ],
          if (customServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailRow('Custom Services', customServices),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Notes',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 6),
            Text(notes,
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13,
                      color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }

  // ── Notes Tab ──────────────────────────────────────────────────────────────
  Widget _buildNotesTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        Expanded(
          child: _loadingNotes
              ? const Center(
                  child: CircularProgressIndicator(color: _primary))
              : _notes.isEmpty
                  ? const Center(child: Text('No notes yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final note = _notes[i] as Map<String, dynamic>;
                        // Issue 3 fix: use content field
                        final content = note['content'] ??
                            note['note'] ??
                            note['text'] ??
                            '';
                        // Issue 3 fix: use author_name
                        final author =
                            note['author_name'] ?? note['created_by_name'] ?? '';
                        final date = note['created_at'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(content,
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (author.isNotEmpty)
                                    Text(author,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _primary,
                                            fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(date,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        _buildAddNoteBar(),
      ],
    );
  }

  Widget _buildAddNoteBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _addingNote
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _primary))
              : IconButton(
                  onPressed: _submitNote,
                  icon: const Icon(Icons.send_rounded, color: _primary),
                ),
        ],
      ),
    );
  }

  Future<void> _submitNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _addingNote = true);
    try {
      final id = widget.call['id'];
      // Use 'content' key as per backend
      final res = await ApiService.post(
          '/ase/customers/$id/notes_history/', {'content': text});
      if (mounted) {
        if (res['success'] == true) {
          _noteCtrl.clear();
          _fetchNotes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error: ${res['data']?['detail'] ?? 'Failed to add note'}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _addingNote = false);
    }
  }

  // ── Call Log Tab ───────────────────────────────────────────────────────────
  Widget _buildCallLogTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return _loadingLogs
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : _logs.isEmpty
            ? const Center(child: Text('No call logs yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final log = _logs[i] as Map<String, dynamic>;
                  // Issue 4 fixes
                  final date =
                      log['called_at'] ?? log['created_at'] ?? '';
                  final by =
                      log['called_by_name'] ?? log['called_by'] ?? '';
                  final status =
                      log['call_status'] ?? log['status'] ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: _primary.withOpacity(0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.phone_rounded,
                              color: _primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (by.isNotEmpty)
                                Text(by,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface)),
                              if (date.isNotEmpty)
                                Text(date,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _primary.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(20)),
                            child: Text(
                                status.toString().replaceAll('_', ' '),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: _primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  );
                },
              );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _FilterSheet - Advanced Filter Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final String statusFilter;
  final String callTypeFilter;
  final DateTime? dateFilter;
  final String assigneeFilter;
  final List<String> serviceFilter;
  final List<Map<String, dynamic>> assignees;
  final Function(String, String, DateTime?, String, List<String>) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.statusFilter,
    required this.callTypeFilter,
    required this.dateFilter,
    required this.assigneeFilter,
    required this.serviceFilter,
    required this.assignees,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  late String _callType;
  late DateTime? _date;
  late String _assignee;
  late List<String> _services;

  static const Color _primary = Color(0xFF1565C0);

  static const _statusOptions = [
    ('all', 'All Status'),
    ('pending', 'Pending'),
    ('answered', 'Answered'),
    ('not_answered', 'Not Answered'),
    ('busy', 'Busy'),
    ('not_interested', 'Not Interested'),
    ('custom', 'Custom'),
  ];

  static const _callTypeOptions = [
    ('all', 'All Calls'),
    ('overdue', 'Overdue'),
    ('today', 'Today'),
    ('upcoming', 'Upcoming'),
  ];

  static const _serviceOptions = [
    'seo',
    'social_media',
    'content_marketing',
    'ppc',
    'email_marketing',
    'web_design',
    'branding',
    'analytics',
    'influencer',
    'video_marketing',
    'custom',
  ];

  static const _serviceLabels = {
    'seo': 'SEO',
    'social_media': 'Social Media',
    'content_marketing': 'Content Marketing',
    'ppc': 'PPC',
    'email_marketing': 'Email Marketing',
    'web_design': 'Web Design',
    'branding': 'Branding',
    'analytics': 'Analytics',
    'influencer': 'Influencer',
    'video_marketing': 'Video Marketing',
    'custom': 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _callType = widget.callTypeFilter;
    _date = widget.dateFilter;
    _assignee = widget.assigneeFilter;
    _services = List.from(widget.serviceFilter);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
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
                    'Filter Calls',
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
                  // Call Type (Overdue, Today, etc.)
                  _buildSectionTitle('Call Type', Icons.schedule_rounded),
                  const SizedBox(height: 8),
                  _buildCallTypeChips(),
                  const SizedBox(height: 20),

                  // Status
                  _buildSectionTitle('Status', Icons.flag_rounded),
                  const SizedBox(height: 8),
                  _buildStatusChips(),
                  const SizedBox(height: 20),

                  // Date
                  _buildSectionTitle('Scheduled Date', Icons.calendar_today_rounded),
                  const SizedBox(height: 8),
                  _buildDatePicker(),
                  const SizedBox(height: 20),

                  // Assignee
                  _buildSectionTitle('Assigned To', Icons.person_rounded),
                  const SizedBox(height: 8),
                  _buildAssigneeDropdown(),
                  const SizedBox(height: 20),

                  // Service Interests
                  _buildSectionTitle('Service Interests', Icons.interests_rounded),
                  const SizedBox(height: 8),
                  _buildServiceChips(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // Apply button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
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
                      widget.onApply(_status, _callType, _date, _assignee, _services);
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCallTypeChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _callTypeOptions.map((opt) {
        final isSelected = _callType == opt.$1;
        Color chipColor;
        switch (opt.$1) {
          case 'overdue':
            chipColor = const Color(0xFFD32F2F);
            break;
          case 'today':
            chipColor = const Color(0xFFF57C00);
            break;
          case 'upcoming':
            chipColor = const Color(0xFF388E3C);
            break;
          default:
            chipColor = _primary;
        }

        return GestureDetector(
          onTap: () => setState(() => _callType = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? chipColor : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? chipColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (opt.$1 == 'overdue')
                  const Icon(Icons.warning_rounded, size: 16, color: Colors.white)
                else if (opt.$1 == 'today')
                  Icon(Icons.today_rounded, size: 16, color: isSelected ? Colors.white : chipColor)
                else if (opt.$1 == 'upcoming')
                  Icon(Icons.upcoming_rounded, size: 16, color: isSelected ? Colors.white : chipColor),
                if (opt.$1 != 'all') const SizedBox(width: 6),
                Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
              color: isSelected ? _primary : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 20, color: _primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _date == null
                    ? 'Select date'
                    : DateFormat('EEEE, MMM dd, yyyy').format(_date!),
                style: TextStyle(
                  fontSize: 14,
                  color: _date == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (_date != null)
              GestureDetector(
                onTap: () => setState(() => _date = null),
                child: Icon(Icons.clear_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final assigneeOptions = [
      {'id': 'all', 'username': 'All Assignees'},
      ...widget.assignees,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _assignee,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
          items: assigneeOptions.map((a) {
            final id = a['id'].toString();
            final name = a['username'] ?? a['first_name'] ?? 'Unknown';
            return DropdownMenuItem(
              value: id,
              child: Text(
                name,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _assignee = v);
          },
        ),
      ),
    );
  }

  Widget _buildServiceChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _serviceOptions.map((service) {
        final isSelected = _services.contains(service);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _services.remove(service);
              } else {
                _services.add(service);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _primary : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                if (isSelected) const SizedBox(width: 4),
                Text(
                  _serviceLabels[service] ?? service,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
