import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CapitalDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;

  const CapitalDashboardScreen({
    super.key,
    required this.userData,
    required this.isManager,
  });

  @override
  State<CapitalDashboardScreen> createState() => _CapitalDashboardScreenState();
}

class _CapitalDashboardScreenState extends State<CapitalDashboardScreen> {
  static const Color _primary = Color(0xFF1565C0);
  
  bool _loading = true;
  String? _error;
  
  // Stats
  int _totalCustomers = 0;
  int _convertedCustomers = 0;
  int _pendingCustomers = 0;
  
  int _totalLoans = 0;
  int _activeLoans = 0;
  int _disbursedLoans = 0;
  
  int _totalServices = 0;
  int _activeServices = 0;
  int _completedServices = 0;
  
  int _totalTasks = 0;
  int _pendingTasks = 0;
  int _completedTasks = 0;
  int _urgentTasks = 0;
  int _overdueTasks = 0;
  
  List<Map<String, dynamic>> _recentTasks = [];
  Map<String, int> _loanStatusBreakdown = {};
  Map<String, int> _serviceCategories = {};
  
  @override
  void initState() {
    super.initState();
    _fetchCapitalData();
  }

  Future<void> _fetchCapitalData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // Fetch all capital data in parallel
      final results = await Future.wait([
        ApiService.get('/capital/customers/'),
        ApiService.get('/capital/loans/'),
        ApiService.get('/capital/services/'),
        ApiService.get('/capital/tasks/'),
      ]);
      
      if (mounted) {
        // Process customers
        final customersData = results[0]['data'];
        final customers = (customersData is List ? customersData : (customersData?['results'] ?? [])) as List;
        _totalCustomers = customers.length;
        _convertedCustomers = customers.where((c) => c['is_converted'] == true).length;
        _pendingCustomers = customers.where((c) => c['call_status'] == 'pending').length;
        
        // Process loans
        final loansData = results[1]['data'];
        final loans = (loansData is List ? loansData : (loansData?['results'] ?? [])) as List;
        _totalLoans = loans.length;
        _activeLoans = loans.where((l) => ['inquiry', 'documents_pending', 'under_review', 'approved'].contains(l['status'])).length;
        _disbursedLoans = loans.where((l) => l['status'] == 'disbursed').length;
        
        // Loan status breakdown
        _loanStatusBreakdown = {
          'Inquiry': loans.where((l) => l['status'] == 'inquiry').length,
          'Docs Pending': loans.where((l) => l['status'] == 'documents_pending').length,
          'Under Review': loans.where((l) => l['status'] == 'under_review').length,
          'Approved': loans.where((l) => l['status'] == 'approved').length,
          'Disbursed': loans.where((l) => l['status'] == 'disbursed').length,
          'Rejected': loans.where((l) => l['status'] == 'rejected').length,
        };
        _loanStatusBreakdown.removeWhere((key, value) => value == 0);
        
        // Process services
        final servicesData = results[2]['data'];
        final services = (servicesData is List ? servicesData : (servicesData?['results'] ?? [])) as List;
        _totalServices = services.length;
        _activeServices = services.where((s) => ['inquiry', 'documents_pending', 'in_progress'].contains(s['status'])).length;
        _completedServices = services.where((s) => s['status'] == 'completed').length;
        
        // Service categories
        int gstCount = 0;
        int msmeCount = 0;
        int itrCount = 0;
        
        for (var service in services) {
          final serviceType = service['service_type'] ?? '';
          if (serviceType.contains('gst') || serviceType.contains('lut') || serviceType.contains('eway')) {
            gstCount++;
          } else if (serviceType.contains('msme')) {
            msmeCount++;
          } else if (serviceType.contains('itr')) {
            itrCount++;
          }
        }
        
        _serviceCategories = {
          'GST': gstCount,
          'MSME': msmeCount,
          'Income Tax': itrCount,
        };
        
        // Process tasks
        final tasksData = results[3]['data'];
        final tasks = (tasksData is List ? tasksData : (tasksData?['results'] ?? [])) as List;
        _totalTasks = tasks.length;
        _pendingTasks = tasks.where((t) => ['in_progress', 'follow_up', 'document_collection', 'processing'].contains(t['status'])).length;
        _completedTasks = tasks.where((t) => t['status'] == 'completed').length;
        _urgentTasks = tasks.where((t) => t['priority'] == 'urgent' && t['status'] != 'completed').length;
        
        // Overdue tasks
        final now = DateTime.now();
        _overdueTasks = tasks.where((t) {
          if (t['due_date'] == null || t['status'] == 'completed') return false;
          try {
            final dueDate = DateTime.parse(t['due_date']);
            return dueDate.isBefore(now);
          } catch (e) {
            return false;
          }
        }).length;
        
        // Recent tasks (top 5 pending)
        _recentTasks = tasks
            .where((t) => t['status'] != 'completed' && t['status'] != 'rejected')
            .take(5)
            .toList();
        
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load capital data: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Eswari Capital', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCapitalData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchCapitalData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top stat cards
                        _buildStatCards(),
                        const SizedBox(height: 16),
                        
                        // Alert row
                        if (_overdueTasks > 0 || _urgentTasks > 0) ...[
                          _buildAlerts(),
                          const SizedBox(height: 16),
                        ],
                        
                        // Details section
                        _buildDetailsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchCapitalData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Calls',
          _totalCustomers,
          '$_convertedCustomers converted · $_pendingCustomers pending',
          Icons.people_outline,
          Colors.blue,
        ),
        _buildStatCard(
          'Loans',
          _totalLoans,
          '$_activeLoans active · $_disbursedLoans disbursed',
          Icons.account_balance,
          Colors.green,
        ),
        _buildStatCard(
          'Services',
          _totalServices,
          '$_activeServices active · $_completedServices completed',
          Icons.description_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          'Tasks',
          _totalTasks,
          '$_pendingTasks pending · $_urgentTasks urgent',
          Icons.task_outlined,
          Colors.purple,
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, int value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlerts() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (_overdueTasks > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 16, color: Colors.red[700]),
                const SizedBox(width: 6),
                Text(
                  '$_overdueTasks overdue task${_overdueTasks > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        if (_urgentTasks > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  '$_urgentTasks urgent task${_urgentTasks > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildDetailsSection() {
    return Column(
      children: [
        // Loan Pipeline
        _buildLoanPipeline(),
        const SizedBox(height: 16),
        
        // Service Breakdown
        _buildServiceBreakdown(),
        const SizedBox(height: 16),
        
        // Pending Tasks
        _buildPendingTasks(),
      ],
    );
  }
  
  Widget _buildLoanPipeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, size: 16, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text(
                'Loan Pipeline',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loanStatusBreakdown.isEmpty)
            Text(
              'No loans yet',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          else
            ..._loanStatusBreakdown.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLoanStatusColor(entry.key).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getLoanStatusColor(entry.key),
                        ),
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildServiceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text(
                'Services by Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._serviceCategories.entries.map((entry) {
            final percentage = _totalServices > 0 ? (entry.value / _totalServices) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getServiceCategoryColor(entry.key),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildPendingTasks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.task_outlined, size: 16, color: Colors.purple[600]),
                  const SizedBox(width: 8),
                  const Text(
                    'Pending Tasks',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'View all',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentTasks.isEmpty)
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'All caught up',
                  style: TextStyle(fontSize: 12, color: Colors.green[600]),
                ),
              ],
            )
          else
            ..._recentTasks.map((task) {
              final priority = task['priority'] ?? 'normal';
              final priorityColor = priority == 'urgent'
                  ? Colors.red
                  : priority == 'high'
                      ? Colors.orange
                      : Colors.blue;
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? '—',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${task['loan_name'] ?? task['service_name'] ?? 'Unlinked'} · ${task['assigned_to_name'] ?? 'Unassigned'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
  
  Color _getLoanStatusColor(String status) {
    switch (status) {
      case 'Inquiry':
        return Colors.blue;
      case 'Docs Pending':
        return Colors.yellow[700]!;
      case 'Under Review':
        return Colors.purple;
      case 'Approved':
        return Colors.green;
      case 'Disbursed':
        return Colors.teal;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Color _getServiceCategoryColor(String category) {
    switch (category) {
      case 'GST':
        return Colors.orange;
      case 'MSME':
        return Colors.teal;
      case 'Income Tax':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
