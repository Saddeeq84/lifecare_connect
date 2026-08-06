// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'admin_weekly_assignments_screen.dart';

class AdminCHWCourseDetailEditorScreen extends StatefulWidget {
  final String? courseId; // null for new course

  const AdminCHWCourseDetailEditorScreen({super.key, this.courseId});

  @override
  State<AdminCHWCourseDetailEditorScreen> createState() =>
      _AdminCHWCourseDetailEditorScreenState();
}

class _AdminCHWCourseDetailEditorScreenState
    extends State<AdminCHWCourseDetailEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _outlineController = TextEditingController();
  final _durationController = TextEditingController();
  final _certificateFeeController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCourseVisible = true;
  bool _isUploadingSignature = false;
  String _selectedCategory = 'maternal_health';
  String _selectedRole = 'chw';
  String? _certificateSignatureUrl;
  List<Map<String, dynamic>> _modules = [];
  final Set<String> _loadedSlideIds = {};

  String _normalizeCategory(String category) {
    if (category == 'community_health_prevention' ||
        category == 'public_health') {
      return 'public_health';
    }
    return category;
  }

  static const List<String> categories = [
    'maternal_health',
    'child_health',
    'nutrition',
    'disease_management',
    'public_health',
    'communication',
    'other',
  ];

  static const List<String> roles = ['chw', 'doctor', 'patient', 'all'];

  @override
  void initState() {
    super.initState();
    if (widget.courseId != null) {
      _loadCourseData();
    } else {
      _durationController.text = '0';
      _certificateFeeController.text = '1000';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _outlineController.dispose();
    _durationController.dispose();
    _certificateFeeController.dispose();
    super.dispose();
  }

  void _loadCourseData() async {
    setState(() => _isLoading = true);
    try {
      // Load course data
      final courseDoc = await _firestore
          .collection('courses')
          .doc(widget.courseId)
          .get();

      if (courseDoc.exists) {
        final data = courseDoc.data()!;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _outlineController.text = data['courseOutline'] ?? '';
        _selectedCategory = _normalizeCategory(
          data['category'] ?? 'maternal_health',
        );
        _selectedRole = data['targetRole'] ?? 'chw';
        _certificateSignatureUrl = data['certificateSignatureUrl'];
        _certificateFeeController.text = _formatEditableAmount(
          data['certificateFee'] ?? 1000,
        );
        _isCourseVisible = (data['status'] ?? 'active') == 'active';
        _durationController.text =
            (data['durationWeeks'] ??
                    _weeksFromMinutes(data['estimatedDurationMinutes']))
                .toString();

        // Load slides and group them into modules and lessons.
        final slidesQuery = await _firestore
            .collection('courseSlides')
            .where('courseId', isEqualTo: widget.courseId)
            .get();

        final slides = slidesQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _loadedSlideIds
          ..clear()
          ..addAll(slides.map((slide) => slide['id'].toString()));
        _modules = _buildModulesFromSlides(slides);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading course: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading Course...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courseId == null ? 'Create New Course' : 'Edit Course',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (widget.courseId != null)
            IconButton(
              tooltip: 'Weekly Assignments',
              icon: const Icon(Icons.assignment_turned_in),
              onPressed: _openWeeklyAssignments,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Info Section
            Text(
              'Course Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Course Title',
                border: OutlineInputBorder(),
                hintText: 'e.g., Basic First Aid',
              ),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              value: _isCourseVisible,
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to learners'),
              subtitle: Text(
                _isCourseVisible
                    ? 'Learners can find and take this course'
                    : 'This course is hidden from learners',
              ),
              activeColor: Colors.teal,
              onChanged: (value) {
                setState(() => _isCourseVisible = value);
              },
            ),
            SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Course Description',
                border: OutlineInputBorder(),
                hintText: 'Describe what this course covers',
              ),
              maxLines: 3,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _outlineController,
              decoration: InputDecoration(
                labelText: 'Course Outline',
                border: OutlineInputBorder(),
                hintText: 'Briefly outline the topics covered in this course',
              ),
              maxLines: 4,
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Course Category',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(_formatCategoryName(category)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Target Audience',
                border: OutlineInputBorder(),
              ),
              items: roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_formatRoleName(role)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedRole = value);
                }
              },
            ),
            SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Course Duration (weeks)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _certificateFeeController,
              decoration: InputDecoration(
                labelText: 'Certificate Cost (₦)',
                border: OutlineInputBorder(),
                hintText: 'Amount learners pay only when downloading',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 12),
            _buildCertificateSignatureSection(),
            SizedBox(height: 30),

            // Modules Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Course Modules (${_modules.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addModule,
                  icon: Icon(Icons.add),
                  label: Text('Add Module'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_modules.isEmpty)
              Center(child: Text('No modules yet. Add your first module!'))
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _modules.length,
                onReorder: _reorderModules,
                itemBuilder: (context, moduleIndex) => KeyedSubtree(
                  key: ValueKey(_modules[moduleIndex]['id']),
                  child: _buildModuleCard(moduleIndex),
                ),
              ),
            SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.courseId == null
                            ? 'Create Course'
                            : 'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openWeeklyAssignments() {
    final courseId = widget.courseId;
    if (courseId == null) return;

    final title = _titleController.text.trim().isEmpty
        ? 'Course'
        : _titleController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminWeeklyAssignmentsScreen(
          courseId: courseId,
          courseTitle: title,
        ),
      ),
    );
  }

  Widget _buildModuleCard(int moduleIndex) {
    final module = _modules[moduleIndex];
    final lessons = module['lessons'] as List<dynamic>;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withValues(alpha: 0.1),
          foregroundColor: Colors.teal,
          child: Text('${moduleIndex + 1}'),
        ),
        title: Text(module['title'] ?? 'Module ${moduleIndex + 1}'),
        subtitle: Text(
          '${lessons.length} lessons • ${_countModuleSlides(module)} slides',
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => _renameModule(moduleIndex),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Rename Module'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => _addLesson(moduleIndex),
              child: Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 8),
                  Text('Add Lesson'),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => _editAssignment(moduleIndex),
              child: Row(
                children: [
                  Icon(Icons.assignment, size: 18),
                  SizedBox(width: 8),
                  Text(
                    module['assignment'] == null
                        ? 'Add Assignment'
                        : 'Edit Assignment',
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: () => setState(() => _modules.removeAt(moduleIndex)),
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Module', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        children: [
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No lessons yet. Add a lesson to this module.'),
            )
          else
            ReorderableListView.builder(
              key: ValueKey('module_${module['id']}_lessons'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lessons.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorderLessons(moduleIndex, oldIndex, newIndex),
              itemBuilder: (context, lessonIndex) => KeyedSubtree(
                key: ValueKey(lessons[lessonIndex]['id']),
                child: _buildLessonCard(moduleIndex, lessonIndex),
              ),
            ),
          _buildAssignmentCard(moduleIndex),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addLesson(moduleIndex),
                icon: Icon(Icons.add),
                label: Text('Add Lesson'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(int moduleIndex, int lessonIndex) {
    final lesson = _modules[moduleIndex]['lessons'][lessonIndex];
    final slides = lesson['slides'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            lesson['title'] ?? 'Lesson ${moduleIndex + 1}.${lessonIndex + 1}',
          ),
          subtitle: Text('${slides.length} slides'),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _renameLesson(moduleIndex, lessonIndex),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Rename Lesson'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => _addSlide(moduleIndex, lessonIndex),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('Add Slide'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () {
                  setState(() {
                    _modules[moduleIndex]['lessons'].removeAt(lessonIndex);
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Lesson', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          children: [
            if (slides.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No slides yet. Add the first slide.'),
              )
            else
              ReorderableListView.builder(
                key: ValueKey(
                  'module_${moduleIndex}_lesson_${lesson['id']}_slides',
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slides.length,
                onReorder: (oldIndex, newIndex) => _reorderSlides(
                  moduleIndex,
                  lessonIndex,
                  oldIndex,
                  newIndex,
                ),
                itemBuilder: (context, slideIndex) {
                  final slide = slides[slideIndex] as Map<String, dynamic>;
                  return ListTile(
                    key: ValueKey(
                      slide['id'] ??
                          '${moduleIndex}_${lessonIndex}_${slideIndex}_${slide['title']}',
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      foregroundColor: Colors.teal,
                      child: Text('${slideIndex + 1}'),
                    ),
                    title: Text(slide['title'] ?? 'Untitled Slide'),
                    subtitle: Text(slide['type'] ?? 'content'),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: () =>
                              _editSlide(moduleIndex, lessonIndex, slideIndex),
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () {
                            setState(() {
                              _modules[moduleIndex]['lessons'][lessonIndex]['slides']
                                  .removeAt(slideIndex);
                            });
                          },
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () =>
                        _editSlide(moduleIndex, lessonIndex, slideIndex),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addSlide(moduleIndex, lessonIndex),
                  icon: Icon(Icons.add),
                  label: Text('Add Slide'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateSignatureSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certificate E-Signature',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_certificateSignatureUrl != null &&
              _certificateSignatureUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                _certificateSignatureUrl!,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Signature preview unavailable',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            Text(
              'No signature uploaded yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isUploadingSignature ? null : _uploadSignature,
                icon: _isUploadingSignature
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _certificateSignatureUrl == null
                      ? 'Upload Signature'
                      : 'Replace Signature',
                ),
              ),
              if (_certificateSignatureUrl != null)
                TextButton.icon(
                  onPressed: _isUploadingSignature
                      ? null
                      : () => _setCertificateSignatureUrl(null),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(int moduleIndex) {
    final module = _modules[moduleIndex];
    final assignment = module['assignment'] as Map<String, dynamic>?;
    if (assignment == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _editAssignment(moduleIndex),
            icon: const Icon(Icons.assignment),
            label: const Text('Add Weekly Assignment'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        elevation: 0,
        color: Colors.teal.withValues(alpha: 0.06),
        child: ListTile(
          leading: const Icon(Icons.assignment, color: Colors.teal),
          title: Text(assignment['title'] ?? 'Weekly Assignment'),
          subtitle: Text(
            assignment['assignmentQuestion'] ??
                assignment['content'] ??
                'No question added',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _editAssignment(moduleIndex),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () {
                  setState(() => module.remove('assignment'));
                },
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          onTap: () => _editAssignment(moduleIndex),
        ),
      ),
    );
  }

  void _reorderModules(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _modules.removeAt(oldIndex);
      _modules.insert(newIndex, item);
    });
  }

  void _reorderLessons(int moduleIndex, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final lessons = _modules[moduleIndex]['lessons'] as List<dynamic>;
      final item = lessons.removeAt(oldIndex);
      lessons.insert(newIndex, item);
    });
  }

  void _reorderSlides(
    int moduleIndex,
    int lessonIndex,
    int oldIndex,
    int newIndex,
  ) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final slides =
          _modules[moduleIndex]['lessons'][lessonIndex]['slides']
              as List<dynamic>;
      final item = slides.removeAt(oldIndex);
      slides.insert(newIndex, item);
    });
  }

  void _addModule() {
    final moduleIndex = _modules.length;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _modules.add({
        'id': 'module_$timestamp',
        'title': 'Module ${moduleIndex + 1}',
        'description': '',
        'lessons': [
          {
            'id': 'lesson_$timestamp',
            'title': 'Lesson ${moduleIndex + 1}.1',
            'slides': <Map<String, dynamic>>[],
          },
        ],
      });
    });
  }

  void _addLesson(int moduleIndex) {
    final lessons = _modules[moduleIndex]['lessons'] as List<dynamic>;
    setState(() {
      lessons.add({
        'id': 'lesson_${DateTime.now().millisecondsSinceEpoch}',
        'title': 'Lesson ${moduleIndex + 1}.${lessons.length + 1}',
        'slides': <Map<String, dynamic>>[],
      });
    });
  }

  void _addSlide(int moduleIndex, int lessonIndex) {
    final slides =
        _modules[moduleIndex]['lessons'][lessonIndex]['slides']
            as List<dynamic>;
    final newSlide = {
      'title': 'New Slide',
      'type': 'content',
      'orderIndex': slides.length,
      'contentByLanguage': {'en': ''},
      'estimatedDurationMinutes': 5,
    };

    setState(() => slides.add(newSlide));
  }

  void _editSlide(int moduleIndex, int lessonIndex, int slideIndex) {
    final slides =
        _modules[moduleIndex]['lessons'][lessonIndex]['slides']
            as List<dynamic>;
    showDialog(
      context: context,
      builder: (context) => SlideEditorDialog(
        slide: Map<String, dynamic>.from(slides[slideIndex] as Map),
        onSave: (updatedSlide) {
          setState(() => slides[slideIndex] = updatedSlide);
        },
        storage: _storage,
        firestore: _firestore,
      ),
    );
  }

  void _editAssignment(int moduleIndex) {
    final module = _modules[moduleIndex];
    final assignment = Map<String, dynamic>.from(
      (module['assignment'] as Map<String, dynamic>?) ??
          {
            'type': 'assignment',
            'title': 'Weekly Assignment',
            'assignmentQuestion': '',
            'content': '',
            'assignmentMinWords': 50,
            'estimatedDurationMinutes': 0,
          },
    );

    showDialog(
      context: context,
      builder: (context) => AssignmentEditorDialog(
        assignment: assignment,
        onSave: (updatedAssignment) {
          setState(() => module['assignment'] = updatedAssignment);
        },
      ),
    );
  }

  Future<void> _uploadSignature() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read selected signature file.'),
        ),
      );
      return;
    }

    setState(() => _isUploadingSignature = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.extension ?? 'png';
      final storageRef = _storage.ref().child(
        'course_signatures/$timestamp.$extension',
      );
      await storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: _getImageContentType(extension),
          cacheControl: 'public, max-age=31536000',
        ),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      if (!mounted) return;
      await _setCertificateSignatureUrl(downloadUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signature uploaded successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signature upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingSignature = false);
      }
    }
  }

  Future<void> _setCertificateSignatureUrl(String? url) async {
    setState(() => _certificateSignatureUrl = url);
    final courseId = widget.courseId;
    if (courseId == null) return;

    await _firestore.collection('courses').doc(courseId).set({
      'certificateSignatureUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _getImageContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'png':
      default:
        return 'image/png';
    }
  }

  void _renameModule(int moduleIndex) {
    _showNameDialog(
      title: 'Rename Module',
      initialValue: _modules[moduleIndex]['title'] ?? '',
      onSave: (value) => setState(() => _modules[moduleIndex]['title'] = value),
    );
  }

  void _renameLesson(int moduleIndex, int lessonIndex) {
    _showNameDialog(
      title: 'Rename Lesson',
      initialValue:
          _modules[moduleIndex]['lessons'][lessonIndex]['title'] ?? '',
      onSave: (value) {
        setState(() {
          _modules[moduleIndex]['lessons'][lessonIndex]['title'] = value;
        });
      },
    );
  }

  void _showNameDialog({
    required String title,
    required String initialValue,
    required void Function(String value) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              onSave(value);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveCourse() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a course title')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final flattenedSlides = _flattenSlides();
      final courseData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseOutline': _outlineController.text.trim().isEmpty
            ? _buildOutlineFromSlides()
            : _outlineController.text.trim(),
        'category': _selectedCategory,
        'targetRole': _selectedRole,
        'status': _isCourseVisible ? 'active' : 'archived',
        'totalModules': _modules.length,
        'totalLessons': flattenedSlides.length,
        'totalCourseLessons': _countLessons(),
        'totalSlides': flattenedSlides.length,
        'durationWeeks': int.tryParse(_durationController.text) ?? 0,
        'estimatedDurationMinutes':
            (int.tryParse(_durationController.text) ?? 0) * 10080,
        'availableLanguages': ['en'],
        'certificateSignatureUrl': _certificateSignatureUrl,
        'certificateFee': double.tryParse(_certificateFeeController.text) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String courseId = widget.courseId ?? '';

      if (widget.courseId == null) {
        // Create new course
        courseData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await _firestore.collection('courses').add(courseData);
        courseId = docRef.id;
      } else {
        // Update existing course
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .update(courseData);
      }

      // Save slides
      final retainedSlideIds = <String>{};
      for (int i = 0; i < flattenedSlides.length; i++) {
        final slide = Map<String, dynamic>.from(flattenedSlides[i]);
        final slideId = slide.remove('id');
        slide['courseId'] = courseId;
        slide['orderIndex'] = i;

        if (slideId != null) {
          // Update existing slide
          await _firestore
              .collection('courseSlides')
              .doc(slideId)
              .update(slide);
          retainedSlideIds.add(slideId.toString());
        } else {
          // Create new slide
          final docRef = await _firestore.collection('courseSlides').add(slide);
          flattenedSlides[i]['id'] = docRef.id;
          retainedSlideIds.add(docRef.id);
        }
      }

      final removedSlideIds = _loadedSlideIds.difference(retainedSlideIds);
      for (final removedSlideId in removedSlideIds) {
        await _firestore
            .collection('courseSlides')
            .doc(removedSlideId)
            .delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.courseId == null
                ? 'Course created successfully!'
                : 'Course updated successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving course: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatCategoryName(String category) {
    if (category == 'community_health_prevention' ||
        category == 'public_health') {
      return 'Public Health';
    }
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _buildOutlineFromSlides() {
    if (_modules.isEmpty) return '';
    return _modules
        .asMap()
        .entries
        .map((moduleEntry) {
          final module = moduleEntry.value;
          final lessons = module['lessons'] as List<dynamic>;
          final lessonTitles = lessons
              .asMap()
              .entries
              .map((lessonEntry) {
                final lesson = lessonEntry.value as Map<String, dynamic>;
                return '  Lesson ${moduleEntry.key + 1}.${lessonEntry.key + 1}: ${lesson['title'] ?? 'Untitled Lesson'}';
              })
              .join('\n');
          return 'Module ${moduleEntry.key + 1}: ${module['title'] ?? 'Untitled Module'}\n$lessonTitles';
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _buildModulesFromSlides(
    List<Map<String, dynamic>> slides,
  ) {
    if (slides.isEmpty) return [];

    slides.sort((a, b) {
      final moduleCompare = ((a['moduleOrderIndex'] ?? 0) as int).compareTo(
        (b['moduleOrderIndex'] ?? 0) as int,
      );
      if (moduleCompare != 0) return moduleCompare;
      final lessonCompare = ((a['lessonOrderIndex'] ?? 0) as int).compareTo(
        (b['lessonOrderIndex'] ?? 0) as int,
      );
      if (lessonCompare != 0) return lessonCompare;
      return ((a['orderIndex'] ?? 0) as int).compareTo(
        (b['orderIndex'] ?? 0) as int,
      );
    });

    final modulesById = <String, Map<String, dynamic>>{};
    for (final slide in slides) {
      final moduleId = (slide['moduleId'] ?? 'module_1').toString();
      final lessonId = (slide['lessonId'] ?? 'lesson_1_1').toString();
      final isAssignment = slide['type'] == 'assignment';

      final module = modulesById.putIfAbsent(moduleId, () {
        return {
          'id': moduleId,
          'title': slide['moduleTitle'] ?? 'Module 1',
          'description': '',
          'orderIndex': slide['moduleOrderIndex'] ?? modulesById.length,
          'lessons': <Map<String, dynamic>>[],
        };
      });

      if (isAssignment) {
        module['assignment'] = slide;
        continue;
      }

      final lessons = module['lessons'] as List<Map<String, dynamic>>;
      var lesson = lessons.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == lessonId,
        orElse: () => null,
      );

      if (lesson == null) {
        lesson = {
          'id': lessonId,
          'title': slide['lessonTitle'] ?? 'Lesson 1.1',
          'orderIndex': slide['lessonOrderIndex'] ?? lessons.length,
          'slides': <Map<String, dynamic>>[],
        };
        lessons.add(lesson);
      }

      (lesson['slides'] as List<Map<String, dynamic>>).add(slide);
    }

    final modules = modulesById.values.toList()
      ..sort(
        (a, b) => ((a['orderIndex'] ?? 0) as int).compareTo(
          (b['orderIndex'] ?? 0) as int,
        ),
      );
    for (final module in modules) {
      final lessons = module['lessons'] as List<Map<String, dynamic>>;
      lessons.sort(
        (a, b) => ((a['orderIndex'] ?? 0) as int).compareTo(
          (b['orderIndex'] ?? 0) as int,
        ),
      );
    }
    return modules;
  }

  List<Map<String, dynamic>> _flattenSlides() {
    final slides = <Map<String, dynamic>>[];
    for (var moduleIndex = 0; moduleIndex < _modules.length; moduleIndex++) {
      final module = _modules[moduleIndex];
      final moduleId = (module['id'] ?? 'module_${moduleIndex + 1}').toString();
      final moduleTitle = (module['title'] ?? 'Module ${moduleIndex + 1}')
          .toString();
      final lessons = module['lessons'] as List<dynamic>;

      for (var lessonIndex = 0; lessonIndex < lessons.length; lessonIndex++) {
        final lesson = lessons[lessonIndex] as Map<String, dynamic>;
        final lessonId =
            (lesson['id'] ?? 'lesson_${moduleIndex + 1}_${lessonIndex + 1}')
                .toString();
        final lessonTitle =
            (lesson['title'] ?? 'Lesson ${moduleIndex + 1}.${lessonIndex + 1}')
                .toString();
        final lessonSlides = lesson['slides'] as List<dynamic>;

        for (
          var slideIndex = 0;
          slideIndex < lessonSlides.length;
          slideIndex++
        ) {
          final slide = Map<String, dynamic>.from(
            lessonSlides[slideIndex] as Map,
          );
          slide['moduleId'] = moduleId;
          slide['moduleTitle'] = moduleTitle;
          slide['moduleOrderIndex'] = moduleIndex;
          slide['lessonId'] = lessonId;
          slide['lessonTitle'] = lessonTitle;
          slide['lessonOrderIndex'] = lessonIndex;
          slide['orderIndex'] = slides.length;
          slide['lessonSlideIndex'] = slideIndex;
          slides.add(slide);
        }
      }

      final assignment = module['assignment'] as Map<String, dynamic>?;
      if (assignment != null) {
        final slide = Map<String, dynamic>.from(assignment);
        slide['type'] = 'assignment';
        slide['title'] = slide['title'] ?? 'Weekly Assignment';
        slide['description'] = slide['description'] ?? '';
        slide['moduleId'] = moduleId;
        slide['moduleTitle'] = moduleTitle;
        slide['moduleOrderIndex'] = moduleIndex;
        slide['lessonId'] = '${moduleId}_assignment';
        slide['lessonTitle'] = 'Weekly Assignment';
        slide['lessonOrderIndex'] = lessons.length;
        slide['orderIndex'] = slides.length;
        slide['lessonSlideIndex'] = 0;
        slides.add(slide);
      }
    }
    return slides;
  }

  int _countLessons() {
    return _modules.fold<int>(
      0,
      (sum, module) =>
          sum + ((module['lessons'] as List<dynamic>?)?.length ?? 0),
    );
  }

  int _countModuleSlides(Map<String, dynamic> module) {
    final lessons = module['lessons'] as List<dynamic>? ?? [];
    final lessonSlides = lessons.fold<int>(
      0,
      (sum, lesson) =>
          sum +
          (((lesson as Map<String, dynamic>)['slides'] as List?)?.length ?? 0),
    );
    return lessonSlides + (module['assignment'] == null ? 0 : 1);
  }

  int _weeksFromMinutes(dynamic minutesValue) {
    final minutes = minutesValue is num ? minutesValue.toInt() : 0;
    if (minutes <= 0) return 0;
    return (minutes / 10080).ceil();
  }

  String _formatEditableAmount(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'chw':
        return 'Community Health Worker';
      case 'doctor':
        return 'Doctor';
      case 'patient':
        return 'Patient';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }
}

class AssignmentEditorDialog extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Function(Map<String, dynamic>) onSave;

  const AssignmentEditorDialog({
    super.key,
    required this.assignment,
    required this.onSave,
  });

  @override
  State<AssignmentEditorDialog> createState() => _AssignmentEditorDialogState();
}

class _AssignmentEditorDialogState extends State<AssignmentEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _questionController;
  late TextEditingController _minWordsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.assignment['title'] ?? 'Weekly Assignment',
    );
    _questionController = TextEditingController(
      text:
          widget.assignment['assignmentQuestion'] ??
          widget.assignment['content'] ??
          '',
    );
    _minWordsController = TextEditingController(
      text: (widget.assignment['assignmentMinWords'] ?? 50).toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _minWordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weekly Assignment'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Assignment Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Assignment Question',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minWordsController,
              decoration: const InputDecoration(
                labelText: 'Minimum Words',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final question = _questionController.text.trim();
            if (question.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter an assignment question.'),
                ),
              );
              return;
            }
            final minWords =
                int.tryParse(_minWordsController.text.trim()) ?? 50;
            if (minWords < 50) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Minimum words should be at least 50.'),
                ),
              );
              return;
            }

            final updatedAssignment = Map<String, dynamic>.from(
              widget.assignment,
            );
            updatedAssignment['type'] = 'assignment';
            updatedAssignment['title'] = _titleController.text.trim().isEmpty
                ? 'Weekly Assignment'
                : _titleController.text.trim();
            updatedAssignment['assignmentQuestion'] = question;
            updatedAssignment['assignmentMinWords'] = minWords;
            updatedAssignment['content'] = question;
            updatedAssignment['description'] = 'Weekly Assignment';
            updatedAssignment['questions'] = <Map<String, dynamic>>[];
            widget.onSave(updatedAssignment);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class SlideEditorDialog extends StatefulWidget {
  final Map<String, dynamic> slide;
  final Function(Map<String, dynamic>) onSave;
  final FirebaseStorage storage;
  final FirebaseFirestore firestore;

  const SlideEditorDialog({
    super.key,
    required this.slide,
    required this.onSave,
    required this.storage,
    required this.firestore,
  });

  @override
  State<SlideEditorDialog> createState() => _SlideEditorDialogState();
}

class _SlideEditorDialogState extends State<SlideEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _contentController;
  late TextEditingController _durationController;
  String _selectedType = 'content';
  String? _mediaPath;
  String _interactionMediaType = 'none';
  List<Map<String, dynamic>> _questions = [];

  static const List<String> slideTypes = [
    'content',
    'quiz',
    'video',
    'image',
    'interaction',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.slide['title'] ?? '');
    _descriptionController = TextEditingController(
      text: widget.slide['description'] ?? '',
    );
    _contentController = TextEditingController(
      text:
          (widget.slide['contentByLanguage']?['en'] ??
          widget.slide['content'] ??
          ''),
    );
    _durationController = TextEditingController(
      text: (widget.slide['estimatedDurationMinutes'] ?? 5).toString(),
    );
    _selectedType = widget.slide['type'] ?? 'content';
    _mediaPath = widget.slide['videoUrl'] ?? widget.slide['imageUrl'];
    if (widget.slide['videoUrl'] != null &&
        widget.slide['videoUrl'].toString().isNotEmpty) {
      _interactionMediaType = 'video';
    } else if (widget.slide['imageUrl'] != null &&
        widget.slide['imageUrl'].toString().isNotEmpty) {
      _interactionMediaType = 'image';
    } else {
      _interactionMediaType = 'none';
    }

    final questionsData = widget.slide['questions'] as List<dynamic>? ?? [];
    _questions = questionsData.map((item) {
      final question = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final options = List<String>.from(
        question['options'] ?? ['Option 1', 'Option 2'],
      );
      final correctAnswer = question['correctAnswer']?.toString();
      return {
        'id': question['id'] ?? UniqueKey().toString(),
        'questionText': question['questionText'] ?? '',
        'questionType': question['questionType'] ?? 'multiple_choice',
        'options': options,
        'correctAnswer': options.contains(correctAnswer)
            ? correctAnswer
            : options.first,
        'points': question['points'] ?? 1,
      };
    }).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'id': UniqueKey().toString(),
        'questionText': '',
        'questionType': 'multiple_choice',
        'options': ['Option 1', 'Option 2'],
        'correctAnswer': 'Option 1',
        'points': 1,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _addOption(int questionIndex) {
    setState(() {
      final options = _questions[questionIndex]['options'] as List<String>;
      options.add('Option ${options.length + 1}');
      if (!_questions[questionIndex]['options'].contains(
        _questions[questionIndex]['correctAnswer'],
      )) {
        _questions[questionIndex]['correctAnswer'] = options.first;
      }
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    setState(() {
      final options = _questions[questionIndex]['options'] as List<String>;
      if (options.length <= 2) return;
      final removed = options.removeAt(optionIndex);
      if (_questions[questionIndex]['correctAnswer'] == removed) {
        _questions[questionIndex]['correctAnswer'] = options.first;
      }
    });
  }

  bool _validateQuizQuestions() {
    if (_questions.isEmpty) return false;
    for (final question in _questions) {
      if ((question['questionText'] as String).trim().isEmpty) return false;
      final options = List<String>.from(question['options'] as List<dynamic>);
      if (options.length < 2) return false;
      if (!(options.contains(question['correctAnswer']))) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            AppBar(
              title: const Text('Edit Slide'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Slide Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Slide Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Slide Type',
                        border: OutlineInputBorder(),
                      ),
                      items: slideTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                            if (value != 'video' && value != 'image') {
                              _mediaPath = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedType == 'quiz')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Quiz Questions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _addQuestion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Add Question'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_questions.isEmpty)
                            const Text(
                              'Add at least one question to make this a quiz slide.',
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _questions.length,
                              itemBuilder: (context, questionIndex) {
                                final question = _questions[questionIndex];
                                final options = List<String>.from(
                                  question['options'] as List<dynamic>,
                                );
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Question ${questionIndex + 1}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _removeQuestion(
                                                questionIndex,
                                              ),
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Question Text',
                                            border: OutlineInputBorder(),
                                          ),
                                          maxLines: 2,
                                          initialValue:
                                              question['questionText'],
                                          onChanged: (value) {
                                            _questions[questionIndex]['questionText'] =
                                                value;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Options',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...options.asMap().entries.map((entry) {
                                          final optionIndex = entry.key;
                                          final option = entry.value;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          'Option ${optionIndex + 1}',
                                                      border:
                                                          const OutlineInputBorder(),
                                                    ),
                                                    initialValue: option,
                                                    onChanged: (value) {
                                                      _questions[questionIndex]['options'][optionIndex] =
                                                          value;
                                                      if (_questions[questionIndex]['correctAnswer'] ==
                                                          option) {
                                                        _questions[questionIndex]['correctAnswer'] =
                                                            value;
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (options.length > 2)
                                                  IconButton(
                                                    onPressed: () =>
                                                        _removeOption(
                                                          questionIndex,
                                                          optionIndex,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.remove_circle,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }),
                                        Row(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _addOption(questionIndex),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Add Option'),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value:
                                                    question['correctAnswer'],
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Correct Answer',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                items: options.map((option) {
                                                  return DropdownMenuItem(
                                                    value: option,
                                                    child: Text(option),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(() {
                                                      _questions[questionIndex]['correctAnswer'] =
                                                          value;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Points',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                keyboardType:
                                                    TextInputType.number,
                                                initialValue: question['points']
                                                    .toString(),
                                                onChanged: (value) {
                                                  final points =
                                                      int.tryParse(value) ?? 1;
                                                  _questions[questionIndex]['points'] =
                                                      points;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      )
                    else if (_selectedType == 'interaction')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _contentController,
                            decoration: const InputDecoration(
                              labelText: 'Interaction Prompt',
                              border: OutlineInputBorder(),
                              hintText: 'Ask the learner a question or prompt',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _interactionMediaType,
                            decoration: const InputDecoration(
                              labelText: 'Optional media',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'none',
                                child: Text('No media'),
                              ),
                              DropdownMenuItem(
                                value: 'image',
                                child: Text('Image'),
                              ),
                              DropdownMenuItem(
                                value: 'video',
                                child: Text('Video'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _interactionMediaType = value;
                                  if (value == 'none') {
                                    _mediaPath = null;
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_interactionMediaType != 'none')
                            ElevatedButton.icon(
                              onPressed: _pickMedia,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                'Upload ${_interactionMediaType == 'video' ? 'Video' : 'Image'}',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Learners will be able to type an answer and submit it for AI feedback.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      )
                    else if (_selectedType == 'video' ||
                        _selectedType == 'image')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: TextEditingController(
                              text: _mediaPath ?? '',
                            ),
                            decoration: InputDecoration(
                              labelText: _selectedType == 'video'
                                  ? 'Video URL or File'
                                  : 'Image URL or File',
                              border: const OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickMedia,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(
                                    'Upload ${_selectedType == 'video' ? 'Video' : 'Image'}',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      )
                    else
                      Column(
                        children: [
                          TextField(
                            controller: _contentController,
                            decoration: const InputDecoration(
                              labelText: 'Slide Content (English)',
                              border: OutlineInputBorder(),
                              hintText: 'Enter the content for this slide',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedType == 'quiz' &&
                          !_validateQuizQuestions()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please complete all quiz questions, options, and correct answers.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final updatedSlide = widget.slide;
                      updatedSlide['title'] = _titleController.text;
                      updatedSlide['description'] = _descriptionController.text;
                      updatedSlide['type'] = _selectedType;
                      updatedSlide['content'] = _contentController.text;
                      updatedSlide['contentByLanguage'] = {
                        'en': _contentController.text,
                      };
                      updatedSlide['estimatedDurationMinutes'] =
                          int.tryParse(_durationController.text) ?? 5;
                      updatedSlide['questions'] = _selectedType == 'quiz'
                          ? _questions
                          : <Map<String, dynamic>>[];
                      if (_selectedType == 'video') {
                        updatedSlide['videoUrl'] = _mediaPath;
                        updatedSlide['imageUrl'] = null;
                      } else if (_selectedType == 'image') {
                        updatedSlide['imageUrl'] = _mediaPath;
                        updatedSlide['videoUrl'] = null;
                      } else if (_selectedType == 'interaction') {
                        if (_interactionMediaType == 'video') {
                          updatedSlide['videoUrl'] = _mediaPath;
                          updatedSlide['imageUrl'] = null;
                        } else if (_interactionMediaType == 'image') {
                          updatedSlide['imageUrl'] = _mediaPath;
                          updatedSlide['videoUrl'] = null;
                        } else {
                          updatedSlide['videoUrl'] = null;
                          updatedSlide['imageUrl'] = null;
                        }
                      } else {
                        updatedSlide['videoUrl'] = null;
                        updatedSlide['imageUrl'] = null;
                      }
                      if (_selectedType == 'interaction') {
                        updatedSlide['interactionPrompt'] =
                            _contentController.text;
                        updatedSlide['content'] = _contentController.text;
                        updatedSlide['contentByLanguage'] = {
                          'en': _contentController.text,
                        };
                      }

                      widget.onSave(updatedSlide);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia() async {
    final mediaType = _selectedType == 'interaction'
        ? (_interactionMediaType == 'video' ? FileType.video : FileType.image)
        : (_selectedType == 'video' ? FileType.video : FileType.image);
    final result = await FilePicker.platform.pickFiles(
      type: mediaType,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      try {
        final file = result.files.first;

        if (!mounted) return;
        // Show uploading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Uploading Media'),
            content: const LinearProgressIndicator(),
          ),
        );

        // Upload to Firebase Storage using putData (cross-platform compatible)
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = 'course_media/$timestamp.${file.extension}';
        final storageRef = widget.storage.ref().child(filePath);

        final uploadTask = storageRef.putData(
          file.bytes!,
          SettableMetadata(
            contentType: _getContentType(file.extension ?? ''),
            cacheControl: 'public, max-age=31536000',
          ),
        );

        await uploadTask;

        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();

        // Close uploading dialog
        if (mounted) {
          Navigator.pop(context);

          setState(() {
            _mediaPath = downloadUrl;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Close uploading dialog
        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error uploading media: $e')));
        }
      }
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return 'video/mp4';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
