import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../services/api_service.dart';

const Color _loanPrimary = Color(0xFF1565C0);

const _loanStatusColors = {
  'inquiry': Color(0xFFE3F2FD), 'documents_pending': Color(0xFFFFF9C4),
  'under_review': Color(0xFFF3E5F5), 'approved': Color(0xFFE8F5E9),
  'disbursed': Color(0xFFE0F2F1), 'rejected': Color(0xFFFFEBEE), 'closed': Color(0xFFF5F5F5),
};
const _loanStatusTextColors = {
  'inquiry': Color(0xFF1565C0), 'documents_pending': Color(0xFFF9A825),
  'under_review': Color(0xFF6A1B9A), 'approved': Color(0xFF2E7D32),
  'disbursed': Color(0xFF00695C), 'rejected': Color(0xFFC62828), 'closed': Colors.grey,
};
const _loanTypeLabels = {
  'personal':'Personal Loan', 'business':'Business Loan', 'home':'Home Loan',
  'vehicle':'Vehicle Loan', 'education':'Education Loan', 'gold':'Gold Loan',
  'mortgage':'Mortgage Loan', 'property':'Property Loan', 'other':'Other',
};
const _loanStatuses = [
  ('inquiry','Inquiry'), ('documents_pending','Docs Pending'),
  ('under_review','Under Review'), ('approved','Approved'),
  ('disbursed','Disbursed'), ('rejected','Rejected'), ('closed','Closed'),
];
const _loanTypes = [
  ('personal','Personal Loan'), ('business','Business Loan'), ('home','Home Loan'),
  ('vehicle','Vehicle Loan'), ('education','Education Loan'), ('gold','Gold Loan'),
  ('mortgage','Mortgage Loan'), ('property','Property Loan'), ('other','Other'),
];

String _fmtLoanType(String t) => _loanTypeLabels[t] ??
    t.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

String _cleanPhone(String raw) {
  if (raw.isEmpty) return raw;
  final d = double.tryParse(raw);
  if (d != null) return d.toInt().toString();
  return raw.replaceAll('.0', '');
}

String _fmtStatus(String s) {
  const m = {
    'inquiry':'Inquiry', 'documents_pending':'Docs Pending', 'under_review':'Under Review',
    'approved':'Approved', 'disbursed':'Disbursed', 'rejected':'Rejected', 'closed':'Closed',
  };
  return m[s] ?? s;
}

String _fmtAmount(dynamic v) {
  if (v == null || v.toString().isEmpty) return '—';
  final n = double.tryParse(v.toString());
  if (n == null) return '—';
  return '₹${NumberFormat('#,##,###').format(n)}';
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class CapitalLoansScreen extends StatefulWidget {
  final bool isManager;
  final Map<String, dynamic> userData;
  const CapitalLoansScreen({super.key, this.isManager = false, required this.userData});
  @override
  State<CapitalLoansScreen> createState() => _CapitalLoansScreenState();
}

class _CapitalLoansScreenState extends State<CapitalLoansScreen> {
  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;
  int _page = 1, _totalPages = 1, _totalCount = 0;
  static const int _pageSize = 20;
  String _search = '', _statusFilter = '', _typeFilter = '';
  final _searchCtrl = TextEditingController();
  List<String> _existingLoanTypes = []; // custom types from API

  @override
  void initState() { super.initState(); _load(); _fetchLoanTypes(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // Fetch all unique loan types from the backend
  Future<void> _fetchLoanTypes() async {
    try {
      final res = await ApiService.get('/capital/loans/?page_size=500');
      final results = (res['data']?['results'] as List? ?? []);
      final types = results
          .map((l) => (l['loan_type'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      if (mounted) setState(() => _existingLoanTypes = types);
    } catch (_) {}
  }

  // All loan types: predefined + any custom ones from API
  List<(String, String)> get _allLoanTypes {
    final predefined = _loanTypes.map((t) => t.$1).toSet();
    final custom = _existingLoanTypes
        .where((t) => !predefined.contains(t))
        .map((t) => (t, _fmtLoanType(t)));
    return [..._loanTypes, ...custom];
  }

  String _buildEndpoint() {
    final p = <String, String>{'page': '$_page', 'page_size': '$_pageSize'};
    if (_search.isNotEmpty) p['search'] = _search;
    if (_statusFilter.isNotEmpty) p['status'] = _statusFilter;
    if (_typeFilter.isNotEmpty) p['loan_type'] = _typeFilter;
    return '/capital/loans/?${p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(_buildEndpoint());
      final data = res['data'];
      if (mounted) {
        final results = (data?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        setState(() {
          _loans = results;
          _totalCount = data?['count'] ?? 0;
          _totalPages = _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _quickUpdateStatus(String id, String status) async {
    await ApiService.request(endpoint: '/capital/loans/$id/', method: 'PATCH', body: {'status': status});
    _load();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Loan'),
        content: const Text('Delete this loan record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await ApiService.delete('/capital/loans/$id/');
    _load();
  }

  void _openForm({Map<String, dynamic>? loan}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _LoanFormSheet(
        loan: loan, userData: widget.userData,
        extraLoanTypes: _existingLoanTypes,
        onSaved: () { Navigator.pop(context); _load(); _fetchLoanTypes(); },
      ),
    );
  }

  void _showDetail(Map<String, dynamic> loan) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _LoanDetailSheet(
        loan: loan,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onEdit: () { Navigator.pop(context); _openForm(loan: loan); },
        onDelete: () { Navigator.pop(context); _delete(loan['id'].toString()); },
        onStatusChange: (s) { Navigator.pop(context); _quickUpdateStatus(loan['id'].toString(), s); },
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String tmpStatus = _statusFilter, tmpType = _typeFilter;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget section(String title, List<(String, String)> opts, String cur, void Function(String) onTap) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700]))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) {
                final active = cur == o.$1;
                return GestureDetector(
                  onTap: () => setLocal(() => onTap(o.$1)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? _loanPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? _loanPrimary : Colors.transparent),
                    ),
                    child: Text(o.$2, style: TextStyle(fontSize: 12,
                        color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              }).toList()),
            ),
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => setLocal(() { tmpStatus = ''; tmpType = ''; }),
                  child: const Text('Clear All', style: TextStyle(color: _loanPrimary))),
            ]),
          ),
          section('Status', [('', 'All'), ..._loanStatuses], tmpStatus, (v) => tmpStatus = v),
          section('Loan Type', [('', 'All'), ..._allLoanTypes], tmpType, (v) => tmpType = v),
          Padding(padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { _statusFilter = tmpStatus; _typeFilter = tmpType; });
                  _load(resetPage: true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _loanPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Apply Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Loans'];
      final headers = ['Applicant Name*', 'Phone*', 'Loan Type', 'Status'];
      final example = ['John Doe', '9876543210', 'personal', 'inquiry'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = xl.TextCellValue(headers[i]);
      }
      for (int j = 0; j < example.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1))
            .value = xl.TextCellValue(example[j]);
      }
      // Remove all sheets except 'Loans'
      for (final name in excel.sheets.keys.toList()) {
        if (name != 'Loans') excel.delete(name);
      }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir!.path}/capital_loans_template_$ts.xlsx';
      File(filePath).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Template saved to Downloads', filePath);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result == null || result.files.single.path == null) return;
      final bytes = File(result.files.single.path!).readAsBytesSync();
      final excel = xl.Excel.decodeBytes(bytes);
      final loans = <Map<String, dynamic>>[];
      for (final table in excel.tables.values) {
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final name  = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          final phone = _cleanPhone(row.length > 1 ? (row[1]?.value?.toString() ?? '') : '');
          if (name.isEmpty && phone.isEmpty) continue;
          loans.add({
            'applicant_name': name, 'phone': phone,
            if (row.length > 2 && row[2]?.value != null) 'email': row[2]!.value.toString(),
            if (row.length > 3 && row[3]?.value != null) 'address': row[3]!.value.toString(),
            'loan_type': row.length > 4 ? (row[4]?.value?.toString() ?? 'personal') : 'personal',
            if (row.length > 5 && row[5]?.value != null) 'loan_amount': row[5]!.value.toString(),
            if (row.length > 6 && row[6]?.value != null) 'tenure_months': int.tryParse(row[6]!.value.toString()),
            if (row.length > 7 && row[7]?.value != null) 'interest_rate': row[7]!.value.toString(),
            if (row.length > 8 && row[8]?.value != null) 'bank_name': row[8]!.value.toString(),
            if (row.length > 9 && row[9]?.value != null) 'notes': row[9]!.value.toString(),
          });
        }
        break;
      }
      if (loans.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid rows found'))); return; }
      final res = await ApiService.post('/capital/loans/bulk_import/', {'loans': loans});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? 'Imported ${loans.length} loans' : 'Import failed'),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) _load(resetPage: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final res = await ApiService.get('/capital/loans/?page_size=2000${_statusFilter.isNotEmpty ? '&status=$_statusFilter' : ''}${_typeFilter.isNotEmpty ? '&loan_type=$_typeFilter' : ''}${_search.isNotEmpty ? '&search=${Uri.encodeComponent(_search)}' : ''}');
      final all = (res['data']?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      final excel = xl.Excel.createExcel();
      final sheet = excel['Loans'];
      final headers = ['Applicant Name', 'Phone', 'Email', 'Address', 'Loan Type', 'Amount', 'Tenure', 'Interest Rate', 'Bank', 'Status', 'Assigned To', 'Notes', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = xl.TextCellValue(headers[i]);
      }
      for (int i = 0; i < all.length; i++) {
        final l = all[i];
        final row = [l['applicant_name'] ?? '', l['phone'] ?? '', l['email'] ?? '', l['address'] ?? '',
          _fmtLoanType(l['loan_type'] ?? ''), l['loan_amount'] ?? '', l['tenure_months']?.toString() ?? '',
          l['interest_rate'] ?? '', l['bank_name'] ?? '', l['status'] ?? '',
          l['assigned_to_name'] ?? '', l['notes'] ?? '', l['created_at'] ?? ''];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)).value = xl.TextCellValue(row[j].toString());
        }
      }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir!.path}/capital_loans_$ts.xlsx';
      File(filePath).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Exported ${all.length} loans to Downloads', filePath);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  int get _filterCount => (_statusFilter.isNotEmpty ? 1 : 0) + (_typeFilter.isNotEmpty ? 1 : 0);

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12121C) : Colors.grey[50]!;
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Toolbar ──
          Container(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone...',
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey[500]),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey[500], size: 18),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.white38 : Colors.grey[500]),
                                  onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); _load(resetPage: true); })
                              : null,
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _loanPrimary)),
                        ),
                        onChanged: (v) {
                          setState(() => _search = v);
                          Future.delayed(const Duration(milliseconds: 500), () { if (_search == v) _load(resetPage: true); });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.filter_list_rounded, size: 16),
                          label: const Text('Filter', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _filterCount > 0 ? _loanPrimary : (isDark ? Colors.white70 : Colors.grey[700]),
                            side: BorderSide(color: _filterCount > 0 ? _loanPrimary : (isDark ? Colors.white24 : Colors.grey.shade300)),
                            backgroundColor: _filterCount > 0 ? _loanPrimary.withOpacity(0.08) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (_filterCount > 0)
                          Positioned(right: 4, top: 4,
                            child: Container(padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text('$_filterCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.file_download_rounded, size: 14),
                      label: const Text('Template', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _importFromExcel,
                      icon: const Icon(Icons.upload_rounded, size: 14),
                      label: const Text('Import', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _exportToExcel,
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text('Export($_totalCount)', style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
          // ── Summary bar ──
          Container(
            height: 58,
            color: isDark ? const Color(0xFF12121C) : Colors.grey[50],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _summaryChip('Total', _totalCount, Colors.blueGrey, card, isDark),
                ..._loanStatuses.map((s) {
                  final cnt = _loans.where((l) => l['status'] == s.$1).length;
                  return _summaryChip(s.$2, cnt, _loanStatusTextColors[s.$1] ?? Colors.grey, card, isDark);
                }),
              ],
            ),
          ),
          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _loanPrimary))
                : _loans.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.account_balance_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No loans found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: () => _openForm(), child: const Text('Add first loan')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: () => _load(resetPage: true),
                        color: _loanPrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _loans.length,
                          itemBuilder: (_, i) => _LoanCard(
                            loan: _loans[i], isDark: isDark, cardColor: card,
                            onTap: () => _showDetail(_loans[i]),
                            onEdit: () => _openForm(loan: _loans[i]),
                            onDelete: () => _delete(_loans[i]['id'].toString()),
                          ),
                        ),
                      ),
          ),
          // ── Pagination ──
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: card,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -2))]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(_page - 1) * _pageSize + 1}–${(_page * _pageSize).clamp(0, _totalCount)} of $_totalCount',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600])),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                    Text('$_page / $_totalPages', style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87)),
                    IconButton(icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                  ]),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _loanPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color, Color card, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey[600])),
      ]),
    );
  }
}

// ── Loan Card ─────────────────────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final bool isDark;
  final Color cardColor;
  final VoidCallback onTap, onEdit, onDelete;

  const _LoanCard({required this.loan, required this.isDark, required this.cardColor,
      required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] ?? 'inquiry';
    final statusTxt = _loanStatusTextColors[status] ?? Colors.grey;
    final name = loan['applicant_name'] ?? 'Unknown';
    final phone = (loan['phone'] ?? '').toString();
    final loanType = _fmtLoanType(loan['loan_type'] ?? '');
    final amount = _fmtAmount(loan['loan_amount']);
    final bank = (loan['bank_name'] ?? '').toString();
    final assigned = (loan['assigned_to_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: statusTxt.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.account_balance_rounded, color: statusTxt, size: 20),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
            color: isDark ? Colors.white : Colors.black87)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (phone.isNotEmpty)
            Text(phone, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _loanPrimary.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(loanType, style: const TextStyle(fontSize: 10, color: _loanPrimary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
          ]),
          if (bank.isNotEmpty)
            Text(bank, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500])),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusTxt.withOpacity(isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(_fmtStatus(status), style: TextStyle(fontSize: 10, color: statusTxt, fontWeight: FontWeight.w600)),
          ),
          if (assigned.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(assigned, style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[400])),
          ],
        ]),
        onTap: onTap,
      ),
    );
  }
}

// ── Loan Detail Sheet ─────────────────────────────────────────────────────────

class _LoanDetailSheet extends StatelessWidget {
  final Map<String, dynamic> loan;
  final bool isDark;
  final VoidCallback onEdit, onDelete;
  final void Function(String) onStatusChange;

  const _LoanDetailSheet({required this.loan, required this.isDark,
      required this.onEdit, required this.onDelete, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status = loan['status'] ?? 'inquiry';
    final statusTxt = _loanStatusTextColors[status] ?? Colors.grey;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final div = isDark ? Colors.white12 : Colors.grey.shade200;
    final phone = (loan['phone'] ?? '').toString();
    final email = (loan['email'] ?? '').toString();
    final address = (loan['address'] ?? '').toString();
    final bank = (loan['bank_name'] ?? '').toString();
    final notes = (loan['notes'] ?? '').toString();
    final assigned = (loan['assigned_to_name'] ?? '').toString();
    final amount = _fmtAmount(loan['loan_amount']);
    final tenure = loan['tenure_months'] != null ? '${loan['tenure_months']} months' : '—';
    final rate = loan['interest_rate'] != null ? '${loan['interest_rate']}% p.a.' : '—';

    // EMI calculation
    String emiStr = '—';
    if (loan['loan_amount'] != null && loan['tenure_months'] != null && loan['interest_rate'] != null) {
      final p = double.tryParse(loan['loan_amount'].toString()) ?? 0;
      final r = (double.tryParse(loan['interest_rate'].toString()) ?? 0) / 12 / 100;
      final n = (loan['tenure_months'] as num).toDouble();
      if (r > 0 && n > 0) {
        final emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
        emiStr = _fmtAmount(emi.toStringAsFixed(2));
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: ctrl, padding: EdgeInsets.zero, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              Container(width: 50, height: 50,
                  decoration: BoxDecoration(color: statusTxt.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_rounded, color: statusTxt, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loan['applicant_name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(_fmtLoanType(loan['loan_type'] ?? ''),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
              ])),
              IconButton(icon: const Icon(Icons.edit_rounded, color: _loanPrimary, size: 20), onPressed: onEdit),
              IconButton(
                icon: const Icon(Icons.task_alt_rounded, color: Color(0xFF1565C0), size: 20),
                tooltip: 'Add Task',
                onPressed: () {
                  Navigator.pop(context);
                  _showAddTaskForLoan(context);
                },
              ),
              IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20), onPressed: onDelete),
            ]),
          ),
          Divider(color: div, height: 20),
          // Status dropdown
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _pickStatus(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (_loanStatusColors[status] ?? const Color(0xFFF5F5F5)).withOpacity(isDark ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusTxt.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Loan Status', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                  Row(children: [
                    Text(_fmtStatus(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusTxt)),
                    Icon(Icons.arrow_drop_down, size: 18, color: statusTxt),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Call button
          if (phone.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Call Applicant', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Divider(color: div, height: 24),
          // Info
          if (phone.isNotEmpty) _tile(Icons.phone_rounded, 'Phone', phone, isDark),
          if (email.isNotEmpty) _tile(Icons.email_rounded, 'Email', email, isDark),
          if (address.isNotEmpty) _tile(Icons.location_on_outlined, 'Address', address, isDark),
          _tile(Icons.account_balance_wallet_rounded, 'Loan Amount', amount, isDark, valueColor: const Color(0xFF2E7D32)),
          _tile(Icons.schedule_rounded, 'Tenure', tenure, isDark),
          _tile(Icons.percent_rounded, 'Interest Rate', rate, isDark),
          if (emiStr != '—') _tile(Icons.calculate_rounded, 'Monthly EMI', emiStr, isDark, valueColor: _loanPrimary),
          if (bank.isNotEmpty) _tile(Icons.account_balance_rounded, 'Bank', bank, isDark),
          if (assigned.isNotEmpty) _tile(Icons.person_outline_rounded, 'Assigned To', assigned, isDark),
          if (notes.isNotEmpty) ...[
            Divider(color: div, height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 8),
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: div),
                  ),
                  child: Text(notes, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.5)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _showAddTaskForLoan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickTaskSheet(
        loanId: loan['id'].toString(),
        loanLabel: '${loan['applicant_name'] ?? ''} · ${loan['phone'] ?? ''}',
        isDark: isDark,
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87))),
        ])),
      ]),
    );
  }

  void _pickStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(14),
            child: Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        ..._loanStatuses.map((s) {
          final txt = _loanStatusTextColors[s.$1] ?? Colors.grey;
          return ListTile(
            dense: true,
            leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: txt, shape: BoxShape.circle)),
            title: Text(s.$2, style: TextStyle(fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
            trailing: loan['status'] == s.$1 ? const Icon(Icons.check, color: _loanPrimary, size: 16) : null,
            onTap: () { Navigator.pop(context); onStatusChange(s.$1); },
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }
}

double pow(double base, double exp) {
  double result = 1;
  for (int i = 0; i < exp.toInt(); i++) result *= base;
  return result;
}

// ── Loan Form Sheet ───────────────────────────────────────────────────────────

class _LoanFormSheet extends StatefulWidget {
  final Map<String, dynamic>? loan;
  final Map<String, dynamic> userData;
  final List<String> extraLoanTypes;
  final VoidCallback onSaved;
  const _LoanFormSheet({this.loan, required this.userData, required this.onSaved, this.extraLoanTypes = const []});
  @override
  State<_LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends State<_LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name    = TextEditingController(text: widget.loan?['applicant_name'] ?? '');
  late final _phone   = TextEditingController(text: widget.loan?['phone'] ?? '');
  late final _email   = TextEditingController(text: widget.loan?['email'] ?? '');
  late final _address = TextEditingController(text: widget.loan?['address'] ?? '');
  late final _amount  = TextEditingController(text: widget.loan?['loan_amount']?.toString() ?? '');
  late final _tenure  = TextEditingController(text: widget.loan?['tenure_months']?.toString() ?? '');
  late final _rate    = TextEditingController(text: widget.loan?['interest_rate']?.toString() ?? '');
  late final _bank    = TextEditingController(text: widget.loan?['bank_name'] ?? '');
  late final _notes   = TextEditingController(text: widget.loan?['notes'] ?? '');
  String _loanType = 'personal';
  String _status   = 'inquiry';
  bool   _saving   = false;
  bool   _showCustomType = false;
  final  _customType = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loanType = widget.loan?['loan_type'] ?? 'personal';
    _status   = widget.loan?['status']    ?? 'inquiry';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _amount, _tenure, _rate, _bank, _notes, _customType]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = widget.userData['id'];
      final assignedTo = uid is int ? uid : int.tryParse(uid.toString());
      final body = <String, dynamic>{
        'applicant_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
        'loan_type': _showCustomType && _customType.text.trim().isNotEmpty
            ? _customType.text.trim().toLowerCase().replaceAll(' ', '_')
            : _loanType,
        if (_amount.text.trim().isNotEmpty) 'loan_amount': _amount.text.trim(),
        if (_tenure.text.trim().isNotEmpty) 'tenure_months': int.tryParse(_tenure.text.trim()),
        if (_rate.text.trim().isNotEmpty) 'interest_rate': _rate.text.trim(),
        if (_bank.text.trim().isNotEmpty) 'bank_name': _bank.text.trim(),
        'status': _status,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (widget.loan == null && assignedTo != null) 'assigned_to': assignedTo,
      };
      final res = widget.loan != null
          ? await ApiService.request(endpoint: '/capital/loans/${widget.loan!['id']}/', method: 'PATCH', body: body)
          : await ApiService.post('/capital/loans/', body);
      if (res['success'] == true) {
        widget.onSaved();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${res['data']?['detail'] ?? res['data']?.toString() ?? 'Error'}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final ts = TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87);

    InputDecoration dec(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _loanPrimary)),
    );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.loan != null ? 'Edit Loan' : 'Add Loan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
            IconButton(icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(children: [
              TextFormField(controller: _name, style: ts, decoration: dec('Applicant Name *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, style: ts,
                  keyboardType: TextInputType.phone, decoration: dec('Phone *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _email, style: ts,
                  keyboardType: TextInputType.emailAddress, decoration: dec('Email')),
              const SizedBox(height: 12),
              TextFormField(controller: _address, style: ts, decoration: dec('Address')),
              const SizedBox(height: 12),
              // Loan Type with custom option
              if (!_showCustomType)
                DropdownButtonFormField<String>(
                  value: _loanType,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Loan Type'),
                  items: [
                    // Predefined types
                    ..._loanTypes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))),
                    // Custom types from API (not in predefined list)
                    ...widget.extraLoanTypes
                        .where((t) => !_loanTypes.any((p) => p.$1 == t))
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_fmtLoanType(t),
                                  style: const TextStyle(fontStyle: FontStyle.italic)),
                            )),
                    // Add new custom type option
                    const DropdownMenuItem(
                      value: '__custom__',
                      child: Text('+ Add Custom Type',
                          style: TextStyle(color: _loanPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '__custom__') {
                      setState(() { _showCustomType = true; _customType.clear(); });
                    } else {
                      setState(() => _loanType = v!);
                    }
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customType,
                        autofocus: true,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: dec('Custom Loan Type *'),
                        validator: (v) => _showCustomType && (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white54 : Colors.grey),
                      onPressed: () => setState(() { _showCustomType = false; _loanType = 'personal'; }),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _amount, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Amount (₹)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _tenure, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Tenure (months)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _rate, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Interest Rate (%)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _bank, style: ts,
                    decoration: dec('Bank Name'))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                style: ts,
                dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                decoration: dec('Status'),
                items: _loanStatuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, style: ts,
                  maxLines: 3, decoration: dec('Notes')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _loanPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.loan != null ? 'Update Loan' : 'Add Loan',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          ),
        ),
      ]),
    );
  }
}

// ── Quick Task Sheet (Add task linked to a loan) ──────────────────────────────

class _QuickTaskSheet extends StatefulWidget {
  final String loanId;
  final String loanLabel;
  final bool isDark;
  const _QuickTaskSheet({required this.loanId, required this.loanLabel, required this.isDark});
  @override
  State<_QuickTaskSheet> createState() => _QuickTaskSheetState();
}

class _QuickTaskSheetState extends State<_QuickTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  final _due   = TextEditingController();
  String _status   = 'in_progress';
  String _priority = 'medium';
  bool   _saving   = false;

  static const _statuses = [
    ('in_progress','In Progress'), ('follow_up','Follow Up'),
    ('document_collection','Doc Collection'), ('processing','Processing'),
    ('completed','Completed'), ('rejected','Rejected'),
  ];
  static const _priorities = [
    ('low','Low'), ('medium','Medium'), ('high','High'), ('urgent','Urgent'),
  ];

  @override
  void dispose() { _title.dispose(); _desc.dispose(); _due.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.post('/capital/tasks/', {
        'title': _title.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'status': _status,
        'priority': _priority,
        'loan': int.tryParse(widget.loanId),
        if (_due.text.trim().isNotEmpty) 'due_date': _due.text.trim(),
      });
      if (res['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task added successfully'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${res['data']?.toString() ?? 'Error'}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final ts = TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87);

    InputDecoration dec(String label, {String? hint}) => InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
      filled: true, fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _loanPrimary)),
    );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
              Text(widget.loanLabel, style: TextStyle(fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey[600])),
            ]),
            IconButton(icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(children: [
              TextFormField(controller: _title, style: ts, decoration: dec('Task Title *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, style: ts, maxLines: 2, decoration: dec('Description')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _status, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Status'),
                  items: _statuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _priority, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Priority'),
                  items: _priorities.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _due, style: ts,
                decoration: dec('Due Date', hint: 'YYYY-MM-DD'),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _due.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _loanPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Add Task', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          ),
        ),
      ]),
    );
  }
}
