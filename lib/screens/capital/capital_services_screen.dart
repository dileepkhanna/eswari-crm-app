import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../services/api_service.dart';

const Color _svcPrimary = Color(0xFF1565C0);

// ── Constants ─────────────────────────────────────────────────────────────────

const _svcStatusColors = {
  'inquiry': Color(0xFFE3F2FD), 'documents_pending': Color(0xFFFFF9C4),
  'in_progress': Color(0xFFF3E5F5), 'completed': Color(0xFFE8F5E9), 'rejected': Color(0xFFFFEBEE),
};
const _svcStatusTextColors = {
  'inquiry': Color(0xFF1565C0), 'documents_pending': Color(0xFFF9A825),
  'in_progress': Color(0xFF6A1B9A), 'completed': Color(0xFF2E7D32), 'rejected': Color(0xFFC62828),
};
const _svcStatuses = [
  ('inquiry','Inquiry'), ('documents_pending','Docs Pending'),
  ('in_progress','In Progress'), ('completed','Completed'), ('rejected','Rejected'),
];

const _serviceCategory = {
  'gst_registration':'GST', 'gst_filing_monthly':'GST', 'gst_filing_quarterly':'GST',
  'gst_amendment':'GST', 'gst_cancellation':'GST', 'lut_filing':'GST',
  'eway_bill':'GST', 'gst_consultation':'GST',
  'msme_registration':'MSME', 'msme_certificate':'MSME', 'msme_amendment':'MSME',
  'itr_filing':'ITR', 'itr_notice':'ITR',
};
const _categoryColors = {
  'GST': Color(0xFFE65100), 'MSME': Color(0xFF00695C), 'ITR': Color(0xFF4527A0),
};

const _serviceTypes = [
  ('gst_registration','GST Registration'), ('gst_filing_monthly','GST Filing (Monthly)'),
  ('gst_filing_quarterly','GST Filing (Quarterly)'), ('gst_amendment','GST Amendment'),
  ('gst_cancellation','GST Cancellation'), ('lut_filing','LUT Filing'),
  ('eway_bill','E-Way Bill'), ('gst_consultation','GST Consultation'),
  ('msme_registration','MSME Registration'), ('msme_certificate','MSME Certificate'),
  ('msme_amendment','MSME Amendment'), ('itr_filing','Income Tax Filing'),
  ('itr_notice','Income Tax Notice'), ('company_registration','Company Registration'),
  ('trademark','Trademark Registration'), ('other','Other'),
];

String _fmtSvcType(String t) {
  for (final s in _serviceTypes) { if (s.$1 == t) return s.$2; }
  return t.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

String _cleanPhone(String raw) {
  if (raw.isEmpty) return raw;
  final d = double.tryParse(raw);
  if (d != null) return d.toInt().toString();
  return raw.replaceAll('.0', '');
}

String _fmtSvcStatus(String s) {
  for (final st in _svcStatuses) { if (st.$1 == s) return st.$2; }
  return s;
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class CapitalServicesScreen extends StatefulWidget {
  final bool isManager;
  final Map<String, dynamic> userData;
  const CapitalServicesScreen({super.key, this.isManager = false, required this.userData});
  @override
  State<CapitalServicesScreen> createState() => _CapitalServicesScreenState();
}

class _CapitalServicesScreenState extends State<CapitalServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  int _page = 1, _totalPages = 1, _totalCount = 0;
  static const int _pageSize = 20;
  String _search = '', _statusFilter = '', _typeFilter = '', _categoryFilter = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String _buildEndpoint() {
    final p = <String, String>{'page': '$_page', 'page_size': '$_pageSize'};
    if (_search.isNotEmpty) p['search'] = _search;
    if (_statusFilter.isNotEmpty) p['status'] = _statusFilter;
    if (_typeFilter.isNotEmpty) p['service_type'] = _typeFilter;
    return '/capital/services/?${p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
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
          _services = results;
          _totalCount = data?['count'] ?? 0;
          _totalPages = _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _quickUpdateStatus(String id, String status) async {
    await ApiService.request(endpoint: '/capital/services/$id/', method: 'PATCH', body: {'status': status});
    _load();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text('Delete this service record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await ApiService.delete('/capital/services/$id/');
    _load();
  }

  void _openForm({Map<String, dynamic>? service}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ServiceFormSheet(
        service: service, userData: widget.userData,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  void _showDetail(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ServiceDetailSheet(
        service: service,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onEdit: () { Navigator.pop(context); _openForm(service: service); },
        onDelete: () { Navigator.pop(context); _delete(service['id'].toString()); },
        onStatusChange: (s) { Navigator.pop(context); _quickUpdateStatus(service['id'].toString(), s); },
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String tmpStatus = _statusFilter, tmpType = _typeFilter, tmpCat = _categoryFilter;
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
                      color: active ? _svcPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? _svcPrimary : Colors.transparent),
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

        // Filter service types by selected category
        final filteredTypes = tmpCat.isEmpty
            ? _serviceTypes
            : _serviceTypes.where((t) => (_serviceCategory[t.$1] ?? 'Other') == tmpCat).toList();

        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => setLocal(() { tmpStatus = ''; tmpType = ''; tmpCat = ''; }),
                  child: const Text('Clear All', style: TextStyle(color: _svcPrimary))),
            ]),
          ),
          section('Category', [('','All'),('GST','GST'),('MSME','MSME'),('ITR','Income Tax')],
              tmpCat, (v) { tmpCat = v; tmpType = ''; }),
          section('Service Type', [('', 'All'), ...filteredTypes], tmpType, (v) => tmpType = v),
          section('Status', [('', 'All'), ..._svcStatuses], tmpStatus, (v) => tmpStatus = v),
          Padding(padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { _statusFilter = tmpStatus; _typeFilter = tmpType; _categoryFilter = tmpCat; });
                  _load(resetPage: true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _svcPrimary, foregroundColor: Colors.white,
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

  void _showFileSnackbar(String msg, String filePath) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.green, duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'View', textColor: Colors.white, onPressed: () => OpenFile.open(filePath)),
    ));
  }

  Future<void> _downloadTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Services'];
      final headers = ['Client Name*', 'Phone*', 'Service Type', 'Status'];
      final example = ['Jane Doe', '9876543210', 'gst_registration', 'inquiry'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = xl.TextCellValue(headers[i]);
      }
      for (int j = 0; j < example.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1)).value = xl.TextCellValue(example[j]);
      }
      for (final name in excel.sheets.keys.toList()) { if (name != 'Services') excel.delete(name); }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fp = '${dir!.path}/capital_services_template_$ts.xlsx';
      File(fp).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Template saved to Downloads', fp);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result == null || result.files.single.path == null) return;
      final bytes = File(result.files.single.path!).readAsBytesSync();
      final excel = xl.Excel.decodeBytes(bytes);
      final services = <Map<String, dynamic>>[];
      for (final table in excel.tables.values) {
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final name  = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          final phone = _cleanPhone(row.length > 1 ? (row[1]?.value?.toString() ?? '') : '');
          if (name.isEmpty && phone.isEmpty) continue;
          services.add({
            'client_name': name, 'phone': phone,
            'service_type': row.length > 2 ? (row[2]?.value?.toString() ?? 'gst_registration') : 'gst_registration',
            'status': row.length > 3 ? (row[3]?.value?.toString() ?? 'inquiry') : 'inquiry',
          });
        }
        break;
      }
      if (services.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid rows found'))); return; }
      final res = await ApiService.post('/capital/services/bulk_import/', {'services': services});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? 'Imported ${services.length} services' : 'Import failed'),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) _load(resetPage: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportToExcel() async {
    try {
      String ep = '/capital/services/?page_size=2000';
      if (_statusFilter.isNotEmpty) ep += '&status=$_statusFilter';
      if (_typeFilter.isNotEmpty) ep += '&service_type=$_typeFilter';
      if (_search.isNotEmpty) ep += '&search=${Uri.encodeComponent(_search)}';
      final res = await ApiService.get(ep);
      final all = (res['data']?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      final excel = xl.Excel.createExcel();
      final sheet = excel['Services'];
      final headers = ['Client Name', 'Phone', 'Email', 'Business Name', 'Category', 'Service Type', 'Status', 'PAN', 'Financial Year', 'Assigned To', 'Notes', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = xl.TextCellValue(headers[i]);
      }
      for (int i = 0; i < all.length; i++) {
        final s = all[i];
        final row = [s['client_name'] ?? '', s['phone'] ?? '', s['email'] ?? '', s['business_name'] ?? '',
          _serviceCategory[s['service_type']] ?? 'Other', _fmtSvcType(s['service_type'] ?? ''),
          s['status'] ?? '', s['pan_number'] ?? '', s['financial_year'] ?? '',
          s['assigned_to_name'] ?? '', s['notes'] ?? '', s['created_at'] ?? ''];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)).value = xl.TextCellValue(row[j].toString());
        }
      }
      for (final name in excel.sheets.keys.toList()) { if (name != 'Services') excel.delete(name); }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fp = '${dir!.path}/capital_services_$ts.xlsx';
      File(fp).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Exported ${all.length} services to Downloads', fp);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  int get _filterCount => (_statusFilter.isNotEmpty ? 1 : 0) + (_typeFilter.isNotEmpty ? 1 : 0) + (_categoryFilter.isNotEmpty ? 1 : 0);

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
            child: Column(children: [
              Row(children: [
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
                      filled: true, fillColor: isDark ? Colors.white10 : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _svcPrimary)),
                    ),
                    onChanged: (v) {
                      setState(() => _search = v);
                      Future.delayed(const Duration(milliseconds: 500), () { if (_search == v) _load(resetPage: true); });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Stack(children: [
                  OutlinedButton.icon(
                    onPressed: _showFilterSheet,
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('Filter', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _filterCount > 0 ? _svcPrimary : (isDark ? Colors.white70 : Colors.grey[700]),
                      side: BorderSide(color: _filterCount > 0 ? _svcPrimary : (isDark ? Colors.white24 : Colors.grey.shade300)),
                      backgroundColor: _filterCount > 0 ? _svcPrimary.withOpacity(0.08) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (_filterCount > 0)
                    Positioned(right: 4, top: 4,
                      child: Container(padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$_filterCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _downloadTemplate,
                  icon: const Icon(Icons.file_download_rounded, size: 14),
                  label: const Text('Template', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _importFromExcel,
                  icon: const Icon(Icons.upload_rounded, size: 14),
                  label: const Text('Import', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _exportToExcel,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: Text('Export($_totalCount)', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
              ]),
            ]),
          ),
          // ── Summary bar ──
          Container(
            height: 58,
            color: isDark ? const Color(0xFF12121C) : Colors.grey[50],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('Total', _totalCount, Colors.blueGrey, card, isDark),
                ..._svcStatuses.map((s) {
                  final cnt = _services.where((sv) => sv['status'] == s.$1).length;
                  return _chip(s.$2, cnt, _svcStatusTextColors[s.$1] ?? Colors.grey, card, isDark);
                }),
              ],
            ),
          ),
          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _svcPrimary))
                : _services.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.miscellaneous_services, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No services found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: () => _openForm(), child: const Text('Add first service')),
                      ]))
                    : RefreshIndicator(
                        onRefresh: () => _load(resetPage: true),
                        color: _svcPrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _services.length,
                          itemBuilder: (_, i) => _ServiceCard(
                            service: _services[i], isDark: isDark, cardColor: card,
                            onTap: () => _showDetail(_services[i]),
                            onEdit: () => _openForm(service: _services[i]),
                            onDelete: () => _delete(_services[i]['id'].toString()),
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
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${(_page-1)*_pageSize+1}–${(_page*_pageSize).clamp(0,_totalCount)} of $_totalCount',
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
              ]),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _svcPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _chip(String label, int count, Color color, Color card, bool isDark) {
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

// ── Service Card ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isDark;
  final Color cardColor;
  final VoidCallback onTap, onEdit, onDelete;

  const _ServiceCard({required this.service, required this.isDark, required this.cardColor,
      required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = service['status'] ?? 'inquiry';
    final statusTxt = _svcStatusTextColors[status] ?? Colors.grey;
    final svcType = service['service_type'] ?? '';
    final cat = _serviceCategory[svcType] ?? 'Other';
    final catColor = _categoryColors[cat] ?? Colors.grey;
    final name = service['client_name'] ?? 'Unknown';
    final phone = (service['phone'] ?? '').toString();
    final biz = (service['business_name'] ?? '').toString();
    final assigned = (service['assigned_to_name'] ?? '').toString();

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
          decoration: BoxDecoration(color: catColor.withOpacity(0.12), shape: BoxShape.circle),
          child: Center(child: Text(cat.substring(0, cat.length > 3 ? 3 : cat.length),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor))),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
            color: isDark ? Colors.white : Colors.black87)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (phone.isNotEmpty)
            Text(phone, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
          if (biz.isNotEmpty)
            Text(biz, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500])),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: catColor.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_fmtSvcType(svcType),
                style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusTxt.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_fmtSvcStatus(status),
                style: TextStyle(fontSize: 10, color: statusTxt, fontWeight: FontWeight.w600)),
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

// ── Service Detail Sheet ──────────────────────────────────────────────────────

class _ServiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isDark;
  final VoidCallback onEdit, onDelete;
  final void Function(String) onStatusChange;

  const _ServiceDetailSheet({required this.service, required this.isDark,
      required this.onEdit, required this.onDelete, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status = service['status'] ?? 'inquiry';
    final statusTxt = _svcStatusTextColors[status] ?? Colors.grey;
    final svcType = service['service_type'] ?? '';
    final cat = _serviceCategory[svcType] ?? 'Other';
    final catColor = _categoryColors[cat] ?? Colors.grey;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final div = isDark ? Colors.white12 : Colors.grey.shade200;
    final phone = (service['phone'] ?? '').toString();
    final email = (service['email'] ?? '').toString();
    final biz = (service['business_name'] ?? '').toString();
    final city = (service['city_state'] ?? '').toString();
    final pan = (service['pan_number'] ?? '').toString();
    final fy = (service['financial_year'] ?? '').toString();
    final fee = (service['service_fee'] ?? '').toString();
    final notes = (service['notes'] ?? '').toString();
    final assigned = (service['assigned_to_name'] ?? '').toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: ctrl, padding: EdgeInsets.zero, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              Container(width: 50, height: 50,
                  decoration: BoxDecoration(color: catColor.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service['client_name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(_fmtSvcType(svcType),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
              ])),
              IconButton(icon: const Icon(Icons.edit_rounded, color: _svcPrimary, size: 20), onPressed: onEdit),
              IconButton(
                icon: const Icon(Icons.task_alt_rounded, color: Color(0xFF1565C0), size: 20),
                tooltip: 'Add Task',
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                    builder: (_) => _QuickSvcTaskSheet(
                      serviceId: service['id'].toString(),
                      serviceLabel: '${service['client_name'] ?? ''} · ${_fmtSvcType(service['service_type'] ?? '')}',
                      isDark: isDark,
                    ),
                  );
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
                  color: (_svcStatusColors[status] ?? const Color(0xFFF5F5F5)).withOpacity(isDark ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusTxt.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Service Status', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                  Row(children: [
                    Text(_fmtSvcStatus(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusTxt)),
                    Icon(Icons.arrow_drop_down, size: 18, color: statusTxt),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Call Client', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          Divider(color: div, height: 24),
          if (phone.isNotEmpty) _tile(Icons.phone_rounded, 'Phone', phone, isDark),
          if (email.isNotEmpty) _tile(Icons.email_rounded, 'Email', email, isDark),
          if (biz.isNotEmpty) _tile(Icons.business_rounded, 'Business Name', biz, isDark),
          if (city.isNotEmpty) _tile(Icons.location_on_outlined, 'City / State', city, isDark),
          if (pan.isNotEmpty) _tile(Icons.credit_card_rounded, 'PAN Number', pan, isDark),
          if (fy.isNotEmpty) _tile(Icons.calendar_today_rounded, 'Financial Year', fy, isDark),
          if (fee.isNotEmpty) _tile(Icons.currency_rupee_rounded, 'Service Fee', '₹$fee', isDark, valueColor: const Color(0xFF2E7D32)),
          if (assigned.isNotEmpty) _tile(Icons.person_outline_rounded, 'Assigned To', assigned, isDark),
          if (notes.isNotEmpty) ...[
            Divider(color: div, height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 8),
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: div)),
                  child: Text(notes, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700], height: 1.5))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
        ]),
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
        ..._svcStatuses.map((s) {
          final txt = _svcStatusTextColors[s.$1] ?? Colors.grey;
          return ListTile(
            dense: true,
            leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: txt, shape: BoxShape.circle)),
            title: Text(s.$2, style: TextStyle(fontSize: 13,
                color: isDark ? Colors.white : Colors.black87)),
            trailing: service['status'] == s.$1 ? const Icon(Icons.check, color: _svcPrimary, size: 16) : null,
            onTap: () { Navigator.pop(context); onStatusChange(s.$1); },
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }
}



// ── Service Form Sheet ────────────────────────────────────────────────────────

const _gstServices  = ['gst_registration','gst_filing_monthly','gst_filing_quarterly',
  'gst_amendment','gst_cancellation','lut_filing','eway_bill','gst_consultation'];
const _msmeServices = ['msme_registration','msme_certificate','msme_amendment'];
const _itrServices  = ['itr_filing','itr_notice'];

class _ServiceFormSheet extends StatefulWidget {
  final Map<String, dynamic>? service;
  final Map<String, dynamic> userData;
  final VoidCallback onSaved;
  const _ServiceFormSheet({this.service, required this.userData, required this.onSaved});
  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name  = TextEditingController(text: widget.service?['client_name'] ?? '');
  late final _phone = TextEditingController(text: widget.service?['phone'] ?? '');
  late final _email = TextEditingController(text: widget.service?['email'] ?? '');
  late final _biz   = TextEditingController(text: widget.service?['business_name'] ?? '');
  late final _city  = TextEditingController(text: widget.service?['city_state'] ?? '');
  late final _pan   = TextEditingController(text: widget.service?['pan_number'] ?? '');
  late final _fy    = TextEditingController(text: widget.service?['financial_year'] ?? '');
  late final _fee   = TextEditingController(text: widget.service?['service_fee']?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.service?['notes'] ?? '');
  late final _gstin = TextEditingController(text: widget.service?['gstin'] ?? '');
  late final _udyam = TextEditingController(text: widget.service?['udyam_number'] ?? '');
  late final _dob   = TextEditingController(text: widget.service?['date_of_birth'] ?? '');

  String _svcType      = 'gst_registration';
  String _status       = 'inquiry';
  String _bizType      = '';
  String _turnover     = '';
  String _existingGst  = '';
  String _existingMsme = '';
  String _incomeSlab   = '';
  List<String> _incomeNature = [];
  bool _saving = false;

  bool get _isGST  => _gstServices.contains(_svcType);
  bool get _isMSME => _msmeServices.contains(_svcType);
  bool get _isITR  => _itrServices.contains(_svcType);

  @override
  void initState() {
    super.initState();
    _svcType      = widget.service?['service_type']             ?? 'gst_registration';
    _status       = widget.service?['status']                   ?? 'inquiry';
    _bizType      = widget.service?['business_type']            ?? '';
    _turnover     = widget.service?['turnover_range']           ?? '';
    _existingGst  = widget.service?['existing_gst_number']?.toString()  ?? '';
    _existingMsme = widget.service?['existing_msme_number']?.toString() ?? '';
    _incomeSlab   = widget.service?['income_slab']              ?? '';
    _incomeNature = List<String>.from(widget.service?['income_nature'] ?? []);
  }

  @override
  void dispose() {
    for (final c in [_name,_phone,_email,_biz,_city,_pan,_fy,_fee,_notes,_gstin,_udyam,_dob]) c.dispose();
    super.dispose();
  }

  void _toggleNature(String val) => setState(() {
    _incomeNature.contains(val) ? _incomeNature.remove(val) : _incomeNature.add(val);
  });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = widget.userData['id'];
      final assignedTo = uid is int ? uid : int.tryParse(uid.toString());
      final body = <String, dynamic>{
        'client_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'service_type': _svcType,
        'status': _status,
        'financial_year': _fy.text.trim(),
        if (_biz.text.trim().isNotEmpty) 'business_name': _biz.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city_state': _city.text.trim(),
        if (_pan.text.trim().isNotEmpty) 'pan_number': _pan.text.trim(),
        if (_fee.text.trim().isNotEmpty) 'service_fee': _fee.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (widget.service == null && assignedTo != null) 'assigned_to': assignedTo,
        if ((_isGST || _isMSME) && _bizType.isNotEmpty) 'business_type': _bizType,
        if (_isGST && _turnover.isNotEmpty) 'turnover_range': _turnover,
        if (_isGST && _existingGst.isNotEmpty) 'existing_gst_number': _existingGst == 'true',
        if (_isGST && _existingGst == 'true' && _gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim(),
        if (_isMSME && _existingMsme.isNotEmpty) 'existing_msme_number': _existingMsme == 'true',
        if (_isMSME && _existingMsme == 'true' && _udyam.text.trim().isNotEmpty) 'udyam_number': _udyam.text.trim(),
        if (_isITR && _dob.text.trim().isNotEmpty) 'date_of_birth': _dob.text.trim(),
        if (_isITR && _incomeNature.isNotEmpty) 'income_nature': _incomeNature,
        if (_isITR && _incomeSlab.isNotEmpty) 'income_slab': _incomeSlab,
      };
      final res = widget.service != null
          ? await ApiService.request(endpoint: '/capital/services/${widget.service!['id']}/', method: 'PATCH', body: body)
          : await ApiService.post('/capital/services/', body);
      if (res['success'] == true) {
        widget.onSaved();
      } else {
        if (mounted) {
          final data = res['data'];
          String errMsg = 'Failed to save';
          if (data is Map && data.isNotEmpty) {
            final k = data.keys.first;
            final v = data[k];
            errMsg = '$k: ${v is List ? v.first : v}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final ts = TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87);

    InputDecoration dec(String label, {String? hint}) => InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700]),
      hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey[400]),
      filled: true, fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _svcPrimary)),
    );

    Widget ddField(String label, String val, List<(String,String)> opts, void Function(String) onChange) {
      return DropdownButtonFormField<String>(
        value: val.isEmpty ? null : val,
        style: ts, dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        decoration: dec(label),
        items: [
          DropdownMenuItem(value: '', child: Text('Select...', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]))),
          ...opts.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))),
        ],
        onChanged: (v) => setState(() => onChange(v ?? '')),
      );
    }

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.service != null ? 'Edit Service' : 'Add Service',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            IconButton(icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Service Type
              DropdownButtonFormField<String>(
                value: _svcType, style: ts,
                dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                decoration: dec('Service Type *'),
                items: _serviceTypes.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                onChanged: (v) => setState(() { _svcType = v!; _existingGst = ''; _existingMsme = ''; }),
              ),
              const SizedBox(height: 12),

              // Basic
              TextFormField(controller: _name, style: ts, decoration: dec('Client Name *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, style: ts, keyboardType: TextInputType.phone,
                  decoration: dec('Phone *'), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _email, style: ts,
                    keyboardType: TextInputType.emailAddress, decoration: dec('Email'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _city, style: ts, decoration: dec('City / State'))),
              ]),

              // GST / MSME: Business fields
              if (_isGST || _isMSME) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _biz, style: ts, decoration: dec('Business Name')),
                const SizedBox(height: 12),
                ddField('Type of Business', _bizType, [
                  ('proprietor','Proprietor'), ('partnership','Partnership'), ('company','Company'),
                ], (v) => _bizType = v),
              ],

              // GST specific
              if (_isGST) ...[
                const SizedBox(height: 12),
                ddField('Turnover Range', _turnover, [
                  ('below_20l','Below ₹20 Lakhs'), ('20l_1cr','₹20L – ₹1 Cr'), ('above_1cr','Above ₹1 Cr'),
                ], (v) => _turnover = v),
                const SizedBox(height: 12),
                ddField('Existing GST Number?', _existingGst, [('false','No'), ('true','Yes')], (v) => _existingGst = v),
                if (_existingGst == 'true') ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _gstin, style: ts,
                      decoration: dec('GSTIN', hint: '15-digit GSTIN'),
                      maxLength: 15, textCapitalization: TextCapitalization.characters),
                ],
              ],

              // MSME specific
              if (_isMSME) ...[
                const SizedBox(height: 12),
                ddField('Existing MSME Number?', _existingMsme, [('false','No'), ('true','Yes')], (v) => _existingMsme = v),
                if (_existingMsme == 'true') ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _udyam, style: ts,
                      decoration: dec('Udyam Number', hint: 'UDYAM-XX-00-0000000')),
                ],
              ],

              // ITR specific
              if (_isITR) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _dob, style: ts,
                    decoration: dec('Date of Birth', hint: 'YYYY-MM-DD'),
                    keyboardType: TextInputType.datetime),
                const SizedBox(height: 12),
                Text('Income Nature', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ('salaried','Salaried'), ('shares','Shares'), ('rental','Rental'), ('other','Other'),
                ].map((o) {
                  final active = _incomeNature.contains(o.$1);
                  return GestureDetector(
                    onTap: () => _toggleNature(o.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? _svcPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? _svcPrimary : Colors.transparent),
                      ),
                      child: Text(o.$2, style: TextStyle(fontSize: 12,
                          color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                ddField('Income Slab', _incomeSlab, [
                  ('0_5l','0 to ₹5 Lakh'), ('5l_10l','₹5L to ₹10L'),
                  ('10l_18l','₹10L to ₹18L'), ('above_18l','Above ₹18L'),
                ], (v) => _incomeSlab = v),
              ],

              // PAN + Financial Year
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _pan, style: ts,
                    decoration: dec('PAN Number', hint: 'ABCDE1234F'),
                    maxLength: 10, textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _fy, style: ts,
                    decoration: dec('Financial Year', hint: '2024-25'))),
              ]),

              // Status + Fee
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _status, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Status'),
                  items: _svcStatuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _fee, style: ts,
                    keyboardType: TextInputType.number, decoration: dec('Service Fee (₹)'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, style: ts, maxLines: 3, decoration: dec('Notes')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _svcPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.service != null ? 'Update Service' : 'Add Service',
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

// ── Quick Task Sheet (linked to a service) ────────────────────────────────────

class _QuickSvcTaskSheet extends StatefulWidget {
  final String serviceId;
  final String serviceLabel;
  final bool isDark;
  const _QuickSvcTaskSheet({required this.serviceId, required this.serviceLabel, required this.isDark});
  @override
  State<_QuickSvcTaskSheet> createState() => _QuickSvcTaskSheetState();
}

class _QuickSvcTaskSheetState extends State<_QuickSvcTaskSheet> {
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
        'service': int.tryParse(widget.serviceId),
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
          borderSide: const BorderSide(color: _svcPrimary)),
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
              Text(widget.serviceLabel, style: TextStyle(fontSize: 11,
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
                  style: ElevatedButton.styleFrom(backgroundColor: _svcPrimary, foregroundColor: Colors.white,
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
