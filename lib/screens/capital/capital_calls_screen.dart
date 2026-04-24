import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'capital_convert_sheet.dart';

// ── Constants ────────────────────────────────────────────────────────────────

const _primary = Color(0xFF1565C0);

const _statusColors = {
  'pending':      Color(0xFFFFF9C4),
  'answered':     Color(0xFFE8F5E9),
  'not_answered': Color(0xFFFFEBEE),
  'busy':         Color(0xFFFFF3E0),
  'not_interested': Color(0xFFF5F5F5),
};
const _statusTextColors = {
  'pending':      Color(0xFFF9A825),
  'answered':     Color(0xFF2E7D32),
  'not_answered': Color(0xFFC62828),
  'busy':         Color(0xFFE65100),
  'not_interested': Color(0xFF757575),
};
const _interestColors = {
  'loan': Color(0xFFE3F2FD),
  'gst':  Color(0xFFFFF3E0),
  'msme': Color(0xFFE0F2F1),
  'itr':  Color(0xFFEDE7F6),
  'none': Color(0xFFF5F5F5),
};
const _interestTextColors = {
  'loan': Color(0xFF1565C0),
  'gst':  Color(0xFFE65100),
  'msme': Color(0xFF00695C),
  'itr':  Color(0xFF4527A0),
  'none': Color(0xFF757575),
};
const _interestLabels = {
  'none': 'Not Decided',
  'loan': 'Loan',
  'gst':  'GST Service',
  'msme': 'MSME Service',
  'itr':  'Income Tax Filing',
};

// Strip decimal from phone numbers read from Excel (e.g. 9876543210.0 → 9876543210)
String _cleanPhone(String raw) {
  if (raw.isEmpty) return raw;
  final d = double.tryParse(raw);
  if (d != null) return d.toInt().toString();
  return raw.replaceAll('.0', '');
}

// ── Main Screen ──────────────────────────────────────────────────────────────

class CapitalCallsScreen extends StatefulWidget {
  final bool isManager;
  final Map<String, dynamic> userData;
  const CapitalCallsScreen({super.key, this.isManager = false, required this.userData});

  @override
  State<CapitalCallsScreen> createState() => _CapitalCallsScreenState();
}

class _CapitalCallsScreenState extends State<CapitalCallsScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 20;

  // filters
  String _search = '';
  String _statusFilter = '';
  String _interestFilter = '';
  String _convertedFilter = '';

  // summary counts
  int _convertedCount = 0;
  int _pendingCount   = 0;
  int _answeredCount  = 0;
  int _notAnsweredCount = 0;
  int _notInterestedCount = 0;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _buildEndpoint() {
    final params = <String, String>{
      'page': '$_page',
      'page_size': '$_pageSize',
    };
    if (_search.isNotEmpty)         params['search']       = _search;
    if (_statusFilter.isNotEmpty)   params['call_status']  = _statusFilter;
    if (_interestFilter.isNotEmpty) params['interest']     = _interestFilter;
    if (_convertedFilter.isNotEmpty) params['is_converted'] = _convertedFilter == 'yes' ? 'true' : 'false';
    final q = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '/capital/customers/?$q';
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _loading = true);
    try {
      final endpoint = _buildEndpoint();
      // Debug: print token to verify correct user
      final token = await AuthService.getAccessToken();
      debugPrint('🔵 App user: ${widget.userData['first_name']} ${widget.userData['last_name']} | role=${widget.userData['role']} | id=${widget.userData['id']}');
      debugPrint('🔵 Token (first 40 chars): ${token?.substring(0, token.length > 40 ? 40 : token.length)}');
      debugPrint('🔵 Calls endpoint: $endpoint');
      final res = await ApiService.get(endpoint);
      debugPrint('🔵 Calls load: status=${res['status']}, success=${res['success']}');
      debugPrint('🔵 Calls data: ${res['data']}');
      final data = res['data'];
      if (mounted) {
        final results = (data?['results'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final count = data?['count'] ?? 0;
        debugPrint('🔵 Calls count=$count, results=${results.length}');
        setState(() {
          _calls      = results;
          _totalCount = count;
          _totalPages = count == 0 ? 1 : (count / _pageSize).ceil();
          _loading    = false;
          _computeSummary(results);
        });
      }
    } catch (e, st) {
      debugPrint('🔴 Calls load error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeSummary(List<Map<String, dynamic>> list) {
    _convertedCount     = list.where((c) => c['is_converted'] == true).length;
    _pendingCount       = list.where((c) => c['call_status'] == 'pending').length;
    _answeredCount      = list.where((c) => c['call_status'] == 'answered').length;
    _notAnsweredCount   = list.where((c) => c['call_status'] == 'not_answered').length;
    _notInterestedCount = list.where((c) => c['call_status'] == 'not_interested').length;
  }

  Future<void> _quickUpdateStatus(String id, String status) async {
    await ApiService.request(
        endpoint: '/capital/customers/$id/', method: 'PATCH', body: {'call_status': status});
    _load();
  }

  Future<void> _delete(String id) async {
    final ok = await _confirm('Delete this call?');
    if (!ok) return;
    await ApiService.delete('/capital/customers/$id/');
    _load();
  }

  Future<void> _convertToLead(Map<String, dynamic> c) async {
    showConvertSheet(context, c, widget.userData, () => _load());
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  void _openForm({Map<String, dynamic>? call}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallFormSheet(
        call: call,
        isManager: widget.isManager,
        userData: widget.userData,
        onSaved: () => Navigator.pop(context),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF12121C) : Colors.grey[50]!;
    final card   = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildSearchBar(isDark, card),
          _buildFilters(isDark, card),
          _buildSummaryBar(isDark, card),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _calls.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => _load(resetPage: true),
                        color: _primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _calls.length,
                          itemBuilder: (_, i) => _CallCard(
                            call: _calls[i],
                            isDark: isDark,
                            cardColor: card,
                            isManager: widget.isManager,
                            userData: widget.userData,
                            onEdit: () => _openForm(call: _calls[i]),
                            onDelete: () => _delete(_calls[i]['id'].toString()),
                            onStatusChange: (s) => _quickUpdateStatus(_calls[i]['id'].toString(), s),
                            onConvert: () => _convertToLead(_calls[i]),
                          ),
                        ),
                      ),
          ),
          _buildPagination(isDark, card),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────
  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final bytes = File(path).readAsBytesSync();
      final excel = xl.Excel.decodeBytes(bytes);
      final customers = <Map<String, dynamic>>[];

      for (final table in excel.tables.values) {
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final name     = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          final rawPhone = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
          final phone    = _cleanPhone(rawPhone);
          final email    = row.length > 2 ? (row[2]?.value?.toString() ?? '') : '';
          final company  = row.length > 3 ? (row[3]?.value?.toString() ?? '') : '';
          final interest = row.length > 4 ? (row[4]?.value?.toString() ?? '') : '';
          final notes    = row.length > 5 ? (row[5]?.value?.toString() ?? '') : '';
          if (name.isEmpty && phone.isEmpty) continue;
          customers.add({
            'name': name, 'phone': phone, 'email': email,
            'company_name': company,
            'interest': interest.isEmpty ? 'none' : interest,
            'notes': notes,
          });
        }
        break;
      }

      if (customers.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid rows found in file.')));
        return;
      }

      final res = await ApiService.post('/capital/customers/bulk_import/', {'customers': customers});
      if (mounted) {
        final ok = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Imported ${customers.length} calls successfully'
              : 'Import failed: ${res['data']?['detail'] ?? 'Unknown error'}'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) _load(resetPage: true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Template ──────────────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Calls'];
      final headers = ['Name', 'Phone*', 'Call Status', 'Interest'];
      final example = ['John Doe', '9876543210', 'pending', 'loan'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }
      for (int j = 0; j < example.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1))
            .value = xl.TextCellValue(example[j]);
      }
      // Remove all sheets except 'Calls'
      for (final name in excel.sheets.keys.toList()) {
        if (name != 'Calls') excel.delete(name);
      }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir!.path}/capital_calls_template_$ts.xlsx';
      File(filePath).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Template saved to Downloads', filePath);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _exportToExcel() async {
    try {
      String endpoint = '/capital/customers/?page_size=2000';
      if (_search.isNotEmpty) endpoint += '&search=${Uri.encodeComponent(_search)}';
      if (_statusFilter.isNotEmpty) endpoint += '&call_status=$_statusFilter';
      if (_interestFilter.isNotEmpty) endpoint += '&interest=$_interestFilter';
      if (_convertedFilter.isNotEmpty) endpoint += '&is_converted=${_convertedFilter == 'yes' ? 'true' : 'false'}';

      final res = await ApiService.get(endpoint);
      final all = (res['data']?['results'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>).toList();

      final excel = xl.Excel.createExcel();
      final sheet = excel['Calls'];
      final headers = ['Name', 'Phone', 'Email', 'Company', 'Call Status', 'Interest', 'Assigned To', 'Notes', 'Converted', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }
      for (int i = 0; i < all.length; i++) {
        final c = all[i];
        final row = [
          c['name'] ?? '', c['phone'] ?? '', c['email'] ?? '',
          c['company_name'] ?? '', c['call_status'] ?? '',
          c['interest'] ?? '', c['assigned_to_name'] ?? '',
          c['notes'] ?? '', c['is_converted'] == true ? 'Yes' : 'No',
          c['created_at'] ?? '',
        ];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(row[j].toString());
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir!.path}/capital_calls_$ts.xlsx';
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to encode file');
      File(filePath).writeAsBytesSync(bytes);
      _showFileSnackbar('Exported ${all.length} calls to Downloads', filePath);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildSearchBar(bool isDark, Color card) {
    final filterCount = _activeFilterCount;
    return Container(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          // Search + Filter button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey[500]),
                    prefixIcon: Icon(Icons.search,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                        size: 18),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                                size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                              _load(resetPage: true);
                            })
                        : null,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _primary)),
                  ),
                  onChanged: (v) {
                    setState(() => _search = v);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_search == v) _load(resetPage: true);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Filter button with badge
              Stack(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('Filter', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: filterCount > 0 ? _primary : (isDark ? Colors.white70 : Colors.grey[700]),
                      side: BorderSide(
                          color: filterCount > 0 ? _primary : (isDark ? Colors.white24 : Colors.grey.shade300)),
                      backgroundColor: filterCount > 0 ? _primary.withOpacity(0.08) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (filterCount > 0)
                    Positioned(
                      right: 4, top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$filterCount',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Template / Import / Export
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.file_download_rounded, size: 14),
                  label: const Text('Template', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importFromExcel,
                  icon: const Icon(Icons.upload_rounded, size: 14),
                  label: const Text('Import', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: Text('Export($_totalCount)', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFileSnackbar(String msg, String filePath) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'View',
        textColor: Colors.white,
        onPressed: () => OpenFile.open(filePath),
      ),
    ));
  }

  int get _activeFilterCount =>
      (_statusFilter.isNotEmpty ? 1 : 0) +
      (_interestFilter.isNotEmpty ? 1 : 0) +
      (_convertedFilter.isNotEmpty ? 1 : 0);

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String tmpStatus    = _statusFilter;
    String tmpInterest  = _interestFilter;
    String tmpConverted = _convertedFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget section(String title, List<(String, String)> opts, String current,
              void Function(String) onTap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[700])),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: opts.map((o) {
                      final active = current == o.$1;
                      return GestureDetector(
                        onTap: () { setLocal(() => onTap(o.$1)); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? _primary : (isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? _primary : Colors.transparent),
                          ),
                          child: Text(o.$2,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setLocal(() { tmpStatus = ''; tmpInterest = ''; tmpConverted = ''; });
                      },
                      child: const Text('Clear All', style: TextStyle(color: _primary)),
                    ),
                  ],
                ),
              ),
              section('Call Status', [
                ('', 'All'), ('pending', 'Pending'), ('answered', 'Answered'),
                ('not_answered', 'Not Answered'), ('busy', 'Busy'), ('not_interested', 'Not Interested'),
              ], tmpStatus, (v) => tmpStatus = v),
              section('Interest', [
                ('', 'All'), ('loan', 'Loan'), ('gst', 'GST'),
                ('msme', 'MSME'), ('itr', 'Income Tax'), ('none', 'Not Decided'),
              ], tmpInterest, (v) => tmpInterest = v),
              section('Converted', [
                ('', 'All'), ('yes', 'Converted'), ('no', 'Not Converted'),
              ], tmpConverted, (v) => tmpConverted = v),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _statusFilter    = tmpStatus;
                        _interestFilter  = tmpInterest;
                        _convertedFilter = tmpConverted;
                      });
                      _load(resetPage: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(bool isDark, Color card) {
    return const SizedBox.shrink(); // Removed — filters now in button
  }

  Widget _buildSummaryBar(bool isDark, Color card) {
    final items = [
      ('$_totalCount', 'Total', Colors.blueGrey),
      ('$_convertedCount', 'Converted', const Color(0xFF2E7D32)),
      ('$_pendingCount', 'Pending', const Color(0xFFF9A825)),
      ('$_answeredCount', 'Answered', const Color(0xFF2E7D32)),
      ('$_notAnsweredCount', 'Not Ans.', const Color(0xFFC62828)),
      ('$_notInterestedCount', 'Not Int.', Colors.grey),
    ];
    return Container(
      height: 60,
      color: isDark ? const Color(0xFF12121C) : Colors.grey[50],
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (item.$3 as Color).withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.$1,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: item.$3 as Color)),
                Text(item.$2,
                    style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white54 : Colors.grey[600])),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(bool isDark, Color card) {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${(_page - 1) * _pageSize + 1}–${(_page * _pageSize).clamp(0, _totalCount)} of $_totalCount',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600])),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text('$_page / $_totalPages', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_missed_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No calls found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Total from API: $_totalCount',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _load(resetPage: true),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
          TextButton(onPressed: () => _openForm(), child: const Text('Add first call')),
        ],
      ),
    );
  }
}

// ── Call Card ────────────────────────────────────────────────────────────────

class _CallCard extends StatelessWidget {
  final Map<String, dynamic> call;
  final bool isDark;
  final Color cardColor;
  final bool isManager;
  final Map<String, dynamic> userData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;
  final VoidCallback onConvert;

  const _CallCard({
    required this.call,
    required this.isDark,
    required this.cardColor,
    required this.isManager,
    required this.userData,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final status    = call['call_status'] ?? 'pending';
    final interest  = call['interest'] ?? 'none';
    final converted = call['is_converted'] == true;
    final statusTxt = _statusTextColors[status] ?? Colors.grey;
    final name      = call['name'] ?? 'Unknown';
    final phone     = call['phone'] ?? '';
    final company   = (call['company_name'] ?? '').toString();
    final assigned  = (call['assigned_to_name'] ?? '').toString();
    final interestLbl = interest != 'none' ? (_interestLabels[interest] ?? interest) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: statusTxt.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.person_rounded, color: statusTxt, size: 20),
        ),
        title: Text(name,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              Text(phone,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600])),
            if (company.isNotEmpty)
              Text(company,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey[500])),
            if (interestLbl != null) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (_interestColors[interest] ?? const Color(0xFFF5F5F5))
                      .withOpacity(isDark ? 0.25 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(interestLbl,
                    style: TextStyle(
                        fontSize: 10,
                        color: _interestTextColors[interest] ?? Colors.grey,
                        fontWeight: FontWeight.w600)),
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
                  color: statusTxt.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(status),
                  style: TextStyle(
                      fontSize: 10,
                      color: statusTxt,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            if (converted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, size: 10, color: Color(0xFF2E7D32)),
                  SizedBox(width: 3),
                  Text('Lead',
                      style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            if (assigned.isNotEmpty && !converted) ...[
              Text(assigned,
                  style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white38 : Colors.grey[400])),
            ],
          ],
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }

  String _statusLabel(String s) => const {
        'pending': 'Pending',
        'answered': 'Answered',
        'not_answered': 'Not Answered',
        'busy': 'Busy',
        'not_interested': 'Not Interested',
      }[s] ??
      s;

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallDetailSheet(
        call: call,
        isDark: isDark,
        userData: userData,
        onEdit: onEdit,
        onDelete: onDelete,
        onStatusChange: onStatusChange,
        onConvert: onConvert,
      ),
    );
  }
}

// ── Call Detail Sheet ────────────────────────────────────────────────────────

class _CallDetailSheet extends StatelessWidget {
  final Map<String, dynamic> call;
  final bool isDark;
  final Map<String, dynamic> userData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;
  final VoidCallback onConvert;

  const _CallDetailSheet({
    required this.call,
    required this.isDark,
    required this.userData,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final status    = call['call_status'] ?? 'pending';
    final interest  = call['interest'] ?? 'none';
    final converted = call['is_converted'] == true;
    final statusTxt = _statusTextColors[status] ?? Colors.grey;
    final name      = call['name'] ?? 'Unknown';
    final phone     = (call['phone'] ?? '').toString();
    final email     = (call['email'] ?? '').toString();
    final company   = (call['company_name'] ?? '').toString();
    final notes     = (call['notes'] ?? '').toString();
    final assigned  = (call['assigned_to_name'] ?? '').toString();
    final interestLbl = interest != 'none' ? (_interestLabels[interest] ?? interest) : null;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final divColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.zero,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: statusTxt.withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Icon(Icons.person_rounded, color: statusTxt, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                        if (company.isNotEmpty)
                          Text(company,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[600])),
                      ],
                    ),
                  ),
                  // Edit
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: _primary, size: 20),
                    onPressed: () { Navigator.pop(context); onEdit(); },
                    tooltip: 'Edit',
                  ),
                  // Convert (only if not converted)
                  if (!converted)
                    IconButton(
                      icon: const Icon(Icons.trending_up_rounded,
                          color: Color(0xFF2E7D32), size: 20),
                      onPressed: () { Navigator.pop(context); onConvert(); },
                      tooltip: 'Convert to Lead',
                    ),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                    onPressed: () { Navigator.pop(context); onDelete(); },
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),

            Divider(color: divColor, height: 20),

            // ── Status dropdown ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _pickStatus(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: (_statusColors[status] ?? const Color(0xFFF5F5F5))
                        .withOpacity(isDark ? 0.2 : 1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: statusTxt.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Call Status',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600])),
                      Row(
                        children: [
                          Text(_statusLabel(status),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusTxt)),
                          Icon(Icons.arrow_drop_down, size: 18, color: statusTxt),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Call / WhatsApp ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: phone.isNotEmpty
                          ? () => launchUrl(Uri.parse('tel:$phone'))
                          : null,
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Call', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: phone.isNotEmpty
                          ? () => launchUrl(Uri.parse(
                              'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}'))
                          : null,
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: divColor, height: 24),

            // ── Info rows ──
            if (phone.isNotEmpty)
              _infoTile(Icons.phone_rounded, 'Phone', phone, isDark),
            if (email.isNotEmpty)
              _infoTile(Icons.email_rounded, 'Email', email, isDark),
            if (assigned.isNotEmpty)
              _infoTile(Icons.person_outline_rounded, 'Assigned To', assigned, isDark),
            if (interestLbl != null)
              _infoTile(Icons.interests_rounded, 'Interested In', interestLbl, isDark),
            if (converted)
              _infoTile(Icons.check_circle_outline, 'Status', 'Converted to Lead', isDark,
                  valueColor: const Color(0xFF2E7D32)),

            // ── Notes ──
            if (notes.isNotEmpty) ...[
              Divider(color: divColor, height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: divColor),
                      ),
                      child: Text(notes,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: valueColor ??
                            (isDark ? Colors.white : Colors.black87))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => const {
        'pending': 'Pending',
        'answered': 'Answered',
        'not_answered': 'Not Answered',
        'busy': 'Busy',
        'not_interested': 'Not Interested',
      }[s] ??
      s;

  void _pickStatus(BuildContext context) {
    final statuses = ['pending', 'answered', 'not_answered', 'busy', 'not_interested'];
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Update Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          ...statuses.map((s) {
            final txt = _statusTextColors[s] ?? Colors.grey;
            return ListTile(
              dense: true,
              leading: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: txt, shape: BoxShape.circle)),
              title: Text(_statusLabel(s), style: const TextStyle(fontSize: 13)),
              trailing: call['call_status'] == s
                  ? const Icon(Icons.check, color: _primary, size: 16)
                  : null,
              onTap: () { Navigator.pop(context); onStatusChange(s); },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}


// ── Add / Edit Form Sheet ────────────────────────────────────────────────────

class _CallFormSheet extends StatefulWidget {
  final Map<String, dynamic>? call;
  final bool isManager;
  final VoidCallback onSaved;
  final Map<String, dynamic> userData;

  const _CallFormSheet({
    this.call,
    required this.isManager,
    required this.onSaved,
    required this.userData,
  });

  @override
  State<_CallFormSheet> createState() => _CallFormSheetState();
}

class _CallFormSheetState extends State<_CallFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name    = TextEditingController(text: widget.call?['name'] ?? '');
  late final TextEditingController _phone   = TextEditingController(text: widget.call?['phone'] ?? '');
  late final TextEditingController _email   = TextEditingController(text: widget.call?['email'] ?? '');
  late final TextEditingController _company = TextEditingController(text: widget.call?['company_name'] ?? '');
  late final TextEditingController _notes   = TextEditingController(text: widget.call?['notes'] ?? '');

  String _status   = 'pending';
  String _interest = 'none';
  bool   _saving   = false;

  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _status   = widget.call?['call_status'] ?? 'pending';
    _interest = widget.call?['interest']    ?? 'none';
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await ApiService.get('/accounts/employees/');
      final data = res['data'];
      if (data != null && mounted) {
        final list = (data is List ? data : data['results'] ?? []) as List;
        setState(() {
          _employees = list.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final currentUserId = widget.userData['id'];
      // Parse to int — backend expects integer for assigned_to
      final assignedToId = currentUserId is int
          ? currentUserId
          : int.tryParse(currentUserId.toString());
      final body = {
        'name':         _name.text.trim(),
        'phone':        _phone.text.trim(),
        'email':        _email.text.trim().isEmpty ? null : _email.text.trim(),
        'company_name': _company.text.trim(),
        'call_status':  _status,
        'interest':     _interest,
        'notes':        _notes.text.trim(),
        // Auto-assign to current user on create (same as web)
        if (widget.call == null && assignedToId != null)
          'assigned_to': assignedToId,
      };
      debugPrint('🔵 Save body assigned_to=$assignedToId (raw=${widget.userData['id']})');
      if (widget.call != null) {
        final res = await ApiService.request(
            endpoint: '/capital/customers/${widget.call!['id']}/',
            method: 'PATCH', body: body);
        debugPrint('🔵 Update call: ${res['status']}');
      } else {
        final res = await ApiService.post('/capital/customers/', body);
        debugPrint('🔵 Create call: ${res['status']} | assigned_to=$currentUserId');
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _email.dispose();
    _company.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.grey.shade300;

    InputDecoration _dec(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
          hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary)),
        );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.call != null ? 'Edit Call' : 'Add Call',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                IconButton(
                    icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _name,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: _dec('Name', hint: 'Enter contact name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      keyboardType: TextInputType.phone,
                      decoration: _dec('Phone *', hint: 'Enter phone number'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec('Email', hint: 'Enter email address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _company,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: _dec('Company Name', hint: 'Enter company name'),
                    ),
                    const SizedBox(height: 16),
                    // Interest pills
                    Text('Interested In',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700])),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _interestLabels.entries.map((e) {
                        final active = _interest == e.key;
                        final bg2 = _interestColors[e.key] ?? const Color(0xFFF5F5F5);
                        final txt = _interestTextColors[e.key] ?? Colors.grey;
                        return GestureDetector(
                          onTap: () => setState(() => _interest = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? (isDark ? bg2.withOpacity(0.35) : bg2)
                                  : (isDark ? Colors.white10 : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: active ? txt : Colors.transparent, width: 1.5),
                            ),
                            child: Text(e.value,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                    color: active
                                        ? txt
                                        : (isDark ? Colors.white54 : Colors.grey[600]))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Call Status
                    Text('Call Status',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey[700])),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _status,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                      decoration: _dec('Call Status'),
                      items: const [
                        DropdownMenuItem(value: 'pending',       child: Text('Pending')),
                        DropdownMenuItem(value: 'answered',      child: Text('Answered')),
                        DropdownMenuItem(value: 'not_answered',  child: Text('Not Answered')),
                        DropdownMenuItem(value: 'busy',          child: Text('Busy')),
                        DropdownMenuItem(value: 'not_interested',child: Text('Not Interested')),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 3,
                      decoration: _dec('Notes', hint: 'Add any additional notes...'),
                    ),
                    const SizedBox(height: 20),
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
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(widget.call != null ? 'Update Call' : 'Add Call',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
