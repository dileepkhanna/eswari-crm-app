import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class CapitalCustomersScreen extends StatefulWidget {
  final bool isManager;

  const CapitalCustomersScreen({Key? key, this.isManager = false}) : super(key: key);

  @override
  _CapitalCustomersScreenState createState() => _CapitalCustomersScreenState();
}

class _CapitalCustomersScreenState extends State<CapitalCustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _pageSize = 50;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'all', 'label': 'All'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'answered', 'label': 'Answered'},
    {'value': 'not_answered', 'label': 'Not Answered'},
    {'value': 'busy', 'label': 'Busy'},
    {'value': 'not_interested', 'label': 'Not Interested'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = '/capital/customers/?page=$_currentPage&page_size=$_pageSize';
      if (_selectedStatus != 'all') endpoint += '&call_status=$_selectedStatus';
      if (_searchQuery.isNotEmpty) endpoint += '&search=${Uri.encodeComponent(_searchQuery)}';

      final response = await ApiService.get(endpoint);
      final data = response['data'];

      if (data != null && data['results'] != null) {
        final results = (data['results'] as List).map((item) => item as Map<String, dynamic>).toList();
        final count = data['count'] ?? 0;

        setState(() {
          _customers = results;
          _filteredCustomers = results;
          _totalCount = count;
          _totalPages = (_totalCount / _pageSize).ceil();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading customers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e')),
        );
      }
    }
  }

  void _filterCustomers() {
    _currentPage = 1;
    _loadCustomers();
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() => _currentPage++);
      _loadCustomers();
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _loadCustomers();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'answered': return Colors.green;
      case 'pending': return Colors.orange;
      case 'not_answered': return Colors.red;
      case 'busy': return Colors.blue;
      case 'not_interested': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  String _maskPhone(String phone, int? createdById) {
    // No userId available in AuthService; managers see masked phones for others
    if (widget.isManager) {
      if (phone.length > 4) {
        return '******${phone.substring(phone.length - 4)}';
      }
    }
    return phone;
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    final notesController = TextEditingController();
    String selectedStatus = 'pending';
    String selectedInterest = 'none';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Customer Call', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone *', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company Name', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: _statusOptions.where((s) => s['value'] != 'all').map((status) {
                  return DropdownMenuItem(value: status['value'], child: Text(status['label']!));
                }).toList(),
                onChanged: (val) => selectedStatus = val!,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedInterest,
                decoration: const InputDecoration(labelText: 'Interest', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Not Decided')),
                  DropdownMenuItem(value: 'loan', child: Text('Loan')),
                  DropdownMenuItem(value: 'gst', child: Text('GST Service')),
                  DropdownMenuItem(value: 'msme', child: Text('MSME Service')),
                  DropdownMenuItem(value: 'itr', child: Text('Income Tax Filing')),
                ],
                onChanged: (val) => selectedInterest = val!,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone is required')),
                );
                return;
              }

              try {
                await ApiService.post('/capital/customers/', {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'email': emailController.text.isEmpty ? null : emailController.text,
                  'company_name': companyController.text,
                  'call_status': selectedStatus,
                  'interest': selectedInterest,
                  'notes': notesController.text,
                });

                Navigator.pop(context);
                _loadCustomers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add customer: $e')),
                );
              }
            },
            child: const Text('Add', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    final nameController = TextEditingController(text: customer['name'] ?? '');
    final phoneController = TextEditingController(text: customer['phone'] ?? '');
    final emailController = TextEditingController(text: customer['email'] ?? '');
    final companyController = TextEditingController(text: customer['company_name'] ?? '');
    final notesController = TextEditingController(text: customer['notes'] ?? '');
    String selectedStatus = customer['call_status'] ?? 'pending';
    String selectedInterest = customer['interest'] ?? 'none';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Customer', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone *', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company Name', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: _statusOptions.where((s) => s['value'] != 'all').map((status) {
                  return DropdownMenuItem(value: status['value'], child: Text(status['label']!));
                }).toList(),
                onChanged: (val) => selectedStatus = val!,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedInterest,
                decoration: const InputDecoration(labelText: 'Interest', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12, color: Colors.black),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Not Decided')),
                  DropdownMenuItem(value: 'loan', child: Text('Loan')),
                  DropdownMenuItem(value: 'gst', child: Text('GST Service')),
                  DropdownMenuItem(value: 'msme', child: Text('MSME Service')),
                  DropdownMenuItem(value: 'itr', child: Text('Income Tax Filing')),
                ],
                onChanged: (val) => selectedInterest = val!,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone is required')),
                );
                return;
              }

              try {
                await ApiService.request(
                  endpoint: '/capital/customers/${customer['id']}/',
                  method: 'PATCH',
                  body: {
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'email': emailController.text.isEmpty ? null : emailController.text,
                    'company_name': companyController.text,
                    'call_status': selectedStatus,
                    'interest': selectedInterest,
                    'notes': notesController.text,
                  },
                );

                Navigator.pop(context);
                _loadCustomers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update customer: $e')),
                );
              }
            },
            child: const Text('Update', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer', style: TextStyle(fontSize: 16)),
        content: Text('Are you sure you want to delete ${customer['name'] ?? 'this customer'}?', style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.delete('/capital/customers/${customer['id']}/');
                Navigator.pop(context);
                _loadCustomers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer deleted successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete customer: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers (Calls)', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        onSubmitted: (_) => _filterCustomers(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _filterCustomers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: const Text('Search', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 11, color: Colors.black),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(value: status['value'], child: Text(status['label']!));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value!);
                          _filterCustomers();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? const Center(child: Text('No customers found', style: TextStyle(fontSize: 12)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final createdById = customer['created_by'];
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer['name'] ?? 'Unknown',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(customer['call_status'] ?? ''),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      customer['call_status'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 9),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Phone: ${_maskPhone(customer['phone'] ?? '', createdById)}', style: const TextStyle(fontSize: 11)),
                                  if (customer['email'] != null && customer['email'].toString().isNotEmpty)
                                    Text('Email: ${customer['email']}', style: const TextStyle(fontSize: 11)),
                                  if (customer['company_name'] != null && customer['company_name'].toString().isNotEmpty)
                                    Text('Company: ${customer['company_name']}', style: const TextStyle(fontSize: 11)),
                                  if (customer['interest'] != null && customer['interest'] != 'none')
                                    Text('Interest: ${customer['interest']}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                  Text('Created: ${_formatDate(customer['created_at'])}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(fontSize: 12))),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 12))),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditCustomerDialog(customer);
                                  } else if (value == 'delete') {
                                    _deleteCustomer(customer);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_currentPage - 1) * _pageSize + 1}-${(_currentPage * _pageSize > _totalCount) ? _totalCount : _currentPage * _pageSize} of $_totalCount',
                  style: const TextStyle(fontSize: 10),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: _currentPage > 1 ? _previousPage : null,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text('$_currentPage/$_totalPages', style: const TextStyle(fontSize: 10)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: _currentPage < _totalPages ? _nextPage : null,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: const Color(0xFF1565C0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
