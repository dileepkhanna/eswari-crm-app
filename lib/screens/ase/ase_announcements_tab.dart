import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class ASEAnnouncementsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ASEAnnouncementsTab({super.key, required this.userData});

  @override
  State<ASEAnnouncementsTab> createState() => _ASEAnnouncementsTabState();
}

class _ASEAnnouncementsTabState extends State<ASEAnnouncementsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _items = [];
  bool _loading = true;
  String _filter = 'all'; // all, unread

  static const Color _primary = Color(0xFF1565C0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final endpoint = _filter == 'unread' 
          ? '${ApiConfig.announcements}unread/?page_size=50'
          : '${ApiConfig.announcements}?page_size=50';
      
      final res = await ApiService.get(endpoint);
      if (mounted) {
        setState(() {
          _items   = res['data']?['results'] ?? res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(int announcementId) async {
    try {
      await ApiService.post('${ApiConfig.announcements}$announcementId/mark_read/', {});
      // Refresh the list to update read status
      _fetch();
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.post('${ApiConfig.announcements}mark_all_read/', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All announcements marked as read'),
            backgroundColor: Colors.green,
          ),
        );
        _fetch();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark all as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: _primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _buildCard(_items[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', 'unread'),
              ],
            ),
          ),
          if (_items.isNotEmpty && _filter == 'all')
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Mark All Read', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _fetch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primary : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _filter == 'unread' ? 'No unread announcements' : 'No announcements',
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_filter == 'unread') ...[
            const SizedBox(height: 8),
            Text('You\'re all caught up!',
                style: TextStyle(fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6))),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final id       = item['id'];
    final title    = item['title'] ?? 'Announcement';
    final message  = item['message'] ?? item['content'] ?? '';
    final date     = item['created_at'] ?? '';
    final priority = item['priority'] ?? 'medium';
    final createdBy = item['created_by_name'] ?? 'Admin';
    final documentUrl = item['document_url'];
    final documentName = item['document_name'];
    final isRead = item['is_read'] == true;

    final Color color = priority == 'high'
        ? const Color(0xFFC62828)
        : priority == 'medium'
            ? const Color(0xFFE65100)
            : _primary;

    return GestureDetector(
      onTap: () => _showDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                  Icon(Icons.campaign_rounded, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority != 'low')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (!isRead) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async { await _markAsRead(id); _fetch(); },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.mark_email_read_outlined,
                            color: _primary, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message,
                    style: TextStyle(fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.85)),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (documentUrl != null && documentName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 14, color: _primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(documentName,
                            style: const TextStyle(fontSize: 11, color: _primary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 12,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(createdBy,
                      style: TextStyle(fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time_rounded, size: 12,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(_formatDate(date),
                      style: TextStyle(fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                  if (!isRead) ...[
                    const Spacer(),
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: _primary, shape: BoxShape.circle)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final id = item['id'];
    
    // Mark as read when opening detail
    _markAsRead(id);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AnnouncementDetailSheet(announcement: item),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          if (diff.inMinutes == 0) {
            return 'Just now';
          }
          return '${diff.inMinutes}m ago';
        }
        return '${diff.inHours}h ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(dt);
      }
    } catch (_) {
      return raw;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnnouncementDetailSheet - Announcement Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const _AnnouncementDetailSheet({required this.announcement});

  static const Color _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = announcement['title'] ?? 'Announcement';
    final message = announcement['message'] ?? announcement['content'] ?? '';
    final date = announcement['created_at'] ?? '';
    final priority = announcement['priority'] ?? 'medium';
    final createdBy = announcement['created_by_name'] ?? 'Admin';
    final documentUrl = announcement['document_url'];
    final documentName = announcement['document_name'];
    final targetRoles = announcement['target_roles'] as List? ?? [];

    final Color color = priority == 'high'
        ? const Color(0xFFC62828)
        : priority == 'medium'
            ? const Color(0xFFE65100)
            : _primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(isDark ? 0.2 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.campaign_rounded, color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 4),
                            if (priority != 'low')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(priority.toUpperCase(),
                                    style: TextStyle(fontSize: 10, color: color,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (message.isNotEmpty) ...[
                    Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(message, style: TextStyle(fontSize: 14, height: 1.5,
                        color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 20),
                  ],
                  if (documentUrl != null && documentName != null) ...[
                    Text('Attachment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openDocument(documentUrl),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file_rounded, color: _primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(documentName,
                                style: const TextStyle(fontSize: 13, color: _primary,
                                    fontWeight: FontWeight.w500))),
                            const Icon(Icons.open_in_new_rounded, color: _primary, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow(Icons.person_outline_rounded, 'Posted by', createdBy, theme),
                        const SizedBox(height: 8),
                        _buildMetaRow(Icons.access_time_rounded, 'Posted on', _formatFullDate(date), theme),
                        if (targetRoles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildMetaRow(Icons.group_outlined, 'Target',
                              targetRoles.map((r) => r.toString().toUpperCase()).join(', '), theme),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _buildMetaRow(IconData icon, String label, String value, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface))),
      ],
    );
  }

  String _formatFullDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _openDocument(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Silently fail
    }
  }
}
