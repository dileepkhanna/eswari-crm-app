import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class EswariProjectsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isManager;
  const EswariProjectsTab({super.key, required this.userData, required this.isManager});

  @override
  State<EswariProjectsTab> createState() => _EswariProjectsTabState();
}

class _EswariProjectsTabState extends State<EswariProjectsTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _projects = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Filters
  String _statusFilter = '';
  String _typeFilter = '';
  String _locationFilter = '';
  
  // View mode
  String _viewMode = 'grid'; // 'grid' or 'list'

  static const Color _primary = Color(0xFF1565C0);

  final _statusColors = const {
    'pre_launch':          Color(0xFF1976D2),
    'launch':              Color(0xFFF57C00),
    'under_construction':  Color(0xFF7B1FA2),
    'mid_stage':           Color(0xFF388E3C),
    'ready_to_go':         Color(0xFF2E7D32),
  };

  final _statusLabels = const {
    'pre_launch':          'Pre Launch',
    'launch':              'Launch',
    'under_construction':  'Under Construction',
    'mid_stage':           'Mid Stage',
    'ready_to_go':         'Ready to Go',
  };
  
  final _typeLabels = const {
    'villa':     'Villa',
    'apartment': 'Apartment',
    'plots':     'Plots',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    setState(() => _loading = true);
    try {
      String url = '/projects/';
      
      // Apply filters
      final params = <String>[];
      if (_statusFilter.isNotEmpty) params.add('status=$_statusFilter');
      if (_search.isNotEmpty) params.add('search=$_search');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final res = await ApiService.get(url);
      
      if (mounted) {
        var projects = res['data'];
        
        // Handle both paginated and non-paginated responses
        if (projects is Map && projects.containsKey('results')) {
          projects = projects['results'];
        }
        
        // Debug: Print first project to see image URL format
        if (projects != null && projects.isNotEmpty) {
          print('=== PROJECT API RESPONSE DEBUG ===');
          print('First project: ${projects[0]}');
          print('Cover Image: ${projects[0]['coverImage']}');
          print('Cover Image (legacy): ${projects[0]['cover_image']}');
          print('Base URL: ${ApiConfig.baseUrl}');
          print('==================================');
        }
        
        // Apply client-side filters
        List<dynamic> filteredProjects = List<dynamic>.from(projects ?? []);
        
        if (_typeFilter.isNotEmpty) {
          filteredProjects = filteredProjects.where((p) => p['type'] == _typeFilter).toList();
        }
        
        if (_locationFilter.isNotEmpty) {
          filteredProjects = filteredProjects.where((p) {
            final location = (p['location'] ?? '').toString().toLowerCase();
            return location.contains(_locationFilter.toLowerCase());
          }).toList();
        }
        
        setState(() {
          _projects = filteredProjects;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error fetching projects: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = '';
      _typeFilter = '';
      _locationFilter = '';
      _search = '';
      _searchCtrl.clear();
    });
    _fetchProjects();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _projects.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _fetchProjects,
                      color: _primary,
                      child: _viewMode == 'grid'
                          ? _buildGridView()
                          : _buildListView(),
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // Search bar with view toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                              _fetchProjects();
                            })
                        : null,
                    filled: true,
                    fillColor: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) {
                    setState(() => _search = v);
                    if (v.isEmpty) _fetchProjects();
                  },
                  onSubmitted: (_) => _fetchProjects(),
                ),
              ),
              const SizedBox(width: 8),
              // View mode toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        color: _viewMode == 'grid' ? _primary : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _viewMode = 'grid'),
                      tooltip: 'Grid View',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.view_list_rounded,
                        color: _viewMode == 'list' ? _primary : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _viewMode = 'list'),
                      tooltip: 'List View',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'All Status',
                  _statusFilter,
                  [
                    {'value': '', 'label': 'All Status'},
                    {'value': 'pre_launch', 'label': 'Pre Launch'},
                    {'value': 'launch', 'label': 'Launch'},
                    {'value': 'under_construction', 'label': 'Under Construction'},
                    {'value': 'mid_stage', 'label': 'Mid Stage'},
                    {'value': 'ready_to_go', 'label': 'Ready to Go'},
                  ],
                  (value) {
                    setState(() => _statusFilter = value ?? '');
                    _fetchProjects();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  'All Types',
                  _typeFilter,
                  [
                    {'value': '', 'label': 'All Types'},
                    {'value': 'apartment', 'label': 'Apartment'},
                    {'value': 'villa', 'label': 'Villa'},
                    {'value': 'plots', 'label': 'Plots'},
                  ],
                  (value) {
                    setState(() => _typeFilter = value ?? '');
                    _fetchProjects();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  'All Locations',
                  _locationFilter,
                  [
                    {'value': '', 'label': 'All Locations'},
                    {'value': 'Vizag', 'label': 'Vizag'},
                    {'value': 'Gajuwaka', 'label': 'Gajuwaka'},
                    {'value': 'Kakinada', 'label': 'Kakinada'},
                    {'value': 'Rajamundry', 'label': 'Rajamundry'},
                    {'value': 'Vijayawada', 'label': 'Vijayawada'},
                  ],
                  (value) {
                    setState(() => _locationFilter = value ?? '');
                    _fetchProjects();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String hint,
    String value,
    List<Map<String, String>> items,
    Function(String?) onChanged,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Text(hint, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surface,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['value'],
              child: Text(
                item['label']!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _projects.length,
      itemBuilder: (_, i) => _buildProjectCard(_projects[i]),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _projects.length,
      itemBuilder: (_, i) => _buildProjectListItem(_projects[i]),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final status = project['status'] ?? 'pre_launch';
    final statusColor = _statusColors[status] ?? _primary;
    final name = project['name'] ?? 'Unknown Project';
    final location = project['location'] ?? '';
    final type = project['type'] ?? 'apartment';
    final priceMin = double.tryParse(project['priceMin']?.toString() ?? '0') ?? 0.0;
    final priceMax = double.tryParse(project['priceMax']?.toString() ?? '0') ?? 0.0;
    final coverImage = project['coverImage'] ?? project['cover_image'] ?? '';
    
    // Build full image URL - matching web logic
    String imageUrl = 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800'; // Default
    
    if (coverImage.isNotEmpty) {
      if (coverImage.startsWith('http://') || coverImage.startsWith('https://')) {
        // Full URL - use as-is
        imageUrl = coverImage;
      } else if (coverImage.startsWith('/media/')) {
        // Relative path starting with /media/ - remove /api from base URL
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
        imageUrl = '$baseUrlWithoutApi$coverImage';
      } else if (coverImage.startsWith('/')) {
        // Other relative path starting with /
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
        imageUrl = '$baseUrlWithoutApi$coverImage';
      } else {
        // Path without leading slash
        final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
        imageUrl = '$baseUrlWithoutApi/media/$coverImage';
      }
      // Debug: Print the constructed URL
      print('Project: $name | Cover Image Path: $coverImage | Constructed URL: $imageUrl');
    }

    return GestureDetector(
      onTap: () => _showProjectDetail(project),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Center(
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 48,
                      color: statusColor.withOpacity(0.5),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 48,
                      color: statusColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 11, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.3 : 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _typeLabels[type] ?? type,
                        style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const Spacer(),
                    if (priceMin > 0 && priceMax > 0)
                      Text(
                        _formatPriceRange(priceMin, priceMax),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabels[status] ?? status,
                        style: TextStyle(
                          fontSize: 9,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectListItem(Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final status = project['status'] ?? 'pre_launch';
    final statusColor = _statusColors[status] ?? _primary;
    final name = project['name'] ?? 'Unknown Project';
    final location = project['location'] ?? '';
    final type = project['type'] ?? 'apartment';
    final priceMin = double.tryParse(project['priceMin']?.toString() ?? '0') ?? 0.0;
    final priceMax = double.tryParse(project['priceMax']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.apartment_rounded, color: statusColor, size: 22),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.3 : 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _typeLabels[type] ?? type,
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (priceMin > 0 && priceMax > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatPriceRange(priceMin, priceMax),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabels[status] ?? status,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => _showProjectDetail(project),
      ),
    );
  }

  String _formatPriceRange(double min, double max) {
    String formatValue(double val) {
      if (val >= 10000000) return '₹${(val / 10000000).toStringAsFixed(1)} Cr';
      if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(0)} L';
      if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(0)}K';
      return '₹${val.toStringAsFixed(0)}';
    }
    return '${formatValue(min)} - ${formatValue(max)}';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No projects found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Projects will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showProjectDetail(Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProjectDetailSheet(project: project),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Project Detail Sheet Widget
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectDetailSheet extends StatelessWidget {
  final Map<String, dynamic> project;

  const _ProjectDetailSheet({required this.project});

  String _getImageUrl(String imagePath) {
    if (imagePath.isEmpty) {
      return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800';
    }
    
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Full URL - use as-is
      return imagePath;
    } else if (imagePath.startsWith('/media/')) {
      final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
      return '$baseUrlWithoutApi$imagePath';
    } else if (imagePath.startsWith('/')) {
      final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
      return '$baseUrlWithoutApi$imagePath';
    } else {
      final baseUrlWithoutApi = ApiConfig.baseUrl.replaceAll('/api', '');
      return '$baseUrlWithoutApi/media/$imagePath';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = project['name'] ?? 'Unknown Project';
    final location = project['location'] ?? '';
    final type = project['type'] ?? 'apartment';
    final status = project['status'] ?? 'pre_launch';
    final description = project['description'] ?? '';
    
    final priceMin = double.tryParse(project['priceMin']?.toString() ?? '0') ?? 0.0;
    final priceMax = double.tryParse(project['priceMax']?.toString() ?? '0') ?? 0.0;
    
    final launchDate = project['launchDate'];
    final possessionDate = project['possessionDate'];
    
    final towerDetails = project['towerDetails'] ?? '';
    final amenities = project['amenities'] as List? ?? [];
    final nearbyLandmarks = project['nearbyLandmarks'] as List? ?? [];
    
    final coverImage = project['coverImage'] ?? project['cover_image'] ?? '';
    final blueprintImage = project['blueprintImage'] ?? project['blueprint_image'] ?? '';
    
    final createdAt = project['created_at'];
    final updatedAt = project['updated_at'];

    const statusColors = {
      'pre_launch':          Color(0xFF1976D2),
      'launch':              Color(0xFFF57C00),
      'under_construction':  Color(0xFF7B1FA2),
      'mid_stage':           Color(0xFF388E3C),
      'ready_to_go':         Color(0xFF2E7D32),
    };
    
    const statusLabels = {
      'pre_launch':          'Pre Launch',
      'launch':              'Launch',
      'under_construction':  'Under Construction',
      'mid_stage':           'Mid Stage',
      'ready_to_go':         'Ready to Go',
    };
    
    const typeLabels = {
      'villa':     'Villa',
      'apartment': 'Apartment',
      'plots':     'Plots',
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (statusColors[status] ?? Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabels[status] ?? status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColors[status] ?? Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  // Cover Image - Always show (use default if not available)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _getImageUrl(coverImage),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Basic Information
                  _buildSection(
                    'Basic Information',
                    Icons.info_outline_rounded,
                    [
                      _buildInfoRow(Icons.category_rounded, 'Type', typeLabels[type] ?? type),
                      if (priceMin > 0 && priceMax > 0)
                        _buildInfoRow(Icons.attach_money_rounded, 'Price Range', _formatPriceRange(priceMin, priceMax)),
                    ],
                  ),
                  
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Description',
                      Icons.description_rounded,
                      [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              description,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Dates
                  _buildSection(
                    'Important Dates',
                    Icons.calendar_today_rounded,
                    [
                      if (launchDate != null && launchDate.toString().isNotEmpty)
                        _buildInfoRow(Icons.rocket_launch_rounded, 'Launch Date', launchDate.toString().split('T')[0]),
                      if (possessionDate != null && possessionDate.toString().isNotEmpty)
                        _buildInfoRow(Icons.key_rounded, 'Possession Date', possessionDate.toString().split('T')[0]),
                    ],
                  ),
                  
                  if (towerDetails.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Tower Details',
                      Icons.apartment_rounded,
                      [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              towerDetails,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Amenities',
                      Icons.star_rounded,
                      [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: amenities.map((amenity) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                              ),
                              child: Text(
                                amenity.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  if (nearbyLandmarks.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Nearby Landmarks',
                      Icons.place_rounded,
                      [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: nearbyLandmarks.map((landmark) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      landmark.toString(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Blueprint Image
                  if (blueprintImage.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Blueprint',
                      Icons.architecture_rounded,
                      [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: _getImageUrl(blueprintImage),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.error)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Timeline
                  _buildSection(
                    'Timeline',
                    Icons.schedule_rounded,
                    [
                      _buildInfoRow(Icons.add_circle_outline_rounded, 'Created', createdAt?.toString().split('T')[0] ?? ''),
                      _buildInfoRow(Icons.update_rounded, 'Last Updated', updatedAt?.toString().split('T')[0] ?? ''),
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
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

  String _formatPriceRange(double min, double max) {
    String formatValue(double val) {
      if (val >= 10000000) return '₹${(val / 10000000).toStringAsFixed(1)} Cr';
      if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(0)} L';
      if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(0)}K';
      return '₹${val.toStringAsFixed(0)}';
    }
    return '${formatValue(min)} - ${formatValue(max)}';
  }
}
