import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class EswariAnnouncementsScreen extends StatefulWidget {
  const EswariAnnouncementsScreen({super.key});

  @override
  State<EswariAnnouncementsScreen> createState() => _EswariAnnouncementsScreenState();
}

class _EswariAnnouncementsScreenState extends State<EswariAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  List<dynamic> _filteredAnnouncements = [];
  bool _loading = true;
  String _filter = 'all'; // all, unread
  String _priorityFilter = 'all'; // all, high, medium, low
  String _statusFilter = 'active'; // active, all, inactive
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/announcements/');
      if (mounted) {
        var list = (res['data']?['results'] ?? []) as List<dynamic>;
        
        setState(() {
          _announcements = list;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(_announcements);
    
    // Apply status filter (active/inactive)
    if (_statusFilter == 'active') {
      filtered = filtered.where((a) {
        if (a['is_active'] != true) return false;
        
        // Check expiry date
        if (a['expires_at'] != null) {
          try {
            final expiryDate = DateTime.parse(a['expires_at']);
            final now = DateTime.now();
            // Set to end of expiry date
            final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 23, 59, 59);
            final today = DateTime(now.year, now.month, now.day);
            return expiry.isAfter(today) || expiry.isAtSameMomentAs(today);
          } catch (_) {
            return true;
          }
        }
        return true;
      }).toList();
    } else if (_statusFilter == 'inactive') {
      filtered = filtered.where((a) => a['is_active'] != true).toList();
    }
    
    // Apply read/unread filter
    if (_filter == 'unread') {
      filtered = filtered.where((a) => a['is_read'] != true).toList();
    }
    
    // Apply priority filter
    if (_priorityFilter != 'all') {
      filtered = filtered.where((a) => a['priority'] == _priorityFilter).toList();
    }
    
    // Apply search filter
    final query = _searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((a) {
        final title = (a['title'] ?? '').toString().toLowerCase();
        final content = (a['content'] ?? '').toString().toLowerCase();
        final createdBy = (a['created_by_name'] ?? '').toString().toLowerCase();
        return title.contains(query) || content.contains(query) || createdBy.contains(query);
      }).toList();
    }
    
    setState(() {
      _filteredAnnouncements = filtered;
    });
  }

  Future<void> _markAsRead(int id) async {
    try {
      final res = await ApiService.post('/announcements/$id/mark_read/', {});
      
      if (mounted && res['success'] == true) {
        // Update local state immediately
        setState(() {
          final index = _announcements.indexWhere((a) => a['id'] == id);
          if (index != -1) {
            _announcements[index]['is_read'] = true;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
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

  Future<void> _markAllAsRead() async {
    try {
      final res = await ApiService.post('/announcements/mark_all_read/', {});
      
      if (mounted && res['success'] == true) {
        // Update all announcements to read in local state
        setState(() {
          for (var announcement in _announcements) {
            announcement['is_read'] = true;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All announcements marked as read'),
            backgroundColor: Colors.green,
          ),
        );
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

  String _getRelativeTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM dd').format(date);
    } catch (_) {
      return '';
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = _announcements.where((a) => a['is_read'] != true).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Announcements', 
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildFilterBar(context, unreadCount),
          _buildFiltersRow(context),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : _filteredAnnouncements.isEmpty
                    ? _buildEmpty(context)
                    : RefreshIndicator(
                        onRefresh: _fetchAnnouncements,
                        color: theme.colorScheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (_, i) => _buildAnnouncementCard(context, _filteredAnnouncements[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search announcements...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, int unreadCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip(context, 'All', 'all', _announcements.length),
          const SizedBox(width: 8),
          _filterChip(context, 'Unread', 'unread', unreadCount),
          const Spacer(),
          Text(
            '${_filteredAnnouncements.length} of ${_announcements.length}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              context,
              value: _priorityFilter,
              items: const ['all', 'high', 'medium', 'low'],
              labels: const {'all': 'All Priorities', 'high': 'High', 'medium': 'Medium', 'low': 'Low'},
              onChanged: (value) {
                setState(() => _priorityFilter = value!);
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDropdown(
              context,
              value: _statusFilter,
              items: const ['active', 'all', 'inactive'],
              labels: const {'active': 'Active', 'all': 'All Status', 'inactive': 'Inactive'},
              onChanged: (value) {
                setState(() => _statusFilter = value!);
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String value,
    required List<String> items,
    required Map<String, String> labels,
    required void Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant, size: 20),
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surface,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                labels[item] ?? item,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, String value, int count) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _filter == value;
    
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 13,
            color: selected 
              ? (isDark ? Colors.black : Colors.white)
              : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Map<String, dynamic> announcement) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRead = announcement['is_read'] == true;
    final priority = announcement['priority'] ?? 'low';
    final priorityColor = _getPriorityColor(priority);
    final title = announcement['title'] ?? 'Untitled';
    final createdBy = announcement['created_by_name'] ?? 'Admin';
    final createdAt = _getRelativeTime(announcement['created_at']);
    final hasAttachments = announcement['document_url'] != null && announcement['document_name'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? Colors.transparent : theme.colorScheme.primary.withOpacity(0.3),
          width: isRead ? 0 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.campaign_rounded, color: priorityColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(createdBy, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 12),
                Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(createdAt, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: priorityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasAttachments) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.attach_file_rounded, size: 10, color: Colors.blue),
                        SizedBox(width: 2),
                        Text(
                          '1',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: !isRead
            ? IconButton(
                icon: Icon(
                  Icons.mark_email_read_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                onPressed: () async {
                  await _markAsRead(announcement['id']);
                  _applyFilters();
                },
                tooltip: 'Mark as read',
              )
            : null,
        onTap: () {
          if (!isRead) _markAsRead(announcement['id']);
          _showAnnouncementDetail(announcement);
        },
      ),
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = announcement['title'] ?? 'Untitled';
    final content = announcement['content'] ?? '';
    final priority = announcement['priority'] ?? 'low';
    final priorityColor = _getPriorityColor(priority);
    final createdBy = announcement['created_by_name'] ?? 'Admin';
    final createdAt = announcement['created_at'] != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(announcement['created_at']))
        : '';
    final hasDocument = announcement['document_url'] != null && announcement['document_name'] != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.campaign_rounded, color: priorityColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By $createdBy',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${priority.toUpperCase()} PRIORITY',
                      style: TextStyle(
                        fontSize: 10,
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(createdAt, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.onSurface),
              ),
              if (hasDocument) ...[
                const SizedBox(height: 20),
                Divider(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text(
                  'Attachment',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentTile(context, {
                  'name': announcement['document_name'],
                  'file': announcement['document_url'],
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext context, Map<String, dynamic> doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = doc['name'] ?? 'Document';
    final url = doc['file'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(isDark ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.insert_drive_file_rounded, color: Colors.blue, size: 20),
        ),
        title: Text(
          name, 
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.blue, size: 20),
          onPressed: () async {
            if (url.isNotEmpty) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters = _searchQuery.isNotEmpty || 
                       _priorityFilter != 'all' || 
                       _statusFilter != 'active' ||
                       _filter != 'all';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined, 
            size: 64, 
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters 
              ? 'No announcements found\nmatching your filters'
              : 'No announcements',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, 
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
