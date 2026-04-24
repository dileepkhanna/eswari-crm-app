import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class CapitalAnnouncementsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CapitalAnnouncementsScreen({super.key, required this.userData});

  @override
  State<CapitalAnnouncementsScreen> createState() => _CapitalAnnouncementsScreenState();
}

class _CapitalAnnouncementsScreenState extends State<CapitalAnnouncementsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _error = '';
  String _filter = 'all';

  static const Color _primary = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _error = ''; });
    try {
      final endpoint = _filter == 'unread'
          ? '${ApiConfig.announcements}unread/?page_size=50'
          : '${ApiConfig.announcements}?page_size=50';

      final res = await ApiService.get(endpoint);
      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _items = data?['results'] ?? (data is List ? data : []);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load announcements (${res['status']})';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await ApiService.post('${ApiConfig.announcements}$id/mark_read/', {});
      _fetch();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.post('${ApiConfig.announcements}mark_all_read/', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All marked as read'), backgroundColor: Colors.green),
        );
        _fetch();
      }
    } catch (_) {}
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) { return raw; }
  }

  Color _priorityColor(String? p) {
    switch (p) {
      case 'high': return const Color(0xFFC62828);
      case 'medium': return const Color(0xFFE65100);
      default: return _primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Announcements', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              label: const Text('All Read', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(child: _buildBody(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _chip('All', 'all', isDark),
          const SizedBox(width: 8),
          _chip('Unread', 'unread', isDark),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, bool isDark) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _fetch(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F6FA)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Could not load announcements', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _filter == 'unread' ? 'No unread announcements\nYou\'re all caught up!' : 'No announcements',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) => _buildCard(_items[i], isDark),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, bool isDark) {
    final id = item['id'];
    final title = item['title'] ?? 'Announcement';
    final message = item['message'] ?? item['content'] ?? '';
    final priority = item['priority'] ?? 'low';
    final createdBy = item['created_by_name'] ?? 'Admin';
    final date = item['created_at'] ?? '';
    final isRead = item['is_read'] == true;
    final docUrl = item['document_url'];
    final docName = item['document_name'];
    final color = _priorityColor(priority);

    return GestureDetector(
      onTap: () {
        if (!isRead) _markAsRead(id);
        _showDetail(item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority != 'low')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(priority.toUpperCase(),
                          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
                    ),
                  if (!isRead) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _markAsRead(id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.mark_email_read_outlined, color: _primary, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
              if (docUrl != null && docName != null) ...[
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
                        child: Text(docName,
                            style: const TextStyle(fontSize: 11, color: _primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(createdBy, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(_formatDate(date), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (!isRead) ...[
                    const Spacer(),
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle)),
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
    final title = item['title'] ?? '';
    final message = item['message'] ?? item['content'] ?? '';
    final priority = item['priority'] ?? 'low';
    final createdBy = item['created_by_name'] ?? 'Admin';
    final date = item['created_at'] ?? '';
    final docUrl = item['document_url'];
    final docName = item['document_name'];
    final color = _priorityColor(priority);

    String fullDate = '';
    try { fullDate = DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(date).toLocal()); } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.campaign_rounded, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (priority != 'low')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text(priority.toUpperCase(),
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (message.isNotEmpty) ...[
                const Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 20),
              ],
              if (docUrl != null && docName != null) ...[
                const Text('Attachment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(docUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
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
                        Expanded(child: Text(docName, style: const TextStyle(fontSize: 13, color: _primary))),
                        const Icon(Icons.open_in_new_rounded, color: _primary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    _metaRow(Icons.person_outline_rounded, 'Posted by', createdBy),
                    const SizedBox(height: 8),
                    _metaRow(Icons.access_time_rounded, 'Posted on', fullDate),
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
                  child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
