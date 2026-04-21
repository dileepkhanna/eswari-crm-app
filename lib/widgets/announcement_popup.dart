import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'dart:async';

class AnnouncementPopup extends StatefulWidget {
  const AnnouncementPopup({super.key});

  @override
  State<AnnouncementPopup> createState() => _AnnouncementPopupState();
}

class _AnnouncementPopupState extends State<AnnouncementPopup> {
  List<dynamic> _unreadAnnouncements = [];
  bool _loading = true;
  bool _hasShown = false;

  @override
  void initState() {
    super.initState();
    _fetchUnreadAnnouncements();
  }

  Future<void> _fetchUnreadAnnouncements() async {
    if (_hasShown) return; // Only show once per session
    
    try {
      final res = await ApiService.get('${ApiConfig.announcements}unread/');
      if (mounted && res['data'] != null) {
        final announcements = res['data'] as List;
        if (announcements.isNotEmpty) {
          setState(() {
            _unreadAnnouncements = announcements;
            _loading = false;
          });
          // Show popup after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasShown) {
              _showAnnouncementDialog();
            }
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      print('Error fetching unread announcements: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAnnouncementDialog() {
    if (_hasShown || !mounted) return;
    _hasShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AnnouncementDialog(
        announcements: _unreadAnnouncements,
        onMarkAsRead: _markAsRead,
        onMarkAllAsRead: _markAllAsRead,
      ),
    );
  }

  Future<void> _markAsRead(int announcementId) async {
    try {
      await ApiService.post(
        '${ApiConfig.announcements}$announcementId/mark_read/',
        {},
      );
      if (mounted) {
        setState(() {
          _unreadAnnouncements.removeWhere((a) => a['id'] == announcementId);
        });
      }
    } catch (e) {
      print('Error marking announcement as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.post('${ApiConfig.announcements}mark_all_read/', {});
      if (mounted) {
        setState(() {
          _unreadAnnouncements.clear();
        });
      }
    } catch (e) {
      print('Error marking all announcements as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget doesn't render anything visible
    return const SizedBox.shrink();
  }
}

class _AnnouncementDialog extends StatefulWidget {
  final List<dynamic> announcements;
  final Function(int) onMarkAsRead;
  final Function() onMarkAllAsRead;

  const _AnnouncementDialog({
    required this.announcements,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
  });

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return const Color(0xFF1565C0);
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      default:
        return 'Normal';
    }
  }

  void _nextAnnouncement() {
    if (_currentIndex < widget.announcements.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousAnnouncement() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _markCurrentAsRead() {
    final announcement = widget.announcements[_currentIndex];
    widget.onMarkAsRead(announcement['id']);
    
    if (_currentIndex >= widget.announcements.length - 1) {
      // Last announcement, close dialog
      Navigator.of(context).pop();
    } else {
      // Move to next announcement
      _nextAnnouncement();
    }
  }

  void _markAllAndClose() {
    widget.onMarkAllAsRead();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcements[_currentIndex];
    final priority = announcement['priority'] ?? 'low';
    final priorityColor = _getPriorityColor(priority);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getPriorityIcon(priority),
                          color: priorityColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Announcement',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getPriorityLabel(priority),
                              style: TextStyle(
                                fontSize: 14,
                                color: priorityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.announcements.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.announcements.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.announcements.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final ann = widget.announcements[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          ann['title'] ?? 'Announcement',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ann['message'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        // Document attachment (if any)
                        if (ann['document_url'] != null && ann['document_name'] != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Attachment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.attach_file_rounded, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ann['document_name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.download_rounded, color: Colors.blue[700], size: 20),
                                  onPressed: () {
                                    // TODO: Implement document download
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Download: ${ann['document_name']}')),
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Created date
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(ann['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Navigation buttons (if multiple announcements)
                  if (widget.announcements.length > 1) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentIndex > 0 ? _previousAnnouncement : null,
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentIndex < widget.announcements.length - 1
                                ? _nextAnnouncement
                                : null,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Next'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      if (widget.announcements.length > 1)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _markAllAndClose,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Mark All Read'),
                          ),
                        ),
                      if (widget.announcements.length > 1) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _markCurrentAsRead,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: priorityColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentIndex >= widget.announcements.length - 1
                                ? 'Got it!'
                                : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes} minutes ago';
        }
        return '${diff.inHours} hours ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
