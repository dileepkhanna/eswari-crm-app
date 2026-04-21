// ═══════════════════════════════════════════════════════════════════════════
// SECTION 2: DATA FETCHING FUNCTIONS
// Add this after Section 1 in eswari_leads_tab.dart
// ═══════════════════════════════════════════════════════════════════════════

  // ── Fetch Leads ─────────────────────────────────────────────────────────────
  Future<void> _fetchLeads() async {
    setState(() => _loading = true);
    try {
      String url = '/leads/?page_size=$_pageSize&page=$_currentPage';
      
      // Apply filters
      if (_statusFilter != 'all') url += '&status=$_statusFilter';
      if (_requirementTypeFilter != 'all') url += '&requirement_type=$_requirementTypeFilter';
      if (_bhkFilter != 'all') url += '&bhk_requirement=$_bhkFilter';
      if (_sourceFilter != 'all') url += '&source=$_sourceFilter';
      if (_assignedToFilter != 'all') {
        if (_assignedToFilter == 'unassigned') {
          url += '&assigned_to__isnull=true';
        } else {
          url += '&assigned_to=$_assignedToFilter';
        }
      }
      if (_createdByFilter != 'all') url += '&created_by=$_createdByFilter';
      if (_search.isNotEmpty) url += '&search=$_search';
      
      final res = await ApiService.get(url);
      
      if (mounted) {
        final data = res['data'];
        final results = data?['results'] ?? [];
        
        // Calculate statistics
        _calculateStatistics(results);
        
        setState(() {
          _leads = results;
          _totalCount = data?['count'] ?? 0;
          _totalPages = (_totalCount / _pageSize).ceil();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading leads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // ── Calculate Statistics ────────────────────────────────────────────────────
  void _calculateStatistics(List<dynamic> leads) {
    _totalLeads = leads.length;
    _hotLeads = leads.where((l) => l['status'] == 'hot').length;
    _warmLeads = leads.where((l) => l['status'] == 'warm').length;
    _coldLeads = leads.where((l) => l['status'] == 'cold').length;
    _newLeads = leads.where((l) => l['status'] == 'new').length;
    _reminderLeads = leads.where((l) => l['status'] == 'reminder').length;
  }
  
  // ── Fetch Projects ──────────────────────────────────────────────────────────
  Future<void> _fetchProjects() async {
    try {
      final res = await ApiService.get('/projects/');
      if (mounted && res['success'] == true) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? res['data'] ?? []
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    }
  }
  
  // ── Fetch Employees ─────────────────────────────────────────────────────────
  Future<void> _fetchEmployees() async {
    try {
      final res = await ApiService.get('/accounts/users/?role=employee');
      if (mounted && res['success'] == true) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? res['data'] ?? []
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }
  
  // ── Fetch Creators ──────────────────────────────────────────────────────────
  Future<void> _fetchCreators() async {
    try {
      final res = await ApiService.get('/accounts/users/');
      if (mounted && res['success'] == true) {
        setState(() {
          _creators = List<Map<String, dynamic>>.from(
            res['data']?['results'] ?? res['data'] ?? []
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching creators: $e');
    }
  }
  
  // ── Create Lead ─────────────────────────────────────────────────────────────
  Future<void> _createLead(Map<String, dynamic> data) async {
    try {
      // Add company ID
      final company = widget.userData['company'];
      if (company is Map && company['id'] != null) {
        data['company'] = company['id'];
      }
      
      final res = await ApiService.post('/leads/', data);
      
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchLeads();
        } else {
          String errorMsg = 'Failed to create lead';
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
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
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
          ),
        );
      }
    }
  }
  
  // ── Update Lead ─────────────────────────────────────────────────────────────
  Future<void> _updateLead(String id, Map<String, dynamic> data) async {
    try {
      final res = await ApiService.request(
        endpoint: '/leads/$id/',
        method: 'PATCH',
        body: data,
      );
      
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchLeads();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${res['data']?['detail'] ?? 'Failed to update'}'),
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
  
  // ── Delete Lead ─────────────────────────────────────────────────────────────
  Future<void> _deleteLead(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete $name?'),
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

// ═══════════════════════════════════════════════════════════════════════════
// END OF SECTION 2
// Next: Add Section 3 (UI Components - Build Methods)
// ═══════════════════════════════════════════════════════════════════════════
