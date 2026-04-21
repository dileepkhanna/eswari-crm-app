// ═══════════════════════════════════════════════════════════════════════════
// SECTION 1: CORE STRUCTURE + IMPORTS + STATE VARIABLES
// Copy this entire section to the top of eswari_leads_tab.dart
// ═══════════════════════════════════════════════════════════════════════════

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
// EswariLeadsTab - Real Estate Leads Management
// ─────────────────────────────────────────────────────────────────────────────
class EswariLeadsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  const EswariLeadsTab({
    super.key,
    required this.userData,
    required this.isManager,
  });

  @override
  State<EswariLeadsTab> createState() => _EswariLeadsTabState();
}

class _EswariLeadsTabState extends State<EswariLeadsTab>
    with AutomaticKeepAliveClientMixin {
  
  // ── Data Lists ──────────────────────────────────────────────────────────────
  List<dynamic> _leads = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _creators = [];
  
  // ── Loading States ──────────────────────────────────────────────────────────
  bool _loading = true;
  
  // ── Search ──────────────────────────────────────────────────────────────────
  String _search = '';
  final _searchCtrl = TextEditingController();
  
  // ── Filters ─────────────────────────────────────────────────────────────────
  String _statusFilter = 'all';
  String _requirementTypeFilter = 'all';
  String _bhkFilter = 'all';
  String _sourceFilter = 'all';
  String _assignedToFilter = 'all';
  String _createdByFilter = 'all';
  
  // ── Statistics ──────────────────────────────────────────────────────────────
  int _totalLeads = 0;
  int _hotLeads = 0;
  int _warmLeads = 0;
  int _coldLeads = 0;
  int _newLeads = 0;
  int _reminderLeads = 0;
  
  // ── Pagination ──────────────────────────────────────────────────────────────
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 50;
  
  // ── Colors ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1565C0); // ASE Blue
  
  static const _statusColors = {
    'new': Color(0xFF1565C0),           // Blue
    'hot': Color(0xFFD32F2F),           // Red
    'warm': Color(0xFFF57C00),          // Orange
    'cold': Color(0xFF0288D1),          // Light Blue
    'not_interested': Color(0xFF757575), // Grey
    'reminder': Color(0xFF6A1B9A),      // Purple
  };
  
  static const _statusLabels = {
    'new': 'New',
    'hot': 'Hot',
    'warm': 'Warm',
    'cold': 'Cold',
    'not_interested': 'Not Interested',
    'reminder': 'Reminder',
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
  
  @override
  void initState() {
    super.initState();
    _fetchLeads();
    _fetchProjects();
    if (widget.isManager) {
      _fetchEmployees();
      _fetchCreators();
    }
  }
  
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  
  // ── Helper: Phone Masking ───────────────────────────────────────────────────
  String _maskPhone(String phone) {
    if (!widget.isManager || phone.isEmpty) return phone;
    if (phone.length <= 4) return '****';
    return '${phone.substring(0, 2)}${'*' * (phone.length - 4)}${phone.substring(phone.length - 2)}';
  }
  
  // ── Helper: Email Masking ───────────────────────────────────────────────────
  String _maskEmail(String email) {
    if (!widget.isManager || email.isEmpty) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final username = parts[0];
    final domain = parts[1];
    
    final maskedUsername = username.length > 2
        ? '${username.substring(0, 2)}${'*' * (username.length - 2)}'
        : '**';
    
    final domainParts = domain.split('.');
    final maskedDomain = domainParts.length > 1
        ? '${domainParts[0].substring(0, min(2, domainParts[0].length))}${'*' * max(0, domainParts[0].length - 2)}.${domainParts[1]}'
        : domain;
    
    return '$maskedUsername@$maskedDomain';
  }
  
  int min(int a, int b) => a < b ? a : b;
  int max(int a, int b) => a > b ? a : b;
  
  // ── Helper: Active Filters Check ────────────────────────────────────────────
  bool get _hasActiveFilters {
    return _statusFilter != 'all' ||
        _requirementTypeFilter != 'all' ||
        _bhkFilter != 'all' ||
        _sourceFilter != 'all' ||
        _assignedToFilter != 'all' ||
        _createdByFilter != 'all' ||
        _search.isNotEmpty;
  }
  
  // ── Helper: Clear Filters ───────────────────────────────────────────────────
  void _clearFilters() {
    setState(() {
      _statusFilter = 'all';
      _requirementTypeFilter = 'all';
      _bhkFilter = 'all';
      _sourceFilter = 'all';
      _assignedToFilter = 'all';
      _createdByFilter = 'all';
      _search = '';
      _searchCtrl.clear();
      _currentPage = 1;
    });
    _fetchLeads();
  }

// ═══════════════════════════════════════════════════════════════════════════
// END OF SECTION 1
// Next: Add Section 2 (Data Fetching Functions)
// ═══════════════════════════════════════════════════════════════════════════
