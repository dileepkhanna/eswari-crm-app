import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'dart:async';

class AnnouncementNotificationBanner extends StatefulWidget {
  const AnnouncementNotificationBanner({super.key});

  @override
  State<AnnouncementNotificationBanner> createState() => _AnnouncementNotificationBannerState();
}

class _AnnouncementNotificationBannerState extends State<AnnouncementNotificationBanner> {
  List<dynamic> _unreadAnnouncements = [];
  int _currentAnnouncementIndex = 0;
  bool _isVisible = false;
  Timer? _pollTimer;
  Timer? _autoHideTimer;
  final Set<int> _shownAnnouncementIds = {};

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Check for new announcements every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForNewAnnouncements();
    });
    // Initial check
    _checkForNewAnnouncements();
  }

  Future<void> _checkForNewAnnouncements() async {
    try {
      final res = await ApiService.get('${ApiConfig.announcements}unread/');
      if (mounted && res['data'] != null) {
        final announcements = res['data'] as List;
        
        // Filter out announcements we've already shown
        final newAnnouncements = announcements
            .where((a) => !_shownAnnouncementIds.contains(a['id']))
            .toList();
        
        if (newAnnouncements.isNotEmpty) {
          setState(() {
            _unreadAnnouncements = newAnnouncements;
            _currentAnnouncementIndex = 0;
            _isVisible = true;
          });
          
          // Mark as shown
          for (var announcement in newAnnouncements) {
            _shownAnnouncementIds.add(announcement['id']);
          }
          
          // Auto-hide after 10 seconds
          _autoHideTimer?.cancel();
          _autoHideTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              setState(() => _isVisible = false);
            }
          });
        }
      }
    } catch (e) {
      print('Error checking announcements: $e');
    }
  }

  Future<void> _markAsRead(int announcementId) async {
    try {
      await ApiService.post(
        '${ApiConfig.announcements}$announcementId/mark_read/',
        {},
      );
    } catch (e) {
      print('Error marking announcement as read: $e');
    }
  }

  void _dismissCurrent() {
    if (_unreadAnnouncements.isEmpty) return;
    
    final announcement = _unreadAnnouncements[_currentAnnouncementIndex];
    _markAsRead(announcement['id']);
    
    setState(() {
      _unreadAnnouncements.removeAt(_currentAnnouncementIndex);
      if (_unreadAnnouncements.isEmpty) {
        _isVisible = false;
      } else if (_currentAnnouncementIndex >= _unreadAnnouncements.length) {
        _currentAnnouncementIndex = _unreadAnnouncements.length - 1;
      }
    });
  }

  void _showNext() {
    if (_currentAnnouncementIndex < _unreadAnnouncements.length - 1) {
      setState(() => _currentAnnouncementIndex++);
    }
  }

  void _showPrevious() {
    if (_currentAnnouncementIndex > 0) {
      setState(() => _currentAnnouncementIndex--);
    }
  }

  void _viewDetails() {
    // Dismiss the banner and show full dialog
    setState(() => _isVisible = false);
    
    if (_unreadAnnouncements.isEmpty) return;
    
    final announcement = _unreadAnnouncements[_currentAnnouncementIndex];
    
    showDialog(
      context: context,
      builder: (context) => _AnnouncementDetailDialog(
        announcement: announcement,
        onMarkAsRead: () {
          _markAsRead(announcement['id']);
          Navigator.of(context).pop();
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _unreadAnnouncements.isEmpty) {
      return const SizedBox.shrink();
    }

    final announcement = _unreadAnnouncements[_currentAnnouncementIndex];
    final priority = announcement['priority'] ?? 'low';
    final priorityColor = _getPriorityColor(priority);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: _isVisible ? Offset.zero : const Offset(0, -1),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _viewDetails,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getPriorityIcon(priority),
                              color: priorityColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        announcement['title'] ?? 'Announcement',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_unreadAnnouncements.length > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_currentAnnouncementIndex + 1}/${_unreadAnnouncements.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: priorityColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  announcement['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: _dismissCurrent,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                      if (_unreadAnnouncements.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                              onPressed: _currentAnnouncementIndex > 0 ? _showPrevious : null,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Swipe for more',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 20),
                              onPressed: _currentAnnouncementIndex < _unreadAnnouncements.length - 1
                                  ? _showNext
                                  : null,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementDetailDialog extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback onMarkAsRead;

  const _AnnouncementDetailDialog({
    required this.announcement,
    required this.onMarkAsRead,
  });

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

  @override
  Widget build(BuildContext context) {
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: priorityColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      announcement['title'] ?? 'Announcement',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        announcement['message'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Document attachment (if any)
                    if (announcement['document_url'] != null &&
                        announcement['document_name'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file_rounded,
                                color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                announcement['document_name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onMarkAsRead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: priorityColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                  elevation: 0,
                ),
                child: const Text('Got it!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
