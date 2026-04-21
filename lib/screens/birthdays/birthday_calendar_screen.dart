import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class BirthdayCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BirthdayCalendarScreen({super.key, required this.userData});

  @override
  State<BirthdayCalendarScreen> createState() => _BirthdayCalendarScreenState();
}

class _BirthdayCalendarScreenState extends State<BirthdayCalendarScreen> {
  static const Color _primary = Color(0xFF1565C0);
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<dynamic> _allBirthdays = [];
  List<dynamic> _todayBirthdays = [];
  List<dynamic> _upcomingBirthdays = [];
  Map<DateTime, List<dynamic>> _birthdayEvents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchBirthdays();
  }

  Future<void> _fetchBirthdays() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/birthdays/'),
        ApiService.get('/birthdays/today_birthdays/'),
        ApiService.get('/birthdays/upcoming_birthdays/'),
      ]);

      if (mounted) {
        final allBirthdays = results[0]['data']?['results'] ?? [];
        final todayBirthdays = results[1]['data'] ?? [];
        final upcomingBirthdays = results[2]['data'] ?? [];

        // Build birthday events map for calendar
        final events = <DateTime, List<dynamic>>{};
        for (var birthday in allBirthdays) {
          if (birthday['birth_date'] != null) {
            try {
              final birthDate = DateTime.parse(birthday['birth_date']);
              // Create date for this year
              final thisYearDate = DateTime(_focusedDay.year, birthDate.month, birthDate.day);
              final key = DateTime(thisYearDate.year, thisYearDate.month, thisYearDate.day);
              
              if (events[key] == null) {
                events[key] = [];
              }
              events[key]!.add(birthday);
            } catch (e) {
              print('Error parsing birth date: $e');
            }
          }
        }

        setState(() {
          _allBirthdays = allBirthdays;
          _todayBirthdays = todayBirthdays;
          _upcomingBirthdays = upcomingBirthdays;
          _birthdayEvents = events;
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

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _birthdayEvents[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Birthday Calendar', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBirthdays,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _fetchBirthdays,
              color: _primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildCalendar(),
                    const SizedBox(height: 16),
                    if (_todayBirthdays.isNotEmpty) _buildTodaySection(),
                    if (_upcomingBirthdays.isNotEmpty) _buildUpcomingSection(),
                    if (_selectedDay != null) _buildSelectedDaySection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: _primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          outsideDaysVisible: false,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: const TextStyle(
            color: _primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildTodaySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '🎉 Today\'s Birthdays (${_todayBirthdays.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._todayBirthdays.map((birthday) => _buildTodayBirthdayCard(birthday)),
        ],
      ),
    );
  }

  Widget _buildTodayBirthdayCard(Map<String, dynamic> birthday) {
    final name = birthday['employee_name'] ?? 'Unknown';
    final role = birthday['employee_role'] ?? '';
    final company = birthday['employee_company'] ?? '';
    final age = birthday['age'];
    final showAge = birthday['show_age'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$role${company.isNotEmpty ? ' • $company' : ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                if (showAge && age != null)
                  Text(
                    '$age years old',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.event_rounded, color: _primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Birthdays (Next 30 Days)',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingBirthdays.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, index) => _buildUpcomingBirthdayTile(_upcomingBirthdays[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBirthdayTile(Map<String, dynamic> birthday) {
    final name = birthday['employee_name'] ?? 'Unknown';
    final role = birthday['employee_role'] ?? '';
    final company = birthday['employee_company'] ?? '';
    final daysUntil = birthday['days_until_birthday'] ?? 0;
    final nextBirthday = birthday['next_birthday'];
    final age = birthday['age'];
    final showAge = birthday['show_age'] ?? true;

    Color badgeColor;
    if (daysUntil <= 7) {
      badgeColor = Colors.orange;
    } else if (daysUntil <= 14) {
      badgeColor = Colors.blue;
    } else {
      badgeColor = Colors.grey;
    }

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$role${company.isNotEmpty ? ' • $company' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (nextBirthday != null)
            Text(
              DateFormat('MMM dd, yyyy').format(DateTime.parse(nextBirthday)),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          if (showAge && age != null)
            Text(
              'Turning ${age + 1}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Text(
          daysUntil == 1 ? 'Tomorrow' : '$daysUntil days',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDaySection() {
    final events = _getEventsForDay(_selectedDay!);
    
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Birthdays on ${DateFormat('MMMM dd, yyyy').format(_selectedDay!)}',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, index) => _buildBirthdayTile(events[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayTile(Map<String, dynamic> birthday) {
    final name = birthday['employee_name'] ?? 'Unknown';
    final role = birthday['employee_role'] ?? '';
    final company = birthday['employee_company'] ?? '';
    final age = birthday['age'];
    final showAge = birthday['show_age'] ?? true;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cake_rounded, color: _primary, size: 22),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$role${company.isNotEmpty ? ' • $company' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (showAge && age != null)
            Text(
              '$age years old',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}
