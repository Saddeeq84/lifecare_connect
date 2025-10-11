// ignore_for_file: prefer_const_constructors, deprecated_member_use, prefer_const_literals_to_create_immutables, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/models/training_material.dart';
import '../../../shared/data/services/training_service.dart';

class TrainingMaterialsScreen extends StatefulWidget {
  final String userRole;

  const TrainingMaterialsScreen({super.key, required this.userRole});

  @override
  State<TrainingMaterialsScreen> createState() =>
      _TrainingMaterialsScreenState();
}

class _TrainingMaterialsScreenState extends State<TrainingMaterialsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<TrainingMaterial> _allMaterials = [];
  List<TrainingMaterial> _requiredMaterials = [];
  List<UserProgress> _userProgress = [];
  bool _isLoading = true;
  String? _currentUserId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadTrainingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTrainingData() {
    setState(() {
      _isLoading = true;
    });

    // Load published materials for user role
    TrainingService.getPublishedTrainingMaterials(
      userRole: widget.userRole,
    ).listen((snapshot) {
      final materials = snapshot.docs
          .map((doc) => TrainingMaterial.fromFirestore(doc))
          .toList();
      setState(() {
        _allMaterials = materials;
      });
      _checkLoadingComplete();
    });

    // Load required materials
    TrainingService.getRequiredTrainingMaterials(
      userRole: widget.userRole,
    ).listen((snapshot) {
      final materials = snapshot.docs
          .map((doc) => TrainingMaterial.fromFirestore(doc))
          .toList();
      setState(() {
        _requiredMaterials = materials;
      });
      _checkLoadingComplete();
    });

    // Load user progress
    if (_currentUserId != null) {
      TrainingService.getUserProgress(userId: _currentUserId!).listen((
        snapshot,
      ) {
        final progress = snapshot.docs
            .map((doc) => UserProgress.fromFirestore(doc))
            .toList();
        setState(() {
          _userProgress = progress;
        });
        _checkLoadingComplete();
      });
    }
  }

  void _checkLoadingComplete() {
    if (_allMaterials.isNotEmpty || _requiredMaterials.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<TrainingMaterial> get _filteredMaterials {
    if (_searchQuery.isEmpty) return _allMaterials;
    return _allMaterials
        .where(
          (material) =>
              material.title.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              material.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              material.tags.any(
                (tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()),
              ),
        )
        .toList();
  }

  List<TrainingMaterial> _getMaterialsByCategory(String category) {
    return _filteredMaterials
        .where((material) => material.category == category)
        .toList();
  }

  UserProgress? _getProgressForMaterial(String materialId) {
    try {
      return _userProgress.firstWhere(
        (progress) => progress.materialId == materialId,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Training Materials'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search training materials...',
                    prefixIcon: Icon(Icons.search),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: true,
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'Required'),
                  Tab(text: 'My Progress'),
                  Tab(text: 'Categories'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsList(
                  _filteredMaterials,
                  'No training materials found',
                ),
                _buildMaterialsList(
                  _requiredMaterials,
                  'No required training materials',
                ),
                _buildProgressView(),
                _buildCategoriesView(),
              ],
            ),
    );
  }

  Widget _buildMaterialsList(
    List<TrainingMaterial> materials,
    String emptyMessage,
  ) {
    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: materials.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final material = materials[index];
        final progress = _getProgressForMaterial(material.id);
        return _buildMaterialCard(material, progress);
      },
    );
  }

  Widget _buildMaterialCard(TrainingMaterial material, UserProgress? progress) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openMaterial(material),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getTypeColor(material.type),
                    child: Icon(
                      _getTypeIcon(material.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          material.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (material.isRequired)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'REQUIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),
              if (progress != null) ...[
                LinearProgressIndicator(
                  value: progress.progressPercentage / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.isCompleted ? Colors.green : Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      progress.isCompleted
                          ? Icons.check_circle
                          : Icons.schedule,
                      size: 16,
                      color: progress.isCompleted
                          ? Colors.green
                          : Colors.orange,
                    ),
                    SizedBox(width: 4),
                    Text(
                      progress.isCompleted
                          ? 'Completed'
                          : '${progress.progressPercentage.toInt()}% completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: progress.isCompleted
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(material.categoryDisplayText, Colors.green),
                  _buildInfoChip(material.difficultyDisplayText, Colors.orange),
                  _buildInfoChip(material.formattedDuration, Colors.purple),
                  if (material.averageRating != null)
                    _buildRatingChip(
                      material.averageRating!,
                      material.ratingCount!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRatingChip(double rating, int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 12, color: Colors.amber),
          SizedBox(width: 2),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.amber[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    final completedProgress = _userProgress
        .where((p) => p.isCompleted)
        .toList();
    final inProgressProgress = _userProgress
        .where((p) => p.isInProgress)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressSection('Completed', completedProgress, Colors.green),
          SizedBox(height: 24),
          _buildProgressSection(
            'In Progress',
            inProgressProgress,
            Colors.orange,
          ),
          SizedBox(height: 24),
          _buildProgressStats(),
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    String title,
    List<UserProgress> progressList,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${progressList.length})',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 12),
        if (progressList.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('No materials in this category'),
          )
        else
          ...progressList.map((progress) {
            final material = _allMaterials.firstWhere(
              (m) => m.id == progress.materialId,
              orElse: () => TrainingMaterial(
                id: progress.materialId,
                title: 'Unknown Material',
                description: '',
                type: 'article',
                category: 'general-health',
                targetRoles: [],
                difficulty: 'beginner',
                estimatedDurationMinutes: 0,
                tags: [],
                status: 'published',
                version: 1,
                language: 'en',
                createdAt: DateTime.now(),
                createdBy: '',
                downloadCount: 0,
                viewCount: 0,
                isRequired: false,
              ),
            );
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _buildMaterialCard(material, progress),
            );
          }),
      ],
    );
  }

  Widget _buildProgressStats() {
    final totalMaterials = _allMaterials.length;
    final completedCount = _userProgress.where((p) => p.isCompleted).length;
    final inProgressCount = _userProgress.where((p) => p.isInProgress).length;
    final completionRate = totalMaterials > 0
        ? (completedCount / totalMaterials * 100)
        : 0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Materials',
                    totalMaterials.toString(),
                    Icons.school,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Completed',
                    completedCount.toString(),
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'In Progress',
                    inProgressCount.toString(),
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Completion Rate',
                    '${completionRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.teal),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCategoriesView() {
    final categories = [
      'general-health',
      'maternal-health',
      'child-health',
      'emergency-care',
      'nutrition',
    ];

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final category = categories[index];
        final materials = _getMaterialsByCategory(category);
        return _buildCategoryCard(category, materials);
      },
    );
  }

  Widget _buildCategoryCard(String category, List<TrainingMaterial> materials) {
    final displayName = category
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return Card(
      child: InkWell(
        onTap: () {
          // Navigate to category-specific view
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryMaterialsScreen(
                category: category,
                materials: materials,
                userRole: widget.userRole,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _getCategoryColor(category),
                child: Icon(_getCategoryIcon(category), color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${materials.length} materials available',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Colors.red;
      case 'pdf':
        return Colors.blue;
      case 'article':
        return Colors.green;
      case 'interactive':
        return Colors.purple;
      case 'quiz':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.play_arrow;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'article':
        return Icons.article;
      case 'interactive':
        return Icons.touch_app;
      case 'quiz':
        return Icons.quiz;
      default:
        return Icons.help;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'maternal-health':
        return Colors.pink;
      case 'child-health':
        return Colors.lightBlue;
      case 'general-health':
        return Colors.green;
      case 'emergency-care':
        return Colors.red;
      case 'nutrition':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'maternal-health':
        return Icons.pregnant_woman;
      case 'child-health':
        return Icons.child_care;
      case 'general-health':
        return Icons.health_and_safety;
      case 'emergency-care':
        return Icons.emergency;
      case 'nutrition':
        return Icons.restaurant;
      default:
        return Icons.help;
    }
  }

  void _openMaterial(TrainingMaterial material) {
    // Track view
    TrainingService.incrementViewCount(material.id);

    // Navigate to material detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MaterialDetailScreen(material: material, userRole: widget.userRole),
      ),
    );
  }
}

// Placeholder screens for navigation
class CategoryMaterialsScreen extends StatelessWidget {
  final String category;
  final List<TrainingMaterial> materials;
  final String userRole;

  const CategoryMaterialsScreen({
    super.key,
    required this.category,
    required this.materials,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category
              .split('-')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' '),
        ),
      ),
      body: ListView.builder(
        itemCount: materials.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(materials[index].title),
            subtitle: Text(materials[index].description),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaterialDetailScreen(
                    material: materials[index],
                    userRole: userRole,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MaterialDetailScreen extends StatelessWidget {
  final TrainingMaterial material;
  final String userRole;

  const MaterialDetailScreen({
    super.key,
    required this.material,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(material.title)),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              material.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(material.description),
            SizedBox(height: 16),
            if (material.content != null) ...[
              Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(child: Text(material.content!)),
              ),
            ] else if (material.fileUrl != null) ...[
              Text('File-based training material'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Handle file opening/downloading
                  TrainingService.incrementDownloadCount(material.id);
                },
                child: Text('Download/Open File'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
