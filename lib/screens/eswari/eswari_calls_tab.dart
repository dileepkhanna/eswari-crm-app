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
// ─────────────────────────────────────────────────────────────────────────────
// EswariCallsTab
// ─────────────────────────────────────────────────────────────────────────────
class EswariCallsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  final VoidCallback? onLeadConverted;
  
  const EswariCallsTab({
    super.key,
    required this.userData,
    required this.isManager,
    this.onLeadConverted,
  });

  @override
  State<EswariCallsTab> createState() => _EswariCallsTabState();
}

class _EswariCallsTabState extends State<EswariCallsTab>
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
  String _conversionFilter = 'all'; // all, converted, not_converted
  
  // Sorting
  String _sortField = 'created_at'; // created_at, name, call_status
  String _sortDirection = 'desc'; // asc, desc
  
  // Status counts for filter badges
  Map<String, int> _statusCounts = {};
  
  // Statistics
  int _totalCalls = 0;
  int _convertedCount = 0;
  int _answeredCount = 0;
  int _pendingCount = 0;
  double _conversionRate = 0.0;
  
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
   
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchCalls();
    _fetchAssignees();
  }
  
  // Helper function to mask phone number for managers
  String _maskPhone(String phone) {
    if (!widget.isManager) return phone;
    if (phone.length <= 4) return '****';
    return '${phone.substring(0, 2)}${'*' * (phone.length - 4)}${phone.substring(phone.length - 2)}';
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

  Future<void> fetchCalls() async {
    setState(() => _loading = true);
    try {
      String url = '/customers/?page_size=500';  // Increased to show more calls
      
      // Apply filters
      if (_statusFilter != 'all') url += '&call_status=$_statusFilter';
      if (_search.isNotEmpty) url += '&search=$_search';
      if (_assigneeFilter != 'all') url += '&assigned_to=$_assigneeFilter';
      if (_dateFilter != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_dateFilter!);
        url += '&scheduled_date=$dateStr';
      }
      if (_conversionFilter == 'converted') {
        url += '&converted=true';
      } else if (_conversionFilter == 'not_converted') {
        url += '&converted=false';
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
        
        // Apply sorting
        list.sort((a, b) {
          int comparison = 0;
          
          switch (_sortField) {
            case 'name':
              final nameA = (a['name'] ?? '').toString().toLowerCase();
              final nameB = (b['name'] ?? '').toString().toLowerCase();
              comparison = nameA.compareTo(nameB);
              break;
            case 'call_status':
              final statusA = (a['call_status'] ?? '').toString();
              final statusB = (b['call_status'] ?? '').toString();
              comparison = statusA.compareTo(statusB);
              break;
            case 'created_at':
            default:
              try {
                final dateA = DateTime.parse(a['created_at'] ?? '');
                final dateB = DateTime.parse(b['created_at'] ?? '');
                comparison = dateA.compareTo(dateB);
              } catch (_) {
                comparison = 0;
              }
              break;
          }
          
          return _sortDirection == 'asc' ? comparison : -comparison;
        });
        
        // Build status counts
        final counts = <String, int>{'all': list.length};
        for (final c in list) {
          final s = (c['call_status'] ?? 'pending') as String;
          counts[s] = (counts[s] ?? 0) + 1;
        }
        
        // Calculate statistics
        final total = list.length;
        final converted = list.where((c) => c['is_converted'] == true).length;
        final answered = list.where((c) => c['call_status'] == 'answered').length;
        final pending = list.where((c) => c['call_status'] == 'pending').length;
        final convRate = total > 0 ? (converted / total * 100) : 0.0;
        
        setState(() {
          _calls = list;
          _statusCounts = counts;
          _totalCalls = total;
          _convertedCount = converted;
          _answeredCount = answered;
          _pendingCount = pending;
          _conversionRate = convRate;
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
      _conversionFilter = 'all';
      _sortField = 'created_at';
      _sortDirection = 'desc';
      _search = '';
      _searchCtrl.clear();
    });
    fetchCalls();
  }
  
  bool get _hasActiveFilters {
    return _statusFilter != 'all' ||
        _callTypeFilter != 'all' ||
        _dateFilter != null ||
        _assigneeFilter != 'all' ||
        _conversionFilter != 'all' ||
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
      
      // Process the Template sheet
      for (final tableName in excel.tables.keys) {
        final table = excel.tables[tableName];
        if (table == null) continue;
        
        print('Processing sheet: $tableName with ${table.rows.length} rows');
        
        // Skip header row (index 0) and start from row 1
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
          
          // Extract phone (required field)
          final phoneCell = row.length > 0 ? row[0] : null;
          var phone = phoneCell?.value?.toString().trim() ?? '';
          
          // Remove .0 from phone numbers (Excel treats numbers as floats)
          if (phone.endsWith('.0')) {
            phone = phone.substring(0, phone.length - 2);
          }
          
          print('Row $i: Phone = "$phone"');
          
          // Skip if phone is empty or is the example placeholder
          if (phone.isEmpty || phone == '+1234567890') continue;
          
          // Extract optional fields
          final nameCell = row.length > 1 ? row[1] : null;
          final name = nameCell?.value?.toString().trim() ?? '';
          
          final notesCell = row.length > 2 ? row[2] : null;
          final notes = notesCell?.value?.toString().trim() ?? '';
          
          // Build customer object with assigned_to field
          // Auto-assign to current user if they are employee or manager
          int? assignedTo;
          final userRole = widget.userData['role'];
          if (userRole == 'employee' || userRole == 'manager') {
            assignedTo = widget.userData['id'];
          }
          
          final customer = <String, dynamic>{
            'phone': phone,
            'call_status': 'pending',  // Default status
            'assigned_to': assignedTo,  // Auto-assign based on role
          };
          
          if (name.isNotEmpty) customer['name'] = name;
          if (notes.isNotEmpty) customer['notes'] = notes;
          
          customers.add(customer);
          print('Added customer: $customer');
        }
        
        // Only process first data sheet
        break;
      }

      print('Total customers to import: ${customers.length}');
      
      // Debug: Print what we're sending
      print('Sending to API: ${customers.take(3).toList()}');

      if (customers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid rows found. Please ensure:\n• Phone column has values\n• You are using the Template sheet\n• Remove or modify the example row'),
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
                Text('Importing ${customers.length} customers...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final res = await ApiService.post(
          '/customers/bulk_import/', {'customers': customers});
      
      // Debug: Print the full response
      print('API Response: $res');
      
      if (mounted) {
        // Clear loading indicator
        ScaffoldMessenger.of(context).clearSnackBars();
        
        final ok = res['success'] == true;
        // Backend returns 'created' not 'imported'
        final imported = res['data']?['created'] ?? res['data']?['imported'] ?? 0;
        final errors = res['data']?['errors'] as List? ?? [];
        
        String msg;
        if (ok) {
          if (errors.isEmpty) {
            msg = '✅ Successfully imported $imported customers!';
          } else {
            // Show detailed error information
            final errorDetails = errors.take(3).map((e) {
              if (e is Map) {
                final phone = e['phone'] ?? 'Unknown';
                final reason = e['error'] ?? 'Unknown error';
                return '• $phone: $reason';
              }
              return '• $e';
            }).join('\n');
            
            msg = '✅ Imported $imported customers\n⚠️ ${errors.length} skipped:\n$errorDetails';
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
        
        if (ok && imported > 0) fetchCalls();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import error: $e\n\nPlease check:\n• File format is correct\n• Phone column has values\n• Remove the example row before importing'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
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
      
      // Create Template sheet
      final sheet = excel['Template'];

      // Header row
      final headers = [
        'Phone*', 'Name', 'Notes'
      ];
      
      // Add headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
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
      final fileName = 'eswari_calls_template_$timestamp.xlsx';
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
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareTemplate() async {
    try {
      final excel = xl.Excel.createExcel();
      
      // Create Template sheet
      final sheet = excel['Template'];

      // Header row
      final headers = [
        'Phone*', 'Name', 'Notes'
      ];
      
      // Add headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }
      
      // Delete default Sheet1 AFTER creating our sheet
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Save to temporary directory for sharing
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_calls_template_$timestamp.xlsx';
      final filePath = '${dir.path}/$fileName';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Calls Import Template',
        text: 'Use this template to import calls into Eswari CRM',
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
              subtitle: Text('Save ${_calls.length} calls to device'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Color(0xFF2E7D32)),
              title: const Text('Share'),
              subtitle: Text('Share ${_calls.length} calls file'),
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
      final excel = xl.Excel.createExcel();
      final sheet = excel['Calls'];

      // Header row
      final headers = [
        'Phone', 'Name', 'Status', 'Custom Status',
        'Assigned To', 'Scheduled Date',
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
        
        final row = [
          c['phone'] ?? '',
          c['name'] ?? '',
          _statusLabels[c['call_status']] ?? (c['call_status'] ?? ''),
          c['custom_call_status'] ?? '',
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
      final fileName = 'eswari_calls_export_$timestamp.xlsx';
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
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Exported ${_calls.length} calls successfully!', 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
              content: Text('Export error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareExport() async {
    try {
      final excel = xl.Excel.createExcel();
      
      final sheet = excel['Calls'];
      
      // Headers
      final headers = ['Phone', 'Name', 'Notes', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
      }
      
      // Data rows
      for (int i = 0; i < _calls.length; i++) {
        final call = _calls[i];
        final rowData = [
          call['phone'] ?? '',
          call['name'] ?? '',
          call['notes'] ?? '',
          call['created_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(call['created_at']))
            : '',
        ];
        
        for (int j = 0; j < rowData.length; j++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = xl.TextCellValue(rowData[j]);
        }
      }
      
      // Save to temporary directory for sharing
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'eswari_calls_export_$timestamp.xlsx';
      final filePath = '${dir.path}/$fileName';
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to encode Excel file');
      File(filePath).writeAsBytesSync(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Eswari Calls Export',
        text: 'Exported ${_calls.length} calls from Eswari CRM',
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
        // Floating Add Call Button (hidden for managers)
        if (!widget.isManager)
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
                          fetchCalls();
                        })
                    : null,
                filled: true,
                fillColor: isDark ? theme.colorScheme.background : const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                if (v.isEmpty) fetchCalls();
              },
              onSubmitted: (_) => fetchCalls(),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button with badge
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? _primary : (isDark ? theme.colorScheme.background : const Color(0xFFF5F6FA)),
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
                        onRefresh: fetchCalls,
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
    if (_conversionFilter == 'converted') filters.add('Converted');
    if (_conversionFilter == 'not_converted') filters.add('Not Converted');
    if (_sortField != 'created_at' || _sortDirection != 'desc') {
      final sortLabel = _sortField == 'name' ? 'Name' : _sortField == 'call_status' ? 'Status' : 'Date';
      filters.add('Sort: $sortLabel ${_sortDirection == 'asc' ? '↑' : '↓'}');
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
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              icon: Icons.phone_rounded,
              label: 'Total',
              value: _totalCalls.toString(),
              color: _primary,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.check_circle_rounded,
              label: 'Answered',
              value: _answeredCount.toString(),
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.pending_rounded,
              label: 'Pending',
              value: _pendingCount.toString(),
              color: const Color(0xFFE65100),
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.trending_up_rounded,
              label: 'Converted',
              value: _convertedCount.toString(),
              color: const Color(0xFF1976D2),
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.percent_rounded,
              label: 'Conv. Rate',
              value: '${_conversionRate.toStringAsFixed(1)}%',
              color: const Color(0xFF6A1B9A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final theme = Theme.of(context);
    
    // Hide import/export buttons for managers
    if (widget.isManager) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: theme.colorScheme.surface,
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
        conversionFilter: _conversionFilter,
        sortField: _sortField,
        sortDirection: _sortDirection,
        assignees: _assignees,
        onApply: (status, callType, date, assignee, conversion, sortField, sortDir) {
          setState(() {
            _statusFilter = status;
            _callTypeFilter = callType;
            _dateFilter = date;
            _assigneeFilter = assignee;
            _conversionFilter = conversion;
            _sortField = sortField;
            _sortDirection = sortDir;
          });
          fetchCalls();
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
    final displayPhone = _maskPhone(phone); // Mask phone for managers

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
                fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone.isNotEmpty)
              Text(displayPhone,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
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
                  style: const TextStyle(
                      fontSize: 9, color: Colors.grey)),
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
        onRefresh: fetchCalls,
        onLeadConverted: widget.onLeadConverted,
        onEdit: () {
          Navigator.pop(context); // Close detail sheet
          _showEditCallForm(call); // Open edit form
        },
        onDelete: () async {
          Navigator.pop(context); // Close detail sheet
          await _deleteCall(call);
        },
        isManager: widget.isManager,
        maskPhone: _maskPhone,
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
        onSaved: fetchCalls,
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
        endpoint: '/customers/$id/',
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
          fetchCalls();
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
        onSaved: fetchCalls,
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
              size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
  late final TextEditingController _notesCtrl;
  late final TextEditingController _customStatusCtrl;

  String _callStatus = 'pending';
  DateTime? _scheduledDate;
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

  @override
  void initState() {
    super.initState();
    final c = widget.call;
    _nameCtrl = TextEditingController(text: c?['name'] ?? '');
    _phoneCtrl = TextEditingController(text: c?['phone'] ?? '');
    _notesCtrl = TextEditingController(text: c?['notes'] ?? '');
    _customStatusCtrl = TextEditingController(text: c?['custom_call_status'] ?? '');
    _callStatus = c?['call_status'] ?? 'pending';
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
    _notesCtrl.dispose();
    _customStatusCtrl.dispose();
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
      if (_notesCtrl.text.trim().isNotEmpty) {
        body['notes'] = _notesCtrl.text.trim();
      }
      
      // Call status
      body['call_status'] = _callStatus;
      if (_callStatus == 'custom' && _customStatusCtrl.text.trim().isNotEmpty) {
        body['custom_call_status'] = _customStatusCtrl.text.trim();
      }
      
      // Scheduled date
      if (_scheduledDate != null) {
        body['scheduled_date'] = DateFormat('yyyy-MM-dd').format(_scheduledDate!);
      }

      final Map<String, dynamic> res;
      if (widget.call == null) {
        res = await ApiService.post('/customers/', body);
      } else {
        final id = widget.call!['id'];
        res = await ApiService.request(
            endpoint: '/customers/$id/',
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
          String errorMsg = 'Unknown error';
          if (res['data'] != null) {
            if (res['data'] is Map) {
              final errors = res['data'] as Map;
              if (errors['detail'] != null) {
                errorMsg = errors['detail'].toString();
              } else {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.call != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? 'Edit Call' : 'Add New Call',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                isEdit 
                  ? 'Update call information and status after making the call'
                  : 'Add call with phone number and name. You can update call status after making the call.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Phone (REQUIRED)
              _field(_phoneCtrl, 'Phone Number *', Icons.phone_rounded,
                  keyboardType: TextInputType.phone, required: true, theme: theme),
              const SizedBox(height: 12),

              // Name (optional)
              _field(_nameCtrl, 'Name (Optional)', Icons.person_rounded, theme: theme),
              const SizedBox(height: 12),

              // Call Status dropdown
              _buildCallStatusDropdown(theme),
              const SizedBox(height: 12),

              // Custom call status (conditional)
              if (_callStatus == 'custom') ...[
                _field(_customStatusCtrl, 'Enter custom call status',
                    Icons.label_rounded, theme: theme),
                Text(
                  'Examples: "Callback Requested", "Wrong Number", "Interested but Busy"',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],

              // Scheduled Date
              _buildDateField(theme),
              const SizedBox(height: 12),

              // Notes
              _field(_notesCtrl, 'Notes (Optional)', Icons.notes_rounded,
                  maxLines: 3, theme: theme),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Update Call' : 'Add Call',
                              style: const TextStyle(fontSize: 15)),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
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

  Widget _buildCallStatusDropdown(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: _callStatus,
      style: TextStyle(color: theme.colorScheme.onSurface),
      dropdownColor: theme.colorScheme.surface,
      decoration: InputDecoration(
        labelText: 'Call Status',
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        prefixIcon:
            const Icon(Icons.flag_rounded, color: _primary, size: 20),
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
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

  Widget _buildDateField(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Scheduled Date',
            labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            prefixIcon: const Icon(Icons.calendar_today_rounded,
                color: _primary, size: 20),
            hintText: _scheduledDate == null
                ? 'Select date'
                : DateFormat('dd MMM yyyy').format(_scheduledDate!),
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            filled: false,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade300, width: 1.5)),
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
  final bool isManager;
  final String Function(String) maskPhone;
  
  const _CallDetailSheet({
    required this.call,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    this.onLeadConverted,
    required this.isManager,
    required this.maskPhone,
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
      final res = await ApiService.get('/customers/$id/notes_history/');
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
      final res = await ApiService.get('/customers/$id/call_logs/');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final call = widget.call;
    final status = call['call_status'] ?? 'pending';
    final color = _statusColors[status] ?? _primary;
    final name = call['name'] ?? 'Unknown';
    final phone = call['phone'] ?? '';
    final displayPhone = widget.maskPhone(phone); // Mask phone for managers

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
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
                                    color: theme.colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      // Action buttons (hidden for managers)
                      if (!widget.isManager) ...[
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick Status Change (hidden for managers)
                  if (!widget.isManager) _buildQuickStatusChange(call, theme, isDark),
                  if (!widget.isManager) const SizedBox(height: 12),
                  // Quick Action Buttons (Call & WhatsApp) - disabled for managers
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.isManager ? null : () => _makePhoneCall(phone),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isManager ? Colors.grey : Colors.green,
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
                          onPressed: widget.isManager ? null : () => _openWhatsApp(phone),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isManager ? Colors.grey : const Color(0xFF25D366),
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
                    _infoRow(Icons.phone_rounded, displayPhone, theme),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabCtrl,
              labelColor: _primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
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
                  _buildDetailsTab(call, theme, isDark),
                  _buildNotesTab(theme, isDark),
                  _buildCallLogTab(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusChange(Map<String, dynamic> call, ThemeData theme, bool isDark) {
    final currentStatus = call['call_status'] ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface.withOpacity(0.5) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : Colors.grey.shade200),
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
                  borderSide: BorderSide(color: Colors.grey.shade300),
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
        endpoint: '/customers/$callId/',
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
    final nameCtrl = TextEditingController(text: call['name'] ?? '');
    final phoneCtrl = TextEditingController(text: call['phone'] ?? '');
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final budgetMinCtrl = TextEditingController();
    final budgetMaxCtrl = TextEditingController();
    final preferredLocationCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: call['notes'] ?? '');
    
    String selectedRequirementType = 'apartment';
    String selectedBhk = '2';
    String selectedStatus = 'new';
    String selectedLeadSource = 'customer_conversion';
    List<String> selectedProjects = [];
    DateTime? followUpDate;

    // Fetch projects for assignment
    List<Map<String, dynamic>> projects = [];
    
    Future<void> fetchProjects() async {
      try {
        final res = await ApiService.get('/projects/');
        if (res['success'] == true) {
          final data = res['data'];
          if (data is List) {
            projects = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['results'] is List) {
            projects = List<Map<String, dynamic>>.from(data['results']);
          }
        }
      } catch (e) {
        // Silently fail, projects will be empty
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: fetchProjects(),
        builder: (context, snapshot) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Convert Call to Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fill in the lead details to convert ${call['name'] ?? call['phone']} to a lead.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    
                    // Basic Information
                    const Text('Basic Information', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLeadSource,
                      decoration: InputDecoration(
                        labelText: 'Lead Source',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'customer_conversion', child: Text('Customer Conversion')),
                        DropdownMenuItem(value: 'website', child: Text('Website')),
                        DropdownMenuItem(value: 'referral', child: Text('Referral')),
                        DropdownMenuItem(value: 'walk_in', child: Text('Walk-in')),
                      ],
                      onChanged: (v) => setState(() => selectedLeadSource = v ?? 'customer_conversion'),
                    ),
                    
                    // Assigned Projects
                    const SizedBox(height: 20),
                    const Text('Assigned Projects (Optional)', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                    const SizedBox(height: 8),
                    Text(
                      'Select one or more projects to assign to this lead (optional)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    if (projects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'No projects available',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            final projectId = project['id'].toString();
                            final isSelected = selectedProjects.contains(projectId);
                            return CheckboxListTile(
                              title: Text(project['name'] ?? '', style: const TextStyle(fontSize: 14)),
                              subtitle: Text(project['location'] ?? '', style: const TextStyle(fontSize: 12)),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedProjects.add(projectId);
                                  } else {
                                    selectedProjects.remove(projectId);
                                  }
                                });
                              },
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                    
                    // Address
                    const SizedBox(height: 20),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 2,
                    ),
                    
                    // Property Requirements
                    const SizedBox(height: 20),
                    const Text('Property Requirements', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRequirementType,
                      decoration: InputDecoration(
                        labelText: 'Requirement Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'apartment', child: Text('Apartment')),
                        DropdownMenuItem(value: 'villa', child: Text('Villa')),
                        DropdownMenuItem(value: 'house', child: Text('House')),
                        DropdownMenuItem(value: 'plot', child: Text('Plot')),
                      ],
                      onChanged: (v) => setState(() => selectedRequirementType = v ?? 'apartment'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedBhk,
                      decoration: InputDecoration(
                        labelText: 'BHK Requirement',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: '1', child: Text('1 BHK')),
                        DropdownMenuItem(value: '2', child: Text('2 BHK')),
                        DropdownMenuItem(value: '3', child: Text('3 BHK')),
                        DropdownMenuItem(value: '4', child: Text('4 BHK')),
                        DropdownMenuItem(value: '5+', child: Text('5+ BHK')),
                      ],
                      onChanged: (v) => setState(() => selectedBhk = v ?? '2'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(value: 'hot', child: Text('Hot')),
                        DropdownMenuItem(value: 'warm', child: Text('Warm')),
                        DropdownMenuItem(value: 'cold', child: Text('Cold')),
                      ],
                      onChanged: (v) => setState(() => selectedStatus = v ?? 'new'),
                    ),
                    
                    // Budget Range
                    const SizedBox(height: 20),
                    const Text('Budget Range', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetMinCtrl,
                      decoration: InputDecoration(
                        labelText: 'Minimum Budget (\$)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetMaxCtrl,
                      decoration: InputDecoration(
                        labelText: 'Maximum Budget (\$)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: preferredLocationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Preferred Location',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    
                    // Follow-up Date
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: followUpDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => followUpDate = picked);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Follow-up Date',
                            hintText: followUpDate == null
                                ? 'Pick a date'
                                : DateFormat('MMM dd, yyyy').format(followUpDate!),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            suffixIcon: const Icon(Icons.calendar_today_rounded),
                          ),
                        ),
                      ),
                    ),
                    
                    // Notes
                    const SizedBox(height: 20),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description / Notes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
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
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Full name is required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (phoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Phone number is required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _convertToLead(call, {
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'requirement_type': selectedRequirementType,
                    'bhk_requirement': selectedBhk,
                    'budget_min': budgetMinCtrl.text.trim().isNotEmpty ? double.tryParse(budgetMinCtrl.text.trim()) ?? 0 : 0,
                    'budget_max': budgetMaxCtrl.text.trim().isNotEmpty ? double.tryParse(budgetMaxCtrl.text.trim()) ?? 0 : 0,
                    'preferred_location': preferredLocationCtrl.text.trim(),
                    'status': selectedStatus,
                    'source': selectedLeadSource,
                    'assigned_projects': selectedProjects.map((id) => int.parse(id)).toList(),
                    'follow_up_date': followUpDate?.toIso8601String(),
                    'description': notesCtrl.text.trim(),
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
      ),
    );
  }

  Future<void> _convertToLead(Map<String, dynamic> call, Map<String, dynamic> leadData) async {
    try {
      // Prepare lead data matching the backend's convert_to_lead endpoint
      final body = {
        'name': leadData['name'],
        'phone': leadData['phone'],
        'email': leadData['email'],
        'address': leadData['address'],
        'requirement_type': leadData['requirement_type'],
        'bhk_requirement': leadData['bhk_requirement'],
        'budget_min': leadData['budget_min'],
        'budget_max': leadData['budget_max'],
        'preferred_location': leadData['preferred_location'],
        'status': leadData['status'],
        'source': leadData['source'],
        'assigned_projects': leadData['assigned_projects'],
        'follow_up_date': leadData['follow_up_date'],
        'description': leadData['description'],
      };
      
      // Remove empty strings and null values to avoid validation errors
      body.removeWhere((key, value) => 
        (value is String && value.trim().isEmpty) || 
        value == null ||
        (value is List && value.isEmpty));
      
      // Use the customer's convert_to_lead endpoint
      final res = await ApiService.post('/customers/${call['id']}/convert-to-lead/', body);
      
      if (mounted) {
        if (res['success'] == true) {
          // Refresh calls list via callback
          widget.onRefresh();
          
          // Notify parent to refresh leads tab
          widget.onLeadConverted?.call();
          
          // Close detail sheet
          Navigator.pop(context);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Successfully converted to lead! Lead ID: ${res['data']?['lead']?['id']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          String errorMsg = 'Failed to convert';
          if (res['data'] != null) {
            if (res['data']['message'] != null) {
              errorMsg = res['data']['message'].toString();
            } else if (res['data']['error'] != null) {
              errorMsg = res['data']['error'].toString();
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

  Widget _infoRow(IconData icon, String text, ThemeData theme) {
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

  Widget _buildDetailsTab(Map<String, dynamic> call, ThemeData theme, bool isDark) {
    final scheduledDate = call['scheduled_date'];
    final notes = call['notes'] ?? '';
    final customStatus = call['custom_call_status'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (call['assigned_to_name'] != null)
            _detailRow('Assigned To', call['assigned_to_name'].toString(), theme),
          if (scheduledDate != null)
            _detailRow('Scheduled', scheduledDate.toString(), theme),
          if (customStatus.isNotEmpty)
            _detailRow('Custom Status', customStatus, theme),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Notes',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface)),
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

  Widget _detailRow(String label, String value, ThemeData theme) {
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
                      fontWeight: FontWeight.w500, fontSize: 13, color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }

  // ── Notes Tab ──────────────────────────────────────────────────────────────
  Widget _buildNotesTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: _loadingNotes
              ? const Center(
                  child: CircularProgressIndicator(color: _primary))
              : _notes.isEmpty
                  ? Center(child: Text('No notes yet', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
        _buildAddNoteBar(theme, isDark),
      ],
    );
  }

  Widget _buildAddNoteBar(ThemeData theme, bool isDark) {
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
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Add a note...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: isDark ? theme.colorScheme.surface.withOpacity(0.5) : const Color(0xFFF5F6FA),
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
          '/customers/$id/notes_history/', {'content': text});
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
  Widget _buildCallLogTab(ThemeData theme, bool isDark) {
    return _loadingLogs
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : _logs.isEmpty
            ? Center(child: Text('No call logs yet', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
  final String conversionFilter;
  final String sortField;
  final String sortDirection;
  final List<Map<String, dynamic>> assignees;
  final Function(String, String, DateTime?, String, String, String, String) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.statusFilter,
    required this.callTypeFilter,
    required this.dateFilter,
    required this.assigneeFilter,
    required this.conversionFilter,
    required this.sortField,
    required this.sortDirection,
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
  late String _conversion;
  late String _sortField;
  late String _sortDirection;

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

  @override
  void initState() {
    super.initState();
    _status = widget.statusFilter;
    _callType = widget.callTypeFilter;
    _date = widget.dateFilter;
    _assignee = widget.assigneeFilter;
    _conversion = widget.conversionFilter;
    _sortField = widget.sortField;
    _sortDirection = widget.sortDirection;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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

                  // Conversion Status
                  _buildSectionTitle('Conversion Status', Icons.trending_up_rounded),
                  const SizedBox(height: 8),
                  _buildConversionChips(),
                  const SizedBox(height: 20),

                  // Sorting
                  _buildSectionTitle('Sort By', Icons.sort_rounded),
                  const SizedBox(height: 8),
                  _buildSortingOptions(),
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
                      widget.onApply(_status, _callType, _date, _assignee, _conversion, _sortField, _sortDirection);
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

  Widget _buildCallTypeChips() {
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
              color: isSelected ? chipColor : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? chipColor : Colors.grey.shade300,
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
                    color: isSelected ? Colors.white : Colors.grey[700],
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

  Widget _buildDatePicker() {
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
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
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
                  color: _date == null ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            if (_date != null)
              GestureDetector(
                onTap: () => setState(() => _date = null),
                child: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeDropdown() {
    final assigneeOptions = [
      {'id': 'all', 'username': 'All Assignees'},
      ...widget.assignees,
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

  Widget _buildConversionChips() {
    const conversionOptions = [
      ('all', 'All Calls'),
      ('converted', 'Converted'),
      ('not_converted', 'Not Converted'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: conversionOptions.map((opt) {
        final isSelected = _conversion == opt.$1;
        Color chipColor;
        switch (opt.$1) {
          case 'converted':
            chipColor = const Color(0xFF1976D2);
            break;
          case 'not_converted':
            chipColor = const Color(0xFF757575);
            break;
          default:
            chipColor = _primary;
        }

        return GestureDetector(
          onTap: () => setState(() => _conversion = opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? chipColor : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? chipColor : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (opt.$1 == 'converted')
                  Icon(Icons.check_circle_rounded, size: 16, color: isSelected ? Colors.white : chipColor)
                else if (opt.$1 == 'not_converted')
                  Icon(Icons.cancel_rounded, size: 16, color: isSelected ? Colors.white : chipColor),
                if (opt.$1 != 'all') const SizedBox(width: 6),
                Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.grey[700],
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

  Widget _buildSortingOptions() {
    const sortFieldOptions = [
      ('created_at', 'Date Created'),
      ('name', 'Name'),
      ('call_status', 'Status'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sort Field
        const Text(
          'Sort Field',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortFieldOptions.map((opt) {
            final isSelected = _sortField == opt.$1;
            return GestureDetector(
              onTap: () => setState(() => _sortField = opt.$1),
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
        ),
        const SizedBox(height: 16),
        // Sort Direction
        const Text(
          'Sort Direction',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _sortDirection = 'asc'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _sortDirection == 'asc' ? _primary : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sortDirection == 'asc' ? _primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: _sortDirection == 'asc' ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ascending',
                        style: TextStyle(
                          fontSize: 13,
                          color: _sortDirection == 'asc' ? Colors.white : Colors.grey[700],
                          fontWeight: _sortDirection == 'asc' ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _sortDirection = 'desc'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _sortDirection == 'desc' ? _primary : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sortDirection == 'desc' ? _primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                        color: _sortDirection == 'desc' ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Descending',
                        style: TextStyle(
                          fontSize: 13,
                          color: _sortDirection == 'desc' ? Colors.white : Colors.grey[700],
                          fontWeight: _sortDirection == 'desc' ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}



