import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';

class ASELeadsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  const ASELeadsTab({super.key, required this.userData, required this.isManager});

  @override
  State<ASELeadsTab> createState() => _ASELeadsTabState();
}

class _ASELeadsTabState extends State<ASELeadsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _leads = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Advanced filters
  String _statusFilter = '';
  String _priorityFilter = '';
  String _industryFilter = '';
  String _createdByFilter = '';
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 50;
  
  // Available creators (for filter)
  List<Map<String, dynamic>> _creators = [];

  static const Color _primary = Color(0xFF1565C0);

  final _statusColors = const {
    'new':           Color(0xFF1565C0),
    'contacted':     Color(0xFF6A1B9A),
    'qualified':     Color(0xFF2E7D32),
    'proposal_sent': Color(0xFFE65100),
    'negotiating':   Color(0xFFF57F17),
    'won':           Color(0xFF1B5E20),
    'lost':          Color(0xFFC62828),
    'on_hold':       Color(0xFF757575),
    'nurturing':     Color(0xFF00838F),
  };

  final _statusLabels = const {
    'new':           'New',
    'contacted':     'Contacted',
    'qualified':     'Qualified',
    'proposal_sent': 'Proposal Sent',
    'negotiating':   'Negotiating',
    'won':           'Won',
    'lost':          'Lost',
    'on_hold':       'On Hold',
    'nurturing':     'Nurturing',
  };
  
  static const _industryLabels = {
    'technology': 'Technology',
    'healthcare': 'Healthcare',
    'finance': 'Finance',
    'retail': 'Retail & E-commerce',
    'real_estate': 'Real Estate',
    'education': 'Education',
    'hospitality': 'Hospitality & Tourism',
    'manufacturing': 'Manufacturing',
    'professional_services': 'Professional Services',
    'non_profit': 'Non-Profit',
    'automotive': 'Automotive',
    'food_beverage': 'Food & Beverage',
    'fashion': 'Fashion & Beauty',
    'sports_fitness': 'Sports & Fitness',
    'entertainment': 'Entertainment & Media',
    'other': 'Other',
  };
  
  static const _priorityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'urgent': 'Urgent',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchLeads();
    _fetchCreators();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _fetchCreators() async {
    try {
      final res = await ApiService.get('/accounts/users/?role=ase');
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

  Future<void> _fetchLeads() async {
    setState(() => _loading = true);
    try {
      String url = '/ase-leads/?page=$_currentPage&page_size=$_pageSize';
      
      // Apply filters
      if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
      if (_priorityFilter.isNotEmpty) url += '&priority=$_priorityFilter';
      if (_industryFilter.isNotEmpty) url += '&industry=$_industryFilter';
      if (_createdByFilter.isNotEmpty) url += '&created_by=$_createdByFilter';
      if (_search.isNotEmpty) url += '&search=$_search';

      final res = await ApiService.get(url);
      if (mounted) {
        final data = res['data'];
        setState(() {
          _leads = data?['results'] ?? [];
          _totalCount = data?['count'] ?? 0;
          _totalPages = (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = '';
      _priorityFilter = '';
      _industryFilter = '';
      _createdByFilter = '';
      _search = '';
      _searchCtrl.clear();
      _currentPage = 1;
    });
    _fetchLeads();
  }
  
  bool get _hasActiveFilters {
    return _statusFilter.isNotEmpty ||
        _priorityFilter.isNotEmpty ||
        _industryFilter.isNotEmpty ||
        _createdByFilter.isNotEmpty ||
        _search.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                          onRefresh: _fetchLeads,
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by company or contact...',
                prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _fetchLeads();
                        })
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                if (v.isEmpty) _fetchLeads();
              },
              onSubmitted: (_) => _fetchLeads(),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button with badge
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? _primary : const Color(0xFFF5F6FA),
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
        priorityFilter: _priorityFilter,
        industryFilter: _industryFilter,
        createdByFilter: _createdByFilter,
        creators: _creators,
        isManager: widget.isManager,
        onApply: (status, priority, industry, createdBy) {
          setState(() {
            _statusFilter = status;
            _priorityFilter = priority;
            _industryFilter = industry;
            _createdByFilter = createdBy;
            _currentPage = 1;
          });
          _fetchLeads();
        },
        onClear: _clearFilters,
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Status filter
            _buildFilterDropdown(
              value: _statusFilter,
              hint: 'All Status',
              items: const [
                ('', 'All Status'),
                ('new', 'New'),
                ('contacted', 'Contacted'),
                ('qualified', 'Qualified'),
                ('proposal_sent', 'Proposal Sent'),
                ('negotiating', 'Negotiating'),
                ('won', 'Won'),
                ('lost', 'Lost'),
                ('on_hold', 'On Hold'),
                ('nurturing', 'Nurturing'),
              ],
              onChanged: (v) {
                setState(() {
                  _statusFilter = v ?? '';
                  _currentPage = 1;
                });
                _fetchLeads();
              },
            ),
            const SizedBox(width: 8),
            // Priority filter
            _buildFilterDropdown(
              value: _priorityFilter,
              hint: 'All Priority',
              items: const [
                ('', 'All Priority'),
                ('low', 'Low'),
                ('medium', 'Medium'),
                ('high', 'High'),
                ('urgent', 'Urgent'),
              ],
              onChanged: (v) {
                setState(() {
                  _priorityFilter = v ?? '';
                  _currentPage = 1;
                });
                _fetchLeads();
              },
            ),
            const SizedBox(width: 8),
            // Industry filter
            _buildFilterDropdown(
              value: _industryFilter,
              hint: 'All Industries',
              items: const [
                ('', 'All Industries'),
                ('technology', 'Technology'),
                ('healthcare', 'Healthcare'),
                ('finance', 'Finance'),
                ('retail', 'Retail & E-commerce'),
                ('real_estate', 'Real Estate'),
                ('education', 'Education'),
                ('hospitality', 'Hospitality'),
                ('manufacturing', 'Manufacturing'),
                ('professional_services', 'Professional Services'),
                ('non_profit', 'Non-Profit'),
                ('automotive', 'Automotive'),
                ('food_beverage', 'Food & Beverage'),
                ('fashion', 'Fashion & Beauty'),
                ('sports_fitness', 'Sports & Fitness'),
                ('entertainment', 'Entertainment'),
                ('other', 'Other'),
              ],
              onChanged: (v) {
                setState(() {
                  _industryFilter = v ?? '';
                  _currentPage = 1;
                });
                _fetchLeads();
              },
            ),
            if (widget.isManager) ...[
              const SizedBox(width: 8),
              // Created by filter (only for managers/admins)
              _buildFilterDropdown(
                value: _createdByFilter,
                hint: 'All Creators',
                items: [
                  const ('', 'All Creators'),
                  ..._creators.map((c) => (c['id'].toString(), c['username'] ?? c['email'] ?? 'User ${c['id']}')),
                ],
                onChanged: (v) {
                  setState(() {
                    _createdByFilter = v ?? '';
                    _currentPage = 1;
                  });
                  _fetchLeads();
                },
              ),
            ],
            if (_hasActiveFilters) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_rounded, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterDropdown({
    required String value,
    required String hint,
    required List<(String, String)> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: value.isNotEmpty ? _primary.withOpacity(0.1) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value.isNotEmpty ? _primary : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: value.isNotEmpty ? _primary : Colors.grey[700],
            fontWeight: value.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
          ),
          items: items.map((item) => DropdownMenuItem(
            value: item.$1,
            child: Text(item.$2, style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  
  Widget _buildActiveFilters() {
    final filters = <String>[];
    if (_statusFilter.isNotEmpty) filters.add(_statusLabels[_statusFilter] ?? _statusFilter);
    if (_priorityFilter.isNotEmpty) filters.add(_priorityLabels[_priorityFilter] ?? _priorityFilter);
    if (_industryFilter.isNotEmpty) filters.add(_industryLabels[_industryFilter] ?? _industryFilter);
    if (_createdByFilter.isNotEmpty) {
      final creator = _creators.firstWhere(
        (c) => c['id'].toString() == _createdByFilter,
        orElse: () => {'username': 'Creator'},
      );
      filters.add(creator['username'] ?? 'Creator');
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
                  _fetchLeads();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1 ? () {
                  setState(() => _currentPage--);
                  _fetchLeads();
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
                  _fetchLeads();
                } : null,
                iconSize: 20,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                onPressed: _currentPage < _totalPages ? () {
                  setState(() => _currentPage = _totalPages);
                  _fetchLeads();
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
    final company = lead['company_name'] ?? 'Unknown Company';
    final contact = lead['contact_person'] ?? '';
    final phone   = lead['phone'] ?? '';
    final industry = lead['industry'] ?? '';
    final priority = lead['priority'] ?? '';
    final services = lead['service_interests_display'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.business_rounded, color: color, size: 22),
        ),
        title: Text(company,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.isNotEmpty)
              Text(contact, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (industry.isNotEmpty)
              Text(_industryLabels[industry] ?? industry.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: services.take(2).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.toString(),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabels[status] ?? status,
                  style: TextStyle(fontSize: 10, color: color,
                      fontWeight: FontWeight.w600)),
            ),
            if (priority.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _priorityLabels[priority] ?? priority.toUpperCase(),
                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        onTap: () => _showLeadDetail(lead),
      ),
    );
  }
  
  // ── Download Template ──────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Template'];

      final headers = [
        'Company Name*', 'Contact Person*', 'Email', 'Phone*', 'Website',
        'Industry*', 'Services', 'Budget', 'Status', 'Priority',
        'Marketing Goals', 'Notes'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }

      final exampleRow = [
        'Example Corp', 'John Doe', 'john@example.com', '9876543210',
        'https://example.com', 'technology', 'SEO, Social Media Marketing',
        '50000', 'new', 'medium', 'Increase brand awareness',
        'Interested in monthly retainer'
      ];
      for (int j = 0; j < exampleRow.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1))
            .value = xl.TextCellValue(exampleRow[j]);
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
      final filePath = '${dir!.path}/ase_leads_template_$timestamp.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template saved to Downloads folder'),
            backgroundColor: Colors.green,
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
      for (final table in excel.tables.values) {
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final companyName = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          final contactPerson = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
          final email = row.length > 2 ? (row[2]?.value?.toString() ?? '') : '';
          final phone = row.length > 3 ? (row[3]?.value?.toString() ?? '') : '';
          
          if (companyName.isEmpty || phone.isEmpty) continue;
          
          leads.add({
            'company_name': companyName,
            'contact_person': contactPerson,
            'email': email,
            'phone': phone,
            'website': row.length > 4 ? (row[4]?.value?.toString() ?? '') : '',
            'industry': row.length > 5 ? (row[5]?.value?.toString() ?? 'other') : 'other',
            'budget_amount': row.length > 7 ? (row[7]?.value?.toString() ?? '') : '',
            'status': row.length > 8 ? (row[8]?.value?.toString() ?? 'new') : 'new',
            'priority': row.length > 9 ? (row[9]?.value?.toString() ?? 'medium') : 'medium',
            'marketing_goals': row.length > 10 ? (row[10]?.value?.toString() ?? '') : '',
            'notes': row.length > 11 ? (row[11]?.value?.toString() ?? '') : '',
            'service_interests': [],
            'has_website': false,
            'has_social_media': false,
          });
        }
        break;
      }

      if (leads.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid rows found in file.')),
          );
        }
        return;
      }

      final res = await ApiService.post('/ase-leads/bulk_import/', {'leads': leads});
      if (mounted) {
        final ok = res['success'] == true;
        final imported = res['data']?['imported'] ?? 0;
        final errors = res['data']?['errors'] ?? [];
        final msg = ok
            ? 'Imported $imported leads${errors.isNotEmpty ? ' (${errors.length} skipped)' : ''}'
            : 'Import failed: ${res['data']?['detail'] ?? 'Unknown error'}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
        if (ok) _fetchLeads();
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

  // ── Export to Excel ────────────────────────────────────────────────────────
  Future<void> _exportToExcel() async {
    try {
      // Fetch all pages
      List<dynamic> allLeads = [];
      int page = 1;
      while (true) {
        String url = '/ase-leads/?page=$page&page_size=200';
        if (_statusFilter.isNotEmpty) url += '&status=$_statusFilter';
        if (_priorityFilter.isNotEmpty) url += '&priority=$_priorityFilter';
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
        'Company Name', 'Contact Person', 'Email', 'Phone', 'Website',
        'Industry', 'Services', 'Budget', 'Status', 'Priority',
        'Marketing Goals', 'Notes', 'Assigned To', 'Created By', 'Created At'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }

      for (int i = 0; i < allLeads.length; i++) {
        final l = allLeads[i] as Map<String, dynamic>;
        final services = l['service_interests_display'] as List? ?? [];
        
        final row = [
          l['company_name'] ?? '',
          l['contact_person'] ?? '',
          l['email'] ?? '',
          l['phone'] ?? '',
          l['website'] ?? '',
          _industryLabels[l['industry']] ?? l['industry'] ?? '',
          services.join(', '),
          l['budget_amount'] ?? '',
          _statusLabels[l['status']] ?? l['status'] ?? '',
          _priorityLabels[l['priority']] ?? l['priority'] ?? '',
          l['marketing_goals'] ?? '',
          l['notes'] ?? '',
          l['assigned_to_name'] ?? '',
          l['created_by_name'] ?? '',
          l['created_at'] ?? '',
        ];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
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
      final filePath = '${dir!.path}/ase_leads_export_$timestamp.xlsx';
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
  
  void _showAddLeadForm() {
    showDialog(
      context: context,
      builder: (_) => _AddLeadDialog(
        userData: widget.userData,
        onSave: () {
          _fetchLeads();
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
        onRefresh: _fetchLeads,
        onEdit: () {
          Navigator.pop(context);
          // TODO: Implement edit
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Edit lead - Coming soon')),
          );
        },
        onDelete: () async {
          Navigator.pop(context);
          await _deleteLead(lead);
        },
      ),
    );
  }
  
  Future<void> _deleteLead(Map<String, dynamic> lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete "${lead['company_name']}"?'),
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
        endpoint: '/ase-leads/$id/',
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
          _fetchLeads();
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
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const _LeadDetailSheet({
    required this.lead,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final company = lead['company_name'] ?? 'Unknown';
    final contact = lead['contact_person'] ?? '';
    final phone   = lead['phone'] ?? '';
    final email   = lead['email'] ?? '';
    final website = lead['website'] ?? '';
    final status  = lead['status'] ?? 'new';
    final priority = lead['priority'] ?? '';
    final industry = lead['industry'] ?? '';
    final budget = lead['budget_amount'] ?? '';
    final goals = lead['marketing_goals'] ?? '';
    final notes   = lead['notes'] ?? '';
    final services = lead['service_interests_display'] as List? ?? [];
    final assignedTo = lead['assigned_to_name'] ?? '';
    final createdBy = lead['created_by_name'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.business_rounded,
                      color: _primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company, style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold)),
                      if (contact.isNotEmpty)
                        Text(contact, style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
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
            if (phone.isNotEmpty || email.isNotEmpty) ...[
              Row(
                children: [
                  if (phone.isNotEmpty) ...[
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
                  ],
                  if (email.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendEmail(email),
                        icon: const Icon(Icons.email, size: 18),
                        label: const Text('Email'),
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
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            _row('Status', status.replaceAll('_', ' ').toUpperCase()),
            if (priority.isNotEmpty) _row('Priority', priority.toUpperCase()),
            if (phone.isNotEmpty) _row('Phone', phone),
            if (email.isNotEmpty) _row('Email', email),
            if (website.isNotEmpty) _row('Website', website),
            if (industry.isNotEmpty) _row('Industry', industry.replaceAll('_', ' ')),
            if (budget.isNotEmpty) _row('Budget', budget),
            if (assignedTo.isNotEmpty) _row('Assigned To', assignedTo),
            if (createdBy.isNotEmpty) _row('Created By', createdBy),
            
            if (services.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Service Interests', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: services.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.toString(),
                    style: const TextStyle(fontSize: 11, color: _primary),
                  ),
                )).toList(),
              ),
            ],
            
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Marketing Goals', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(goals, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(notes, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110,
              child: Text(label, style: const TextStyle(
                  color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 13))),
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
  
  void _sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    } catch (_) {}
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _LeadFilterSheet - Filter Bottom Sheet for Leads
// ─────────────────────────────────────────────────────────────────────────────
class _LeadFilterSheet extends StatefulWidget {
  final String statusFilter;
  final String priorityFilter;
  final String industryFilter;
  final String createdByFilter;
  final List<Map<String, dynamic>> creators;
  final bool isManager;
  final Function(String, String, String, String) onApply;
  final VoidCallback onClear;

  const _LeadFilterSheet({
    required this.statusFilter,
    required this.priorityFilter,
    required this.industryFilter,
    required this.createdByFilter,
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
  late String _priority;
  late String _industry;
  late String _createdBy;

  static const Color _primary = Color(0xFF1565C0);

  static const _statusOptions = [
    ('', 'All Status'),
    ('new', 'New'),
    ('contacted', 'Contacted'),
    ('qualified', 'Qualified'),
    ('proposal_sent', 'Proposal Sent'),
    ('negotiating', 'Negotiating'),
    ('won', 'Won'),
    ('lost', 'Lost'),
    ('on_hold', 'On Hold'),
    ('nurturing', 'Nurturing'),
  ];

  static const _priorityOptions = [
    ('', 'All Priority'),
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('urgent', 'Urgent'),
  ];

  static const _industryOptions = [
    ('', 'All Industries'),
    ('technology', 'Technology'),
    ('healthcare', 'Healthcare'),
    ('finance', 'Finance'),
    ('retail', 'Retail & E-commerce'),
    ('real_estate', 'Real Estate'),
    ('education', 'Education'),
    ('hospitality', 'Hospitality'),
    ('manufacturing', 'Manufacturing'),
    ('professional_services', 'Professional Services'),
    ('non_profit', 'Non-Profit'),
    ('automotive', 'Automotive'),
    ('food_beverage', 'Food & Beverage'),
    ('fashion', 'Fashion & Beauty'),
    ('sports_fitness', 'Sports & Fitness'),
    ('entertainment', 'Entertainment'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _priority = widget.priorityFilter;
    _industry = widget.industryFilter;
    _createdBy = widget.createdByFilter;
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

                  // Priority
                  _buildSectionTitle('Priority', Icons.priority_high_rounded),
                  const SizedBox(height: 8),
                  _buildPriorityChips(),
                  const SizedBox(height: 20),

                  // Industry
                  _buildSectionTitle('Industry', Icons.business_rounded),
                  const SizedBox(height: 8),
                  _buildIndustryDropdown(),
                  const SizedBox(height: 20),

                  // Created By (only for managers)
                  if (widget.isManager) ...[
                    _buildSectionTitle('Created By', Icons.person_rounded),
                    const SizedBox(height: 8),
                    _buildCreatedByDropdown(),
                    const SizedBox(height: 20),
                  ],

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
                      widget.onApply(_status, _priority, _industry, _createdBy);
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

  Widget _buildPriorityChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _priorityOptions.map((opt) {
        final isSelected = _priority == opt.$1;
        return GestureDetector(
          onTap: () => setState(() => _priority = opt.$1),
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

  Widget _buildIndustryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _industry.isEmpty ? '' : _industry,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
          items: _industryOptions.map((opt) {
            return DropdownMenuItem(
              value: opt.$1,
              child: Text(
                opt.$2,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _industry = v);
          },
        ),
      ),
    );
  }

  Widget _buildCreatedByDropdown() {
    final creatorOptions = [
      {'id': '', 'username': 'All Creators'},
      ...widget.creators,
    ];

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
          items: creatorOptions.map((c) {
            final id = c['id'].toString();
            final name = c['username'] ?? c['first_name'] ?? 'Unknown';
            return DropdownMenuItem(
              value: id,
              child: Text(
                name,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _createdBy = v);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AddLeadDialog - Add Lead Form Dialog
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
  final _companyNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _companySizeCtrl = TextEditingController();
  final _annualRevenueCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _currentMarketingSpendCtrl = TextEditingController();
  final _currentSeoAgencyCtrl = TextEditingController();
  final _leadSourceCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _estimatedProjectValueCtrl = TextEditingController();
  final _monthlyRetainerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _industry = 'technology';
  String _status = 'new';
  String _priority = 'medium';
  List<String> _serviceInterests = [];
  bool _hasWebsite = false;
  bool _hasSocialMedia = false;
  DateTime? _firstContactDate;
  DateTime? _nextFollowUp;
  bool _loading = false;

  static const Color _primary = Color(0xFF1565C0);

  static const _serviceOptions = [
    ('seo', 'SEO'),
    ('social_media', 'Social Media Marketing'),
    ('content_marketing', 'Content Marketing'),
    ('ppc', 'Pay-Per-Click Advertising'),
    ('email_marketing', 'Email Marketing'),
    ('web_design', 'Web Design & Development'),
    ('branding', 'Branding & Design'),
    ('analytics', 'Analytics & Reporting'),
    ('influencer', 'Influencer Marketing'),
    ('video_marketing', 'Video Marketing'),
    ('custom', 'Custom/Other Services'),
  ];

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _companySizeCtrl.dispose();
    _annualRevenueCtrl.dispose();
    _budgetCtrl.dispose();
    _currentMarketingSpendCtrl.dispose();
    _currentSeoAgencyCtrl.dispose();
    _leadSourceCtrl.dispose();
    _goalsCtrl.dispose();
    _estimatedProjectValueCtrl.dispose();
    _monthlyRetainerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_serviceInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service interest'),
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

      final body = {
        'company': companyId,
        'company_name': _companyNameCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'industry': _industry,
        'company_size': _companySizeCtrl.text.trim().isEmpty ? null : _companySizeCtrl.text.trim(),
        'annual_revenue': _annualRevenueCtrl.text.trim().isEmpty ? null : _annualRevenueCtrl.text.trim(),
        'service_interests': _serviceInterests,
        'budget_amount': _budgetCtrl.text.trim().isEmpty ? null : _budgetCtrl.text.trim(),
        'current_marketing_spend': _currentMarketingSpendCtrl.text.trim().isEmpty ? null : _currentMarketingSpendCtrl.text.trim(),
        'current_seo_agency': _currentSeoAgencyCtrl.text.trim().isEmpty ? null : _currentSeoAgencyCtrl.text.trim(),
        'lead_source': _leadSourceCtrl.text.trim().isEmpty ? null : _leadSourceCtrl.text.trim(),
        'has_website': _hasWebsite,
        'has_social_media': _hasSocialMedia,
        'marketing_goals': _goalsCtrl.text.trim().isEmpty ? null : _goalsCtrl.text.trim(),
        'status': _status,
        'priority': _priority,
        'first_contact_date': _firstContactDate?.toIso8601String(),
        'next_follow_up': _nextFollowUp?.toIso8601String(),
        'estimated_project_value': _estimatedProjectValueCtrl.text.trim().isEmpty ? null : _estimatedProjectValueCtrl.text.trim(),
        'monthly_retainer': _monthlyRetainerCtrl.text.trim().isEmpty ? null : _monthlyRetainerCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      final res = await ApiService.post('/ase-leads/', body);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSave();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['detail'] ?? 'Failed to create lead'}'),
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 700),
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
                  const Icon(Icons.add_business_rounded, color: Colors.white, size: 24),
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
                    // Company Information
                    _buildSectionHeader('Company Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _companyNameCtrl,
                      label: 'Company Name *',
                      hint: 'Enter company name',
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _contactPersonCtrl,
                      label: 'Contact Person *',
                      hint: 'Enter contact person name',
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: 'Phone *',
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'Enter email address (optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _websiteCtrl,
                      label: 'Website',
                      hint: 'https://example.com (optional)',
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 20),
                    // Business Information
                    _buildSectionHeader('Business Information'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Industry *',
                      value: _industry,
                      items: const [
                        ('technology', 'Technology'),
                        ('healthcare', 'Healthcare'),
                        ('finance', 'Finance'),
                        ('retail', 'Retail & E-commerce'),
                        ('real_estate', 'Real Estate'),
                        ('education', 'Education'),
                        ('hospitality', 'Hospitality'),
                        ('manufacturing', 'Manufacturing'),
                        ('professional_services', 'Professional Services'),
                        ('non_profit', 'Non-Profit'),
                        ('automotive', 'Automotive'),
                        ('food_beverage', 'Food & Beverage'),
                        ('fashion', 'Fashion & Beauty'),
                        ('sports_fitness', 'Sports & Fitness'),
                        ('entertainment', 'Entertainment'),
                        ('other', 'Other'),
                      ],
                      onChanged: (v) => setState(() => _industry = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _companySizeCtrl,
                      label: 'Company Size',
                      hint: 'e.g., 10-50 employees',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _annualRevenueCtrl,
                      label: 'Annual Revenue',
                      hint: 'e.g., ₹1-5 Crores',
                    ),

                    const SizedBox(height: 20),
                    // Service Interests
                    _buildSectionHeader('Service Interests *'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _serviceOptions.map((opt) {
                        final isSelected = _serviceInterests.contains(opt.$1);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _serviceInterests.remove(opt.$1);
                              } else {
                                _serviceInterests.add(opt.$1);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? _primary : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                if (isSelected) const SizedBox(width: 4),
                                Text(
                                  opt.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    // Marketing Information
                    _buildSectionHeader('Marketing Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _budgetCtrl,
                      label: 'Budget Amount',
                      hint: 'e.g., ₹2,00,000 per month',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _currentMarketingSpendCtrl,
                      label: 'Current Marketing Spend',
                      hint: 'e.g., ₹50,000 per month',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _currentSeoAgencyCtrl,
                      label: 'Current SEO Agency',
                      hint: 'Current agency name (if any)',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _leadSourceCtrl,
                      label: 'Lead Source',
                      hint: 'e.g., Website, Referral, Cold Call',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Has existing website', style: TextStyle(fontSize: 13)),
                            value: _hasWebsite,
                            onChanged: (v) => setState(() => _hasWebsite = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Has social media presence', style: TextStyle(fontSize: 13)),
                            value: _hasSocialMedia,
                            onChanged: (v) => setState(() => _hasSocialMedia = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _goalsCtrl,
                      label: 'Marketing Goals',
                      hint: 'Describe their marketing goals and objectives...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 20),
                    // Lead Management
                    _buildSectionHeader('Lead Management'),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Status',
                      value: _status,
                      items: const [
                        ('new', 'New Lead'),
                        ('contacted', 'Contacted'),
                        ('qualified', 'Qualified'),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Priority',
                      value: _priority,
                      items: const [
                        ('low', 'Low'),
                        ('medium', 'Medium'),
                        ('high', 'High'),
                        ('urgent', 'Urgent'),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),

                    const SizedBox(height: 20),
                    // Important Dates
                    _buildSectionHeader('Important Dates'),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: 'First Contact Date',
                      value: _firstContactDate,
                      onChanged: (date) => setState(() => _firstContactDate = date),
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: 'Next Follow Up',
                      value: _nextFollowUp,
                      onChanged: (date) => setState(() => _nextFollowUp = date),
                    ),

                    const SizedBox(height: 20),
                    // Financial Information
                    _buildSectionHeader('Financial Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _estimatedProjectValueCtrl,
                      label: 'Estimated Project Value (₹)',
                      hint: 'e.g., 500000',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _monthlyRetainerCtrl,
                      label: 'Monthly Retainer (₹)',
                      hint: 'e.g., 50000',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 20),
                    // Notes
                    _buildSectionHeader('Notes'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _notesCtrl,
                      label: 'Additional Notes',
                      hint: 'Additional notes and comments...',
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
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
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
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey[600]),
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
                if (value != null)
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
