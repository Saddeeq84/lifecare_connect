// ignore_for_file: prefer_const_constructors, deprecated_member_use, use_build_context_synchronously, prefer_const_literals_to_create_immutables, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/models/training_material.dart';
import '../../../shared/data/services/training_service.dart';

class AdminTrainingScreen extends StatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  State<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends State<AdminTrainingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<TrainingMaterial> _allMaterials = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadTrainingMaterials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTrainingMaterials() {
    setState(() {
      _isLoading = true;
    });

    TrainingService.getTrainingMaterials().listen(
      (snapshot) {
        final materials = snapshot.docs
            .map((doc) => TrainingMaterial.fromFirestore(doc))
            .toList();
        setState(() {
          _allMaterials = materials;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading materials: $error')),
          );
        }
      },
    );
  }

  List<TrainingMaterial> _getMaterialsByStatus(String status) {
    return _allMaterials
        .where((material) => material.status == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Training Materials Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin_dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'All Materials'),
            Tab(text: 'Draft'),
            Tab(text: 'Published'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsList(_allMaterials, 'All Materials'),
                _buildMaterialsList(
                  _getMaterialsByStatus('draft'),
                  'Draft Materials',
                ),
                _buildMaterialsList(
                  _getMaterialsByStatus('published'),
                  'Published Materials',
                ),
                _buildStatisticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMaterialDialog(),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Add Material'),
      ),
    );
  }

  Widget _buildMaterialsList(List<TrainingMaterial> materials, String title) {
    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No $title Found',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first training material',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
        return _buildMaterialCard(materials[index]);
      },
    );
  }

  Widget _buildMaterialCard(TrainingMaterial material) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditMaterialDialog(material);
                        break;
                      case 'publish':
                        _publishMaterial(material);
                        break;
                      case 'archive':
                        _archiveMaterial(material);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(material);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (material.status == 'draft')
                      PopupMenuItem(value: 'publish', child: Text('Publish')),
                    if (material.status == 'published')
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(material.status),
                _buildInfoChip(material.typeDisplayText, Colors.blue),
                _buildInfoChip(material.categoryDisplayText, Colors.green),
                _buildInfoChip(material.difficultyDisplayText, Colors.orange),
                _buildInfoChip(material.formattedDuration, Colors.purple),
                if (material.isRequired) _buildInfoChip('Required', Colors.red),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.visibility, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${material.viewCount} views'),
                SizedBox(width: 16),
                Icon(Icons.download, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('${material.downloadCount} downloads'),
                if (material.averageRating != null) ...[
                  SizedBox(width: 16),
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    '${material.averageRating!.toStringAsFixed(1)} (${material.ratingCount})',
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Target Roles: ${material.targetRoles.join(', ')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'published':
        color = Colors.green;
        break;
      case 'draft':
        color = Colors.orange;
        break;
      case 'archived':
        color = Colors.grey;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
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

  Widget _buildStatisticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: TrainingService.getTrainingStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading statistics'));
        }

        final stats = snapshot.data ?? {};

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                'Total Materials',
                stats['totalMaterials']?.toString() ?? '0',
                Icons.school,
              ),
              SizedBox(height: 16),
              _buildStatCard(
                'Published Materials',
                stats['publishedMaterials']?.toString() ?? '0',
                Icons.publish,
              ),
              SizedBox(height: 16),
              _buildStatCard(
                'Total Users',
                stats['totalUsers']?.toString() ?? '0',
                Icons.people,
              ),
              SizedBox(height: 16),
              _buildStatCard(
                'Total Completions',
                stats['totalCompletions']?.toString() ?? '0',
                Icons.check_circle,
              ),
              SizedBox(height: 16),
              _buildStatCard(
                'Avg Completion Rate',
                '${stats['averageCompletionRate']?.toStringAsFixed(1) ?? '0'}%',
                Icons.trending_up,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.teal),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    value,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMaterialDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateMaterialDialog(
        onMaterialCreated: () => _loadTrainingMaterials(),
      ),
    );
  }

  void _showEditMaterialDialog(TrainingMaterial material) {
    showDialog(
      context: context,
      builder: (context) => CreateMaterialDialog(
        material: material,
        onMaterialCreated: () => _loadTrainingMaterials(),
      ),
    );
  }

  Future<void> _publishMaterial(TrainingMaterial material) async {
    if (_currentUserId == null) return;

    try {
      await TrainingService.publishTrainingMaterial(
        materialId: material.id,
        publishedBy: _currentUserId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material published successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _archiveMaterial(TrainingMaterial material) async {
    if (_currentUserId == null) return;

    try {
      await TrainingService.archiveTrainingMaterial(
        materialId: material.id,
        archivedBy: _currentUserId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material archived successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(TrainingMaterial material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Material'),
        content: Text(
          'Are you sure you want to delete "${material.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMaterial(material);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(TrainingMaterial material) async {
    try {
      await TrainingService.deleteTrainingMaterial(material.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class CreateMaterialDialog extends StatefulWidget {
  final TrainingMaterial? material;
  final VoidCallback onMaterialCreated;

  const CreateMaterialDialog({
    super.key,
    this.material,
    required this.onMaterialCreated,
  });

  @override
  State<CreateMaterialDialog> createState() => _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends State<CreateMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedType = 'article';
  String _selectedCategory = 'general-health';
  String _selectedDifficulty = 'beginner';
  String _selectedLanguage = 'en';
  List<String> _selectedRoles = ['chw'];
  bool _isRequired = false;
  File? _selectedFile;
  String? _fileUrl;
  bool _isUploading = false;

  final List<String> _types = [
    'article',
    'video',
    'pdf',
    'interactive',
    'quiz',
  ];
  final List<String> _categories = [
    'general-health',
    'maternal-health',
    'child-health',
    'emergency-care',
    'nutrition',
  ];
  final List<String> _difficulties = ['beginner', 'intermediate', 'advanced'];

  final List<String> _roles = ['chw', 'patient', 'doctor', 'facility'];

  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      final material = widget.material!;
      _titleController.text = material.title;
      _descriptionController.text = material.description;
      _contentController.text = material.content ?? '';
      _tagsController.text = material.tags.join(', ');
      _durationController.text = material.estimatedDurationMinutes.toString();
      _selectedType = material.type;
      _selectedCategory = material.category;
      _selectedDifficulty = material.difficulty;
      _selectedLanguage = material.language;
      _selectedRoles = List.from(material.targetRoles);
      _isRequired = material.isRequired;
      _fileUrl = material.fileUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.material != null;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              isEditing ? 'Edit Training Material' : 'Create Training Material',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      if (_selectedType == 'article') ...[
                        TextFormField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            labelText: 'Content',
                            border: OutlineInputBorder(),
                            hintText: 'Enter the article content...',
                          ),
                          maxLines: 8,
                        ),
                        SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                              ),
                              items: _types
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type
                                            .split('-')
                                            .map(
                                              (word) =>
                                                  word[0].toUpperCase() +
                                                  word.substring(1),
                                            )
                                            .join(' '),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category
                                            .split('-')
                                            .map(
                                              (word) =>
                                                  word[0].toUpperCase() +
                                                  word.substring(1),
                                            )
                                            .join(' '),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDifficulty,
                              decoration: InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder(),
                              ),
                              items: _difficulties
                                  .map(
                                    (difficulty) => DropdownMenuItem(
                                      value: difficulty,
                                      child: Text(
                                        difficulty[0].toUpperCase() +
                                            difficulty.substring(1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDifficulty = value!;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              decoration: InputDecoration(
                                labelText: 'Duration (minutes)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Duration is required';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          hintText: 'pregnancy, nutrition, health',
                        ),
                      ),
                      SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Roles:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _roles
                                .map(
                                  (role) => FilterChip(
                                    label: Text(role.toUpperCase()),
                                    selected: _selectedRoles.contains(role),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedRoles.add(role);
                                        } else {
                                          _selectedRoles.remove(role);
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      CheckboxListTile(
                        title: Text('Required Training'),
                        subtitle: Text(
                          'Mark as required training for selected roles',
                        ),
                        value: _isRequired,
                        onChanged: (value) {
                          setState(() {
                            _isRequired = value ?? false;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      if (_selectedType != 'article') ...[
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'File Upload',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                if (_selectedFile != null)
                                  Text(
                                    'Selected: ${_selectedFile!.path.split('/').last}',
                                  )
                                else if (_fileUrl != null)
                                  Text(
                                    'Current file: ${_fileUrl!.split('/').last}',
                                  ),
                                SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(Icons.upload_file),
                                  label: Text(
                                    _selectedFile != null || _fileUrl != null
                                        ? 'Change File'
                                        : 'Select File',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isUploading ? null : _saveMaterial,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: _isUploading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Update' : 'Create',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'mp4',
          'mov',
          'avi',
          'doc',
          'docx',
          'ppt',
          'pptx',
        ],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
    }
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one target role')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      String? fileUrl = _fileUrl;

      // Upload file if selected
      if (_selectedFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.path.split('/').last}';
        fileUrl = await TrainingService.uploadFile(
          file: _selectedFile!,
          fileName: fileName,
          type: _selectedType,
        );
      }

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      final duration = int.parse(_durationController.text);

      if (widget.material != null) {
        // Update existing material
        await TrainingService.updateTrainingMaterial(
          materialId: widget.material!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          content: _selectedType == 'article'
              ? _contentController.text.trim()
              : null,
          fileUrl: fileUrl,
          type: _selectedType,
          category: _selectedCategory,
          targetRoles: _selectedRoles,
          difficulty: _selectedDifficulty,
          estimatedDurationMinutes: duration,
          tags: tags,
          language: _selectedLanguage,
          updatedBy: currentUserId,
          isRequired: _isRequired,
        );
      } else {
        // Create new material
        await TrainingService.createTrainingMaterial(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          content: _selectedType == 'article'
              ? _contentController.text.trim()
              : null,
          fileUrl: fileUrl,
          type: _selectedType,
          category: _selectedCategory,
          targetRoles: _selectedRoles,
          difficulty: _selectedDifficulty,
          estimatedDurationMinutes: duration,
          tags: tags,
          language: _selectedLanguage,
          createdBy: currentUserId,
          isRequired: _isRequired,
        );
      }

      widget.onMaterialCreated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Training material ${widget.material != null ? 'updated' : 'created'} successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save material: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
