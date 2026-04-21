import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class HolidaysScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HolidaysScreen({super.key, required this.userData});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  static const Color _primary = Color(0xFF1565C0);
  
  List<dynamic> _holidays = [];
  bool _loading = true;
  String _selectedYear = DateTime.now().year.toString();
  
  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/holidays/?year=$_selectedYear');
      if (mounted) {
        setState(() {
          _holidays = res['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading holidays: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Holidays', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _showYearPicker,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildYearSelector(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _holidays.isEmpty
                    ? _buildEmptyState()
                    : _buildHolidaysList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Year: $_selectedYear',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _selectedYear = (int.parse(_selectedYear) - 1).toString();
                  });
                  _fetchHolidays();
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _selectedYear = (int.parse(_selectedYear) + 1).toString();
                  });
                  _fetchHolidays();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysList() {
    // Group holidays by month
    Map<String, List<dynamic>> groupedHolidays = {};
    for (var holiday in _holidays) {
      try {
        final date = DateTime.parse(holiday['date']);
        final monthKey = DateFormat('MMMM yyyy').format(date);
        groupedHolidays.putIfAbsent(monthKey, () => []);
        groupedHolidays[monthKey]!.add(holiday);
      } catch (e) {
        // Skip invalid dates
      }
    }

    return RefreshIndicator(
      onRefresh: _fetchHolidays,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedHolidays.length,
        itemBuilder: (context, index) {
          final monthKey = groupedHolidays.keys.elementAt(index);
          final monthHolidays = groupedHolidays[monthKey]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8, top: index == 0 ? 0 : 16),
                child: Text(
                  monthKey,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...monthHolidays.map((holiday) => _buildHolidayCard(holiday)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHolidayCard(Map<String, dynamic> holiday) {
    final date = DateTime.parse(holiday['date']);
    final dayName = DateFormat('EEEE').format(date);
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final isUpcoming = date.isAfter(DateTime.now());
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpcoming ? _primary.withOpacity(0.3) : Colors.grey[200]!,
          width: isUpcoming ? 2 : 1,
        ),
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey[100]
                    : isUpcoming
                        ? _primary.withOpacity(0.1)
                        : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPast
                          ? Colors.grey
                          : isUpcoming
                              ? _primary
                              : Colors.orange,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isPast
                          ? Colors.grey
                          : isUpcoming
                              ? _primary
                              : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday['name'] ?? 'Holiday',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPast ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (holiday['description'] != null && holiday['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        holiday['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (isUpcoming)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getDaysUntil(date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDaysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return 'In $difference days';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No holidays found for $_selectedYear',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different year',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Year'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            selectedDate: DateTime(int.parse(_selectedYear)),
            onChanged: (date) {
              setState(() {
                _selectedYear = date.year.toString();
              });
              _fetchHolidays();
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
