import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../services/api_service.dart';

const Color _taskPrimary = Color(0xFF1565C0);

// ── Constants ─────────────────────────────────────────────────────────────────

const _taskStatusColors = {
  'in_progress':         Color(0xFFE3F2FD),
  'follow_up':           Color(0xFFFFF9C4),
  'document_collection': Color(0xFFFFF3E0),
  'processing':          Color(0xFFF3E5F5),
  'completed':           Color(0xFFE8F5E9),
  'rejected':            Color(0xFFFFEBEE),
};
const _taskStatusTextColors = {
  'in_progress':         Color(0xFF1565C0),
  'follow_up':           Color(0xFFF9A825),
  'document_collection': Color(0xFFE65100),
  'processing':          Color(0xFF6A1B9A),
  'completed':           Color(0xFF2E7D32),
  'rejected':            Color(0xFFC62828),
};
const _priorityColors = {
  'low':    Color(0xFFF5F5F5),
  'medium': Color(0xFFFFF9C4),
  'high':   Color(0xFFFFF3E0),
  'urgent': Color(0xFFFFEBEE),
};
const _priorityTextColors = {
  'low':    Color(0xFF757575),
  'medium': Color(0xFFF9A825),
  'high':   Color(0xFFE65100),
  'urgent': Color(0xFFC62828),
};
const _taskStatuses = [
  ('in_progress','In Progress'), ('follow_up','Follow Up'),
  ('document_collection','Doc Collection'), ('processing','Processing'),
  ('completed','Completed'), ('rejected','Rejected'),
];
const _taskPriorities = [
  ('low','Low'), ('medium','Medium'), ('high','High'), ('urgent','Urgent'),
];

String _fmtTaskStatus(String s) {
  for (final st in _taskStatuses) { if (st.$1 == s) return st.$2; }
  return s.replaceAll('_', ' ');
}
String _fmtPriority(String p) {
  for (final pr in _taskPriorities) { if (pr.$1 == p) return pr.$2; }
  return p;
}
String _fmtDue(String? d) {
  if (d == null || d.isEmpty) return '—';
  try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class CapitalTasksScreen extends StatefulWidget {
  final bool isManager;
  final Map<String, dynamic> userData;
  const CapitalTasksScreen({super.key, this.isManager = false, required this.userData});
  @override
  State<CapitalTasksScreen> createState() => _CapitalTasksScreenState();
}

class _CapitalTasksScreenState extends State<CapitalTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  int _page = 1, _totalPages = 1, _totalCount = 0;
  static const int _pageSize = 20;
  String _search = '', _statusFilter = '', _priorityFilter = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String _buildEndpoint() {
    final p = <String, String>{'page': '$_page', 'page_size': '$_pageSize'};
    if (_search.isNotEmpty) p['search'] = _search;
    if (_statusFilter.isNotEmpty) p['status'] = _statusFilter;
    if (_priorityFilter.isNotEmpty) p['priority'] = _priorityFilter;
    return '/capital/tasks/?${p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
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
          _tasks = results;
          _totalCount = data?['count'] ?? 0;
          _totalPages = _totalCount == 0 ? 1 : (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _quickUpdateStatus(String id, String status) async {
    await ApiService.request(endpoint: '/capital/tasks/$id/', method: 'PATCH', body: {'status': status});
    _load();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Delete this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await ApiService.delete('/capital/tasks/$id/');
    _load();
  }

  void _openForm({Map<String, dynamic>? task}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _TaskFormSheet(
        task: task, userData: widget.userData,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  void _showDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onEdit: () { Navigator.pop(context); _openForm(task: task); },
        onDelete: () { Navigator.pop(context); _delete(task['id'].toString()); },
        onStatusChange: (s) { Navigator.pop(context); _quickUpdateStatus(task['id'].toString(), s); },
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String tmpStatus = _statusFilter, tmpPriority = _priorityFilter;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget section(String title, List<(String,String)> opts, String cur, void Function(String) onTap) {
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
                      color: active ? _taskPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? _taskPrimary : Colors.transparent),
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
              TextButton(onPressed: () => setLocal(() { tmpStatus = ''; tmpPriority = ''; }),
                  child: const Text('Clear All', style: TextStyle(color: _taskPrimary))),
            ]),
          ),
          section('Status', [('', 'All'), ..._taskStatuses], tmpStatus, (v) => tmpStatus = v),
          section('Priority', [('', 'All'), ..._taskPriorities], tmpPriority, (v) => tmpPriority = v),
          Padding(padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { _statusFilter = tmpStatus; _priorityFilter = tmpPriority; });
                  _load(resetPage: true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _taskPrimary, foregroundColor: Colors.white,
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
      final sheet = excel['Tasks'];
      final headers = ['Title*', 'Description', 'Status', 'Priority', 'Due Date (YYYY-MM-DD)'];
      final example = ['Follow up with client', 'Call and confirm documents', 'in_progress', 'medium', '2025-06-01'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = xl.TextCellValue(headers[i]);
      }
      for (int j = 0; j < example.length; j++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1)).value = xl.TextCellValue(example[j]);
      }
      for (final name in excel.sheets.keys.toList()) { if (name != 'Tasks') excel.delete(name); }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fp = '${dir!.path}/capital_tasks_template_$ts.xlsx';
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
      final tasks = <Map<String, dynamic>>[];
      for (final table in excel.tables.values) {
        for (int i = 1; i < table.rows.length; i++) {
          final row = table.rows[i];
          final title = row.length > 0 ? (row[0]?.value?.toString() ?? '') : '';
          if (title.isEmpty) continue;
          tasks.add({
            'title': title,
            if (row.length > 1 && row[1]?.value != null) 'description': row[1]!.value.toString(),
            'status': row.length > 2 ? (row[2]?.value?.toString() ?? 'in_progress') : 'in_progress',
            'priority': row.length > 3 ? (row[3]?.value?.toString() ?? 'medium') : 'medium',
            if (row.length > 4 && row[4]?.value != null) 'due_date': row[4]!.value.toString(),
          });
        }
        break;
      }
      if (tasks.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid rows found'))); return; }
      final res = await ApiService.post('/capital/tasks/bulk_import/', {'tasks': tasks});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? 'Imported ${tasks.length} tasks' : 'Import failed'),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) _load(resetPage: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportToExcel() async {
    try {
      String ep = '/capital/tasks/?page_size=2000';
      if (_statusFilter.isNotEmpty) ep += '&status=$_statusFilter';
      if (_priorityFilter.isNotEmpty) ep += '&priority=$_priorityFilter';
      if (_search.isNotEmpty) ep += '&search=${Uri.encodeComponent(_search)}';
      final res = await ApiService.get(ep);
      final all = (res['data']?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      final excel = xl.Excel.createExcel();
      final sheet = excel['Tasks'];
      final headers = ['Title', 'Description', 'Status', 'Priority', 'Linked Loan', 'Linked Service', 'Assigned To', 'Due Date', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = xl.TextCellValue(headers[i]);
      }
      for (int i = 0; i < all.length; i++) {
        final t = all[i];
        final row = [t['title'] ?? '', t['description'] ?? '', t['status'] ?? '', t['priority'] ?? '',
          t['loan_name'] ?? '', t['service_name'] ?? '', t['assigned_to_name'] ?? '',
          t['due_date'] ?? '', t['created_at'] ?? ''];
        for (int j = 0; j < row.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)).value = xl.TextCellValue(row[j].toString());
        }
      }
      for (final name in excel.sheets.keys.toList()) { if (name != 'Tasks') excel.delete(name); }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else { dir = await getApplicationDocumentsDirectory(); }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fp = '${dir!.path}/capital_tasks_$ts.xlsx';
      File(fp).writeAsBytesSync(excel.save()!);
      _showFileSnackbar('Exported ${all.length} tasks to Downloads', fp);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  int get _filterCount => (_statusFilter.isNotEmpty ? 1 : 0) + (_priorityFilter.isNotEmpty ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12121C) : Colors.grey[50]!;
    final card = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
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
                    hintText: 'Search tasks...',
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
                        borderSide: const BorderSide(color: _taskPrimary)),
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
                    foregroundColor: _filterCount > 0 ? _taskPrimary : (isDark ? Colors.white70 : Colors.grey[700]),
                    side: BorderSide(color: _filterCount > 0 ? _taskPrimary : (isDark ? Colors.white24 : Colors.grey.shade300)),
                    backgroundColor: _filterCount > 0 ? _taskPrimary.withOpacity(0.08) : null,
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
              ..._taskStatuses.map((s) {
                final cnt = _tasks.where((t) => t['status'] == s.$1).length;
                return _chip(s.$2, cnt, _taskStatusTextColors[s.$1] ?? Colors.grey, card, isDark);
              }),
            ],
          ),
        ),
        // ── List ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _taskPrimary))
              : _tasks.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No tasks found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => _openForm(), child: const Text('Add first task')),
                    ]))
                  : RefreshIndicator(
                      onRefresh: () => _load(resetPage: true),
                      color: _taskPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: _tasks.length,
                        itemBuilder: (_, i) => _TaskCard(
                          task: _tasks[i], isDark: isDark, cardColor: card,
                          onTap: () => _showDetail(_tasks[i]),
                          onEdit: () => _openForm(task: _tasks[i]),
                          onDelete: () => _delete(_tasks[i]['id'].toString()),
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
                Text('$_page / $_totalPages', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                IconButton(icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
              ]),
            ]),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _taskPrimary,
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


// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDark;
  final Color cardColor;
  final VoidCallback onTap, onEdit, onDelete;

  const _TaskCard({required this.task, required this.isDark, required this.cardColor,
      required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] ?? 'in_progress';
    final priority = task['priority'] ?? 'medium';
    final statusTxt   = _taskStatusTextColors[status]   ?? Colors.grey;
    final priorityTxt = _priorityTextColors[priority]   ?? Colors.grey;
    final title    = task['title'] ?? 'Untitled';
    final assigned = (task['assigned_to_name'] ?? '').toString();
    final due      = _fmtDue(task['due_date']);
    final loanName = (task['loan_name'] ?? '').toString();
    final svcName  = (task['service_name'] ?? '').toString();

    // Overdue check
    bool isOverdue = false;
    if (task['due_date'] != null && status != 'completed' && status != 'rejected') {
      try { isOverdue = DateTime.parse(task['due_date']).isBefore(DateTime.now()); } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(14),
        border: isOverdue ? Border.all(color: Colors.red.withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: priorityTxt.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.task_alt_rounded, color: priorityTxt, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
            color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (loanName.isNotEmpty)
            Text('Loan: $loanName', style: TextStyle(fontSize: 11, color: const Color(0xFF1565C0))),
          if (svcName.isNotEmpty)
            Text('Service: $svcName', style: TextStyle(fontSize: 11, color: const Color(0xFFE65100))),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: (_priorityColors[priority] ?? const Color(0xFFF5F5F5)).withOpacity(isDark ? 0.25 : 1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_fmtPriority(priority),
                  style: TextStyle(fontSize: 10, color: priorityTxt, fontWeight: FontWeight.w600)),
            ),
            if (due != '—') ...[
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 11, color: isOverdue ? Colors.red : Colors.grey[500]),
              const SizedBox(width: 3),
              Text(due, style: TextStyle(fontSize: 10,
                  color: isOverdue ? Colors.red : (isDark ? Colors.white38 : Colors.grey[500]),
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal)),
            ],
          ]),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusTxt.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_fmtTaskStatus(status),
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

// ── Task Detail Sheet ─────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDark;
  final VoidCallback onEdit, onDelete;
  final void Function(String) onStatusChange;

  const _TaskDetailSheet({required this.task, required this.isDark,
      required this.onEdit, required this.onDelete, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] ?? 'in_progress';
    final priority = task['priority'] ?? 'medium';
    final statusTxt   = _taskStatusTextColors[status]   ?? Colors.grey;
    final priorityTxt = _priorityTextColors[priority]   ?? Colors.grey;
    final bg  = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final div = isDark ? Colors.white12 : Colors.grey.shade200;
    final desc     = (task['description'] ?? '').toString();
    final assigned = (task['assigned_to_name'] ?? '').toString();
    final due      = _fmtDue(task['due_date']);
    final loanName = (task['loan_name'] ?? '').toString();
    final loanPhone= (task['loan_phone'] ?? '').toString();
    final svcName  = (task['service_name'] ?? '').toString();
    final svcType  = (task['service_type_display'] ?? '').toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: ctrl, padding: EdgeInsets.zero, children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              Container(width: 50, height: 50,
                  decoration: BoxDecoration(color: priorityTxt.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.task_alt_rounded, color: priorityTxt, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task['title'] ?? 'Untitled',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                Text('${_fmtPriority(priority)} Priority',
                    style: TextStyle(fontSize: 12, color: priorityTxt)),
              ])),
              IconButton(icon: const Icon(Icons.edit_rounded, color: _taskPrimary, size: 20), onPressed: onEdit),
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
                  color: (_taskStatusColors[status] ?? const Color(0xFFF5F5F5)).withOpacity(isDark ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusTxt.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Task Status', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
                  Row(children: [
                    Text(_fmtTaskStatus(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusTxt)),
                    Icon(Icons.arrow_drop_down, size: 18, color: statusTxt),
                  ]),
                ]),
              ),
            ),
          ),
          Divider(color: div, height: 24),
          if (desc.isNotEmpty) _tile(Icons.notes_rounded, 'Description', desc, isDark),
          if (loanName.isNotEmpty) _tile(Icons.account_balance_rounded, 'Linked Loan',
              '$loanName${loanPhone.isNotEmpty ? ' · $loanPhone' : ''}', isDark, valueColor: const Color(0xFF1565C0)),
          if (svcName.isNotEmpty) _tile(Icons.miscellaneous_services, 'Linked Service',
              '$svcName${svcType.isNotEmpty ? ' · $svcType' : ''}', isDark, valueColor: const Color(0xFFE65100)),
          if (assigned.isNotEmpty) _tile(Icons.person_outline_rounded, 'Assigned To', assigned, isDark),
          if (due != '—') _tile(Icons.schedule_rounded, 'Due Date', due, isDark),
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
        ..._taskStatuses.map((s) {
          final txt = _taskStatusTextColors[s.$1] ?? Colors.grey;
          return ListTile(
            dense: true,
            leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: txt, shape: BoxShape.circle)),
            title: Text(s.$2, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            trailing: task['status'] == s.$1 ? const Icon(Icons.check, color: _taskPrimary, size: 16) : null,
            onTap: () { Navigator.pop(context); onStatusChange(s.$1); },
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Task Form Sheet ───────────────────────────────────────────────────────────

class _TaskFormSheet extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Map<String, dynamic> userData;
  final VoidCallback onSaved;
  const _TaskFormSheet({this.task, required this.userData, required this.onSaved});
  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?['title'] ?? '');
  late final _desc  = TextEditingController(text: widget.task?['description'] ?? '');
  late final _due   = TextEditingController(text: widget.task?['due_date']?.toString().substring(0, 10) ?? '');

  String _status   = 'in_progress';
  String _priority = 'medium';
  String _linkType = 'none'; // none, loan, service
  bool   _saving   = false;

  List<Map<String, dynamic>> _loans    = [];
  List<Map<String, dynamic>> _services = [];
  String _selectedLoan    = '';
  String _selectedService = '';

  @override
  void initState() {
    super.initState();
    _status   = widget.task?['status']   ?? 'in_progress';
    _priority = widget.task?['priority'] ?? 'medium';
    if (widget.task?['loan'] != null) { _linkType = 'loan'; _selectedLoan = widget.task!['loan'].toString(); }
    else if (widget.task?['service'] != null) { _linkType = 'service'; _selectedService = widget.task!['service'].toString(); }
    _loadLinked();
  }

  Future<void> _loadLinked() async {
    try {
      final results = await Future.wait([
        ApiService.get('/capital/loans/?page_size=200'),
        ApiService.get('/capital/services/?page_size=200'),
      ]);
      if (mounted) setState(() {
        _loans    = (results[0]['data']?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        _services = (results[1]['data']?['results'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() { _title.dispose(); _desc.dispose(); _due.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = widget.userData['id'];
      final assignedTo = uid is int ? uid : int.tryParse(uid.toString());
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'status': _status,
        'priority': _priority,
        if (_due.text.trim().isNotEmpty) 'due_date': _due.text.trim(),
        if (_linkType == 'loan' && _selectedLoan.isNotEmpty) 'loan': int.tryParse(_selectedLoan),
        if (_linkType == 'service' && _selectedService.isNotEmpty) 'service': int.tryParse(_selectedService),
        if (widget.task == null && assignedTo != null) 'assigned_to': assignedTo,
      };
      final res = widget.task != null
          ? await ApiService.request(endpoint: '/capital/tasks/${widget.task!['id']}/', method: 'PATCH', body: body)
          : await ApiService.post('/capital/tasks/', body);
      if (res['success'] == true) {
        widget.onSaved();
      } else {
        if (mounted) {
          final data = res['data'];
          String msg = 'Failed';
          if (data is Map && data.isNotEmpty) {
            final k = data.keys.first;
            final v = data[k];
            msg = '$k: ${v is List ? v.first : v}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
          borderSide: const BorderSide(color: _taskPrimary)),
    );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.task != null ? 'Edit Task' : 'New Task',
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
              TextFormField(controller: _title, style: ts, decoration: dec('Title *'),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, style: ts, maxLines: 2, decoration: dec('Description')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _status, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Status'),
                  items: _taskStatuses.map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _priority, style: ts,
                  dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                  decoration: dec('Priority'),
                  items: _taskPriorities.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                )),
              ]),
              const SizedBox(height: 12),
              // Link type pills
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Link To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 8),
                Row(children: [
                  for (final lt in [('none','None'), ('loan','Loan'), ('service','Service')]) ...[
                    GestureDetector(
                      onTap: () => setState(() { _linkType = lt.$1; _selectedLoan = ''; _selectedService = ''; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _linkType == lt.$1 ? _taskPrimary : (isDark ? Colors.white10 : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _linkType == lt.$1 ? _taskPrimary : Colors.transparent),
                        ),
                        child: Text(lt.$2, style: TextStyle(fontSize: 12,
                            color: _linkType == lt.$1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _linkType == lt.$1 ? FontWeight.w600 : FontWeight.normal)),
                      ),
                    ),
                  ],
                ]),
                if (_linkType == 'loan' && _loans.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLoan.isEmpty ? null : _selectedLoan,
                    style: ts, dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                    decoration: dec('Select Loan'),
                    items: [
                      DropdownMenuItem(value: '', child: Text('Select...', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]))),
                      ..._loans.map((l) => DropdownMenuItem(
                          value: l['id'].toString(),
                          child: Text('${l['applicant_name'] ?? ''} · ${l['phone'] ?? ''}',
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _selectedLoan = v ?? ''),
                  ),
                ],
                if (_linkType == 'service' && _services.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedService.isEmpty ? null : _selectedService,
                    style: ts, dropdownColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                    decoration: dec('Select Service'),
                    items: [
                      DropdownMenuItem(value: '', child: Text('Select...', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]))),
                      ..._services.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text('${s['client_name'] ?? ''} · ${s['service_type_display'] ?? s['service_type'] ?? ''}',
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _selectedService = v ?? ''),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _due, style: ts,
                decoration: dec('Due Date', hint: 'YYYY-MM-DD'),
                keyboardType: TextInputType.datetime,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _due.text = DateFormat('yyyy-MM-dd').format(picked));
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _taskPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.task != null ? 'Update Task' : 'Create Task',
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
