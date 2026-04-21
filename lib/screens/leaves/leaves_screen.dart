import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../services/api_service.dart';

class LeavesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const LeavesScreen({super.key, required this.userData});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _leaves = [];
  bool _loading = true;
  String _statusFilter = 'all'; // all, pending, approved, rejected

  static const Color _primary = Color(0xFF1565C0);

  String get userRole => widget.userData['role'] ?? 'employee';
  bool get isManagerOrAbove => ['admin', 'hr', 'manager'].contains(userRole);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isManagerOrAbove ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _fetchLeaves();
      }
    });
    _fetchLeaves();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaves() async {
    setState(() => _loading = true);
    try {
      String endpoint = '/leaves/?page_size=100';
      
      // Apply status filter
      if (_statusFilter != 'all') {
        endpoint += '&status=$_statusFilter';
      }
      
      // For managers/admin viewing team leaves, filter by assigned employees
      if (isManagerOrAbove && _tabController.index == 1) {
        // Team tab - will show leaves from assigned employees
        // Backend handles this filtering automatically
      }

      final res = await ApiService.get(endpoint);
      if (mounted) {
        setState(() {
          _leaves = res['data']?['results'] ?? res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('My Leaves'),
        bottom: isManagerOrAbove
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'My Leaves'),
                  Tab(text: 'Team Leaves'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildLeaveStats(),
          Expanded(
            child: isManagerOrAbove
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeavesList(showActions: false),
                      _buildLeavesList(showActions: true),
                    ],
                  )
                : _buildLeavesList(showActions: false),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyLeaveDialog,
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Apply Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Approved', 'approved'),
          const SizedBox(width: 8),
          _buildFilterChip('Rejected', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildLeaveStats() {
    // Calculate stats for current user
    final myLeaves = _leaves.where((l) => l['user'].toString() == widget.userData['id'].toString()).toList();
    final totalLeaves = myLeaves.length;
    final pendingLeaves = myLeaves.where((l) => l['status'] == 'pending').length;
    final approvedLeaves = myLeaves.where((l) => l['status'] == 'approved').length;
    final rejectedLeaves = myLeaves.where((l) => l['status'] == 'rejected').length;
    
    // Calculate monthly leave count
    final now = DateTime.now();
    final monthlyLeaves = myLeaves.where((l) {
      try {
        final createdAt = DateTime.parse(l['created_at'] ?? '');
        return createdAt.year == now.year && createdAt.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total', totalLeaves.toString(), _primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Pending', pendingLeaves.toString(), const Color(0xFFE65100))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Approved', approvedLeaves.toString(), const Color(0xFF2E7D32))),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Rejected', rejectedLeaves.toString(), const Color(0xFFC62828))),
            ],
          ),
          const SizedBox(height: 12),
          // Monthly Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monthlyLeaves == 0
                        ? 'No leaves this month. First leave won\'t require a document.'
                        : 'This month: $monthlyLeaves leave(s). Next leave will require a document.',
                    style: const TextStyle(fontSize: 11, color: _primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    Color chipColor;
    switch (value) {
      case 'pending':
        chipColor = const Color(0xFFE65100);
        break;
      case 'approved':
        chipColor = const Color(0xFF2E7D32);
        break;
      case 'rejected':
        chipColor = const Color(0xFFC62828);
        break;
      default:
        chipColor = _primary;
    }

    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _fetchLeaves();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLeavesList({required bool showActions}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_leaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _statusFilter == 'all' ? 'No leaves found' : 'No $_statusFilter leaves',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaves,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _leaves.length,
        itemBuilder: (_, i) => _buildLeaveCard(_leaves[i], showActions),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave, bool showActions) {
    final id = leave['id'];
    final leaveType = leave['leave_type'] ?? 'casual';
    final startDate = leave['start_date'] ?? '';
    final endDate = leave['end_date'] ?? '';
    final reason = leave['reason'] ?? '';
    final status = leave['status'] ?? 'pending';
    final userName = leave['user_name'] ?? 'Unknown';
    final durationDays = leave['duration_days'] ?? 0;
    final createdAt = leave['created_at'] ?? '';

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF2E7D32);
        break;
      case 'rejected':
        statusColor = const Color(0xFFC62828);
        break;
      default:
        statusColor = const Color(0xFFE65100);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getLeaveTypeLabel(leaveType),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (showActions) ...[
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$durationDays day${durationDays > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showActions && status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectLeave(id),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveLeave(id),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!showActions && status == 'rejected' && leave['rejection_reason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFC62828)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${leave['rejection_reason']}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Document and Delete Actions
            if (leave['document_url'] != null || _canDeleteLeave(leave)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (leave['document_url'] != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewDocument(leave['document_url']),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('View Doc'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_canDeleteLeave(leave)) const SizedBox(width: 8),
                  ],
                  if (_canDeleteLeave(leave))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDeleteLeave(id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFC62828)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canDeleteLeave(Map<String, dynamic> leave) {
    final leaveUserId = leave['user'].toString();
    final currentUserId = widget.userData['id'].toString();
    final leaveStatus = leave['status'];
    
    // Admin can delete any leave
    if (userRole == 'admin') return true;
    
    // Manager can delete employee leaves
    if (userRole == 'manager' && leave['user_role'] == 'employee') return true;
    
    // Employee CANNOT delete leaves in mobile app
    // (They can only delete via web interface)
    if (userRole == 'employee') {
      return false;
    }
    
    return false;
  }

  Future<void> _viewDocument(String? documentUrl) async {
    if (documentUrl == null || documentUrl.isEmpty) return;
    
    try {
      final uri = Uri.parse(documentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteLeave(int leaveId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Leave'),
        content: const Text('Are you sure you want to delete this leave request? This action cannot be undone.'),
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

    if (confirmed == true) {
      await _deleteLeave(leaveId);
    }
  }

  Future<void> _deleteLeave(int leaveId) async {
    try {
      final res = await ApiService.request(
        endpoint: '/leaves/$leaveId/',
        method: 'DELETE',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLeaves();
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

  String _getLeaveTypeLabel(String type) {
    switch (type) {
      case 'sick':
        return 'Sick Leave';
      case 'casual':
        return 'Casual Leave';
      case 'annual':
        return 'Annual Leave';
      case 'other':
        return 'Other';
      default:
        return type.toUpperCase();
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _approveLeave(int leaveId) async {
    try {
      final res = await ApiService.request(
        endpoint: '/leaves/$leaveId/approve/',
        method: 'PATCH',
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchLeaves();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['error'] ?? 'Failed to approve'}'),
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

  Future<void> _rejectLeave(int leaveId) async {
    // Show dialog to get rejection reason
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {},
              controller: TextEditingController(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final controller = (ctx as Element)
                  .findAncestorWidgetOfExactType<AlertDialog>()
                  ?.content as Column?;
              final textField = controller?.children.last as TextField?;
              Navigator.pop(context, textField?.controller?.text ?? '');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    try {
      final res = await ApiService.request(
        endpoint: '/leaves/$leaveId/reject/',
        method: 'PATCH',
        body: {'rejection_reason': reason},
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          _fetchLeaves();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['error'] ?? 'Failed to reject'}'),
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

  void _showApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (_) => _ApplyLeaveDialog(
        userData: widget.userData,
        onSuccess: () {
          _fetchLeaves();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ApplyLeaveDialog - Apply Leave Form Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ApplyLeaveDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onSuccess;

  const _ApplyLeaveDialog({
    required this.userData,
    required this.onSuccess,
  });

  @override
  State<_ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<_ApplyLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  String _leaveType = 'casual';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  File? _selectedDocument;
  String? _selectedFileName;

  static const Color _primary = Color(0xFF1565C0);

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _durationDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  // Calculate monthly leave count to determine if document is required
  int get _monthlyLeaveCount {
    // This would be passed from parent or calculated
    // For now, we'll make it optional
    return 0;
  }

  bool get _isDocumentRequired => _monthlyLeaveCount >= 1;

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        
        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size must be less than 10MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedDocument = file;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeDocument() {
    setState(() {
      _selectedDocument = null;
      _selectedFileName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if document is required but not provided
    if (_isDocumentRequired && _selectedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document is required for your 2nd leave onwards in the current month'),
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
        'leave_type': _leaveType,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'reason': _reasonCtrl.text.trim(),
      };

      // If document is selected, use multipart upload
      final res = _selectedDocument != null
          ? await ApiService.postWithFile(
              '/leaves/',
              body,
              _selectedDocument!,
              'document',
            )
          : await ApiService.post('/leaves/', body);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['detail'] ?? 'Failed to submit'}'),
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
        constraints: const BoxConstraints(maxHeight: 600),
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
                  const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Apply for Leave',
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
                    // Leave Type
                    const Text(
                      'Leave Type *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                          value: _leaveType,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: _primary),
                          items: const [
                            DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
                            DropdownMenuItem(value: 'casual', child: Text('Casual Leave')),
                            DropdownMenuItem(value: 'annual', child: Text('Annual Leave')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _leaveType = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Start Date
                    const Text(
                      'Start Date *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    _buildDateField(
                      value: _startDate,
                      onChanged: (date) => setState(() => _startDate = date),
                    ),
                    const SizedBox(height: 16),

                    // End Date
                    const Text(
                      'End Date *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    _buildDateField(
                      value: _endDate,
                      onChanged: (date) => setState(() => _endDate = date),
                    ),
                    const SizedBox(height: 16),

                    // Duration Display
                    if (_durationDays > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: _primary),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: $_durationDays day${_durationDays > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Reason
                    const Text(
                      'Reason *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 4,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for leave',
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
                    const SizedBox(height: 16),

                    // Document Upload
                    Row(
                      children: [
                        const Text(
                          'Supporting Document',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        if (_isDocumentRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(fontSize: 10, color: Color(0xFFC62828), fontWeight: FontWeight.w600),
                            ),
                          )
                        else
                          const Text(
                            '(Optional)',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                    if (_isDocumentRequired) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Document required from 2nd leave onwards in current month',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_selectedDocument != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_rounded, color: _primary, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName ?? 'Document',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedDocument != null)
                                    FutureBuilder<int>(
                                      future: _selectedDocument!.length(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final kb = (snapshot.data! / 1024).toStringAsFixed(1);
                                          return Text(
                                            '$kb KB',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: _removeDocument,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _pickDocument,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.upload_file_rounded, size: 32, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              const Text(
                                'Click to upload document',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PDF, JPG, PNG (max 10MB)',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
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
                          : const Text('Submit Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildDateField({
    required DateTime? value,
    required void Function(DateTime?) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                    ? 'Select date'
                    : DateFormat('EEEE, MMM dd, yyyy').format(value),
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
    );
  }
}
