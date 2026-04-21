import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BirthdaysScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BirthdaysScreen({super.key, required this.userData});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  static const Color _primary = Color(0xFF1565C0);
  
  List<dynamic> _birthdays = [];
  bool _loading = true;
  String _filter = 'all'; // all, today, this_week, this_month
  
  @override
  void initState() {
    super.initState();
    _fetchBirthdays();
  }

  Future<void> _fetchBirthdays() async {
    setState(() => _loading = true);
    try {
      String url = '/birthdays/';
      if (_filter != 'all') {
        url += '?filter=$_filter';
      }
      
      final res = await ApiService.get(url);
      if (mounted) {
        setState(() {
          _birthdays = res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading birthdays: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Birthdays', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _birthdays.isEmpty
                    ? _buildEmptyState()
                    : _buildBirthdaysList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Today', 'today'),
            const SizedBox(width: 8),
            _buildFilterChip('This Week', 'this_week'),
            const SizedBox(width: 8),
            _buildFilterChip('This Month', 'this_month'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
        _fetchBirthdays();
      },
      backgroundColor: Colors.grey[100],
      selectedColor: _primary.withOpacity(0.2),
      checkmarkColor: _primary,
      labelStyle: TextStyle(
        color: isSelected ? _primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildBirthdaysList() {
    return RefreshIndicator(
      onRefresh: _fetchBirthdays,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _birthdays.length,
        itemBuilder: (context, index) {
          return _buildBirthdayCard(_birthdays[index]);
        },
      ),
    );
  }

  Widget _buildBirthdayCard(Map<String, dynamic> birthday) {
    final name = '${birthday['first_name'] ?? ''} ${birthday['last_name'] ?? ''}'.trim();
    final designation = birthday['designation'] ?? '';
    final phone = birthday['phone'] ?? '';
    final email = birthday['email'] ?? '';
    final dateOfBirth = birthday['date_of_birth'];
    
    DateTime? birthDate;
    String dateStr = '';
    String ageStr = '';
    bool isToday = false;
    
    if (dateOfBirth != null) {
      try {
        birthDate = DateTime.parse(dateOfBirth);
        final now = DateTime.now();
        final thisYearBirthday = DateTime(now.year, birthDate.month, birthDate.day);
        
        dateStr = DateFormat('MMM dd').format(birthDate);
        final age = now.year - birthDate.year;
        ageStr = 'Turns $age';
        
        isToday = thisYearBirthday.year == now.year &&
                  thisYearBirthday.month == now.month &&
                  thisYearBirthday.day == now.day;
      } catch (e) {
        // Invalid date
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: Colors.pink, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isToday ? Colors.pink[50] : _primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.pink : _primary,
                    ),
                  ),
                ),
                if (isToday)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cake_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (designation.isNotEmpty)
                    Text(
                      designation,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cake_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (ageStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ageStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.pink[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🎉 Birthday Today!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.pink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    color: Colors.green,
                    onPressed: () => _makeCall(phone),
                  ),
                if (email.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.email_outlined, size: 20),
                    color: _primary,
                    onPressed: () => _sendEmail(email),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No birthdays found';
    if (_filter == 'today') {
      message = 'No birthdays today';
    } else if (_filter == 'this_week') {
      message = 'No birthdays this week';
    } else if (_filter == 'this_month') {
      message = 'No birthdays this month';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cake_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make call')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email')),
        );
      }
    }
  }
}
