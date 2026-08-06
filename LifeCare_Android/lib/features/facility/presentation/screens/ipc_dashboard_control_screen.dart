import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/environmental_health_questionnaire.dart';
import '../models/hai_questionnaire.dart';
import '../models/ward_denominator_questionnaire.dart';
import '../models/water_quality_questionnaire.dart';

class IpcDashboardControlScreen extends StatelessWidget {
  final String facilityName;
  final String? facilityId;

  const IpcDashboardControlScreen({
    super.key,
    required this.facilityName,
    this.facilityId,
  });

  static const tabLabels = <String, String>{
    'hai_surveillance': 'HAI Surveillance',
    'hand_hygiene': 'Hand Hygiene',
    'outbreak_investigation': 'Outbreak Investigation',
    'environmental_surveillance': 'Environmental Surveillance',
    'ward_denominator': 'Ward Denominator',
    'ipc_assessment_tools': 'IPC Assessment tools',
    'surveillance_data': 'Surveillance Data',
  };

  String get _collection =>
      '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

  Query<Map<String, dynamic>> get _customFormsQuery => FirebaseFirestore
      .instance
      .collection('ipc_custom_forms')
      .where('facilityName', isEqualTo: facilityName)
      .where('isActive', isEqualTo: true);

  String get _facilityKey => facilityName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  String get _facilityTemplateKey {
    final idKey = (facilityId ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return idKey.isNotEmpty ? idKey : _facilityKey;
  }

  DocumentReference<Map<String, dynamic>> _builtInTemplateRef(String id) =>
      FirebaseFirestore.instance
          .collection('ipc_form_templates')
          .doc('${_facilityTemplateKey}_$id');

  DocumentReference<Map<String, dynamic>> _legacyBuiltInTemplateRef(
    String id,
  ) => FirebaseFirestore.instance
      .collection('ipc_form_templates')
      .doc('${_facilityKey}_$id');

  List<_BuiltInIpcFormTemplate> get _builtInTemplates => [
    _BuiltInIpcFormTemplate(
      id: 'hai_surveillance',
      title: 'HAI Surveillance',
      description:
          'Routine and targeted healthcare-associated infection surveillance form.',
      questions: _haiTemplateQuestions(),
    ),
    _BuiltInIpcFormTemplate(
      id: 'environmental_health_surveillance',
      title: 'Environmental Health Surveillance',
      description:
          'General environmental health and waste management assessment form.',
      questions: _environmentalHealthTemplateQuestions(),
    ),
    _BuiltInIpcFormTemplate(
      id: 'water_quality_surveillance',
      title: 'Water Quality Surveillance',
      description:
          'Water sample information, IPC assessment, laboratory result, and corrective action form.',
      questions: _waterQualityTemplateQuestions(),
    ),
    _BuiltInIpcFormTemplate(
      id: 'ward_denominator',
      title: 'Ward Denominator',
      description: 'Daily ward denominator form with monthly discharge entry.',
      questions: _wardDenominatorTemplateQuestions(),
    ),
  ];

  Future<Map<String, dynamic>> _loadBuiltInTemplate(
    _BuiltInIpcFormTemplate template,
  ) async {
    final snapshot = await _builtInTemplateRef(
      template.id,
    ).get(const GetOptions(source: Source.server));
    if (snapshot.exists && snapshot.data() != null) {
      return _mergeBuiltInTemplateDefaults(template, snapshot.data()!);
    }
    final legacySnapshot = await _legacyBuiltInTemplateRef(
      template.id,
    ).get(const GetOptions(source: Source.server));
    if (legacySnapshot.exists && legacySnapshot.data() != null) {
      return _mergeBuiltInTemplateDefaults(template, legacySnapshot.data()!);
    }
    return template.toFirestore(
      facilityName: facilityName,
      facilityId: facilityId,
    );
  }

  Map<String, dynamic> _mergeBuiltInTemplateDefaults(
    _BuiltInIpcFormTemplate template,
    Map<String, dynamic> saved,
  ) {
    if (template.id != 'hai_surveillance') return saved;
    final savedQuestions = saved['questions'];
    if (savedQuestions is! List) return saved;
    final defaultsById = {
      for (final question in template.questions)
        '${question['stableName'] ?? question['id']}': question,
    };
    final mergedQuestions = savedQuestions.map((raw) {
      if (raw is! Map) return raw;
      final question = Map<String, dynamic>.from(raw);
      final stableName = '${question['stableName'] ?? question['id']}';
      final defaults = defaultsById[stableName];
      if (defaults == null) return question;
      if (defaults['metadata'] is Map) {
        question['metadata'] = Map<String, dynamic>.from(
          defaults['metadata'] as Map,
        );
      }
      if (stableName == 'Antimicrobials_001') {
        question['type'] = 'multiple_choice';
      }
      if (defaults['calculation'] is Map) {
        question
          ..['type'] = 'calculated'
          ..['relevant'] = defaults['relevant'] ?? question['relevant'] ?? ''
          ..['calculation'] = Map<String, dynamic>.from(
            defaults['calculation'] as Map,
          );
      }
      if (stableName == '_76_Sub_specy') {
        question
          ..['label'] = defaults['label']
          ..['type'] = defaults['type']
          ..['required'] = false
          ..['options'] = <String>[]
          ..['optionValues'] = <String, String>{}
          ..['relevant'] = defaults['relevant'] ?? '';
      }
      return question;
    }).toList();
    final mergedStableNames = mergedQuestions
        .whereType<Map>()
        .map((question) => '${question['stableName'] ?? question['id']}')
        .toSet();
    for (final question in template.questions) {
      final stableName = '${question['stableName'] ?? question['id']}';
      if (mergedStableNames.contains(stableName)) continue;
      if (stableName == '_76_Sub_specy') {
        mergedQuestions.add(Map<String, dynamic>.from(question));
      }
    }
    return {...saved, 'questions': mergedQuestions};
  }

  Future<void> _openBuiltInTemplateReuseDialog(
    BuildContext context,
    _BuiltInIpcFormTemplate template,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reuse ${template.title} template'),
        content: SizedBox(
          width: 620,
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('ipc_form_templates')
                .where('templateId', isEqualTo: template.id)
                .get(const GetOptions(source: Source.server)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Unable to load templates: ${snapshot.error}');
              }
              final templates =
                  (snapshot.data?.docs ?? [])
                      .where(
                        (doc) =>
                            '${doc.data()['facilityName'] ?? ''}' !=
                            facilityName,
                      )
                      .toList()
                    ..sort((a, b) {
                      final aFacility = '${a.data()['facilityName'] ?? ''}';
                      final bFacility = '${b.data()['facilityName'] ?? ''}';
                      return aFacility.compareTo(bFacility);
                    });
              if (templates.isEmpty) {
                return const Text(
                  'No reusable template has been saved by another facility yet.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = templates[index];
                    final data = doc.data();
                    final sourceFacility =
                        '${data['facilityName'] ?? 'Unknown facility'}';
                    final questionCount =
                        (data['questions'] as List<dynamic>? ?? []).length;
                    return ListTile(
                      leading: const Icon(Icons.content_copy_outlined),
                      title: Text('${data['title'] ?? template.title}'),
                      subtitle: Text(
                        '$sourceFacility - $questionCount questions',
                      ),
                      trailing: FilledButton(
                        onPressed: () async {
                          await _copyBuiltInTemplateFromSource(
                            context: dialogContext,
                            template: template,
                            sourceDoc: doc,
                          );
                        },
                        child: const Text('Use'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyBuiltInTemplateFromSource({
    required BuildContext context,
    required _BuiltInIpcFormTemplate template,
    required QueryDocumentSnapshot<Map<String, dynamic>> sourceDoc,
  }) async {
    final source = sourceDoc.data();
    final sourceFacility = '${source['facilityName'] ?? 'another facility'}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current template?'),
        content: Text(
          'Use the ${source['title'] ?? template.title} template from $sourceFacility for $facilityName? This replaces this facility template only. Existing submitted data will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use template'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final data = Map<String, dynamic>.from(source);
    data
      ..['facilityName'] = facilityName
      ..['facilityId'] = facilityId
      ..['templateId'] = template.id
      ..['formKind'] = 'built_in_surveillance_template'
      ..['lockedStableKeys'] = true
      ..['sourceFacilityName'] = sourceFacility
      ..['sourceTemplateDocId'] = sourceDoc.id
      ..['importedAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    data.remove('createdAt');
    await _builtInTemplateRef(
      template.id,
    ).set({...data, 'createdAt': FieldValue.serverTimestamp()});
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.title} template imported')),
      );
    }
  }

  Future<void> _openCustomFormReuseDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reuse custom surveillance form'),
        content: SizedBox(
          width: 620,
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('ipc_custom_forms')
                .where('isActive', isEqualTo: true)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Unable to load forms: ${snapshot.error}');
              }
              final forms =
                  (snapshot.data?.docs ?? [])
                      .where(
                        (doc) =>
                            '${doc.data()['facilityName'] ?? ''}' !=
                            facilityName,
                      )
                      .toList()
                    ..sort((a, b) {
                      final aTitle = '${a.data()['title'] ?? ''}';
                      final bTitle = '${b.data()['title'] ?? ''}';
                      return aTitle.compareTo(bTitle);
                    });
              if (forms.isEmpty) {
                return const Text(
                  'No reusable custom surveillance form has been saved by another facility yet.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: forms.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = forms[index];
                    final data = doc.data();
                    final questionCount =
                        (data['questions'] as List<dynamic>? ?? []).length;
                    return ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text('${data['title'] ?? 'Custom form'}'),
                      subtitle: Text(
                        '${data['facilityName'] ?? 'Unknown facility'} - $questionCount questions',
                      ),
                      trailing: FilledButton(
                        onPressed: () async {
                          await _copyCustomFormFromSource(
                            context: dialogContext,
                            sourceDoc: doc,
                          );
                        },
                        child: const Text('Use'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCustomFormFromSource({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> sourceDoc,
  }) async {
    final source = sourceDoc.data();
    final sourceFacility = '${source['facilityName'] ?? 'another facility'}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this custom form?'),
        content: Text(
          'Copy "${source['title'] ?? 'Custom form'}" from $sourceFacility into $facilityName? You can edit it after copying.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use form'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final data = Map<String, dynamic>.from(source);
    data
      ..['facilityName'] = facilityName
      ..['facilityId'] = facilityId
      ..['isActive'] = true
      ..['sourceFacilityName'] = sourceFacility
      ..['sourceCustomFormDocId'] = sourceDoc.id
      ..['importedAt'] = FieldValue.serverTimestamp()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    data.remove('deletedAt');
    await FirebaseFirestore.instance.collection('ipc_custom_forms').add(data);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom surveillance form imported')),
      );
    }
  }

  Future<void> _deleteCustomForm(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> form,
  ) async {
    final title = '${form.data()['title'] ?? 'Custom form'}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete custom form'),
        content: Text(
          'Delete "$title"? Existing submitted data will remain in Surveillance Data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await form.reference.update({
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom surveillance form deleted')),
      );
    }
  }

  bool _isIpcStaff(Map<String, dynamic> data) {
    final profession = '${data['profession'] ?? ''}'.toLowerCase();
    final department = '${data['department'] ?? ''}'.toLowerCase();
    return profession.startsWith('ipc ') ||
        profession.contains('infection prevention') ||
        department.contains('infection prevention') ||
        department.contains('infection control');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPC Dashboard Control'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _IpcCustomFormBuilderScreen(
              facilityName: facilityName,
              facilityId: facilityId,
            ),
          ),
        ),
        icon: const Icon(Icons.dynamic_form_outlined),
        label: const Text('Create surveillance'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _customFormsQuery.snapshots(),
        builder: (context, formsSnapshot) {
          final customForms =
              formsSnapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Select and save the IPC dashboard tabs and custom surveillance forms each staff member is permitted to access.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openCustomFormReuseDialog(context),
                      icon: const Icon(Icons.library_add_outlined),
                      label: const Text('Reuse existing custom form'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Editable built-in surveillance forms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._builtInTemplates.map(
                (template) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.edit_document),
                    title: Text(template.title),
                    subtitle: Text(template.description),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Reuse template from another facility',
                          icon: const Icon(Icons.library_add_outlined),
                          onPressed: () => _openBuiltInTemplateReuseDialog(
                            context,
                            template,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      final data = await _loadBuiltInTemplate(template);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _IpcCustomFormBuilderScreen(
                            facilityName: facilityName,
                            facilityId: facilityId,
                            documentId:
                                '${_facilityTemplateKey}_${template.id}',
                            initialData: data,
                            collectionName: 'ipc_form_templates',
                            isBuiltInTemplate: true,
                            templateId: template.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Custom surveillance forms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (formsSnapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Unable to load custom forms: ${formsSnapshot.error}',
                    ),
                  ),
                )
              else if (formsSnapshot.connectionState == ConnectionState.waiting)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (customForms.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No custom surveillance forms saved yet.'),
                  ),
                )
              else
                ...customForms.map(
                  (form) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text('${form.data()['title'] ?? 'Custom form'}'),
                      subtitle: Text(
                        '${(form.data()['questions'] as List<dynamic>? ?? []).length} questions',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit form',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _IpcCustomFormBuilderScreen(
                                  facilityName: facilityName,
                                  facilityId: facilityId,
                                  documentId: form.id,
                                  initialData: form.data(),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete form',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteCustomForm(context, form),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'IPC staff access',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(_collection)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Unable to load IPC staff: ${snapshot.error}',
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final staff =
                      (snapshot.data?.docs ?? [])
                          .where(
                            (doc) =>
                                _isIpcStaff(doc.data() as Map<String, dynamic>),
                          )
                          .toList()
                        ..sort((a, b) {
                          final aName =
                              '${(a.data() as Map<String, dynamic>)['fullName'] ?? ''}';
                          final bName =
                              '${(b.data() as Map<String, dynamic>)['fullName'] ?? ''}';
                          return aName.compareTo(bName);
                        });
                  if (staff.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No registered IPC staff found. Register IPC staff before assigning dashboard access.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: staff
                        .map(
                          (document) => _IpcStaffAccessCard(
                            document: document,
                            customForms: customForms,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IpcStaffAccessCard extends StatefulWidget {
  final QueryDocumentSnapshot document;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> customForms;

  const _IpcStaffAccessCard({
    required this.document,
    required this.customForms,
  });

  @override
  State<_IpcStaffAccessCard> createState() => _IpcStaffAccessCardState();
}

class _IpcStaffAccessCardState extends State<_IpcStaffAccessCard> {
  late Set<String> _selectedTabs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.document.data() as Map<String, dynamic>;
    final saved = (data['ipcTabAccess'] as List<dynamic>? ?? []).cast<String>();
    _selectedTabs = saved.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.document.reference.update({
        'ipcTabAccess': _selectedTabs.toList(),
        'ipcAccessUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IPC dashboard access updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update access: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
        title: Text(
          '${data['fullName'] ?? 'IPC Staff'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${data['profession'] ?? 'IPC Staff'}'),
        children: [
          ...IpcDashboardControlScreen.tabLabels.entries.map(
            (entry) => CheckboxListTile(
              title: Text(entry.value),
              value: _selectedTabs.contains(entry.key),
              onChanged: (selected) {
                setState(() {
                  if (selected ?? false) {
                    _selectedTabs.add(entry.key);
                  } else {
                    _selectedTabs.remove(entry.key);
                  }
                });
              },
            ),
          ),
          if (widget.customForms.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Custom surveillance forms',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ...widget.customForms.map((form) {
              final key = 'custom_form:${form.id}';
              return CheckboxListTile(
                title: Text('${form.data()['title'] ?? 'Custom form'}'),
                subtitle: const Text('Custom IPC surveillance form'),
                value: _selectedTabs.contains(key),
                onChanged: (selected) {
                  setState(() {
                    if (selected ?? false) {
                      _selectedTabs.add(key);
                    } else {
                      _selectedTabs.remove(key);
                    }
                  });
                },
              );
            }),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save access'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuiltInIpcFormTemplate {
  final String id;
  final String title;
  final String description;
  final List<Map<String, dynamic>> questions;

  const _BuiltInIpcFormTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
  });

  Map<String, dynamic> toFirestore({
    required String facilityName,
    String? facilityId,
  }) {
    return {
      'facilityName': facilityName,
      if (facilityId != null && facilityId.isNotEmpty) 'facilityId': facilityId,
      'templateId': id,
      'formKind': 'built_in_surveillance_template',
      'title': title,
      'description': description,
      'questions': questions,
      'isActive': true,
      'lockedStableKeys': true,
    };
  }
}

List<Map<String, dynamic>> _haiTemplateQuestions() {
  return [
    for (final field in haiQuestionnaireFields)
      _templateQuestion(
        id: field.name,
        label: field.name == '_76_Sub_specy' ? 'Add pathogen' : field.label,
        type: field.name == '_76_Sub_specy'
            ? 'short_text'
            : field.name == 'Antimicrobials_001'
            ? 'multiple_choice'
            : _haiDefaultCalculation(field.name) != null
            ? 'calculated'
            : _builderTypeFromHai(field.type),
        required: field.name == '_76_Sub_specy' ? false : field.required,
        section: field.section,
        options: field.name == '_76_Sub_specy'
            ? const <String>[]
            : field.options.map((option) => option.label).toList(),
        optionValues: field.name == '_76_Sub_specy'
            ? const <String, String>{}
            : {for (final option in field.options) option.label: option.value},
        relevant: field.name == '_76_Sub_specy'
            ? r"${Pathogen_Identified} != ''"
            : field.relevant,
        calculation: _haiDefaultCalculation(field.name),
        metadata: field.name == 'Antimicrobials_001'
            ? {
                'behavior': 'antimicrobial_bank',
                'addButtonLabel': 'Add antimicrobial',
                'selectionTitle': 'Select antimicrobial',
                'detailsAnswerKey': 'Antimicrobials_001_details',
                'hideTemplateQuestions': _antimicrobialBankChildQuestionIds(),
                'childFields': _antimicrobialBankChildQuestions(),
              }
            : field.name == '_76_Sub_specy'
            ? {
                'behavior': 'repeat_group',
                'addButtonLabel': 'Add pathogen',
                'buttonVariant': 'link',
                'detailsAnswerKey': 'Additional_Pathogens_Details',
                'itemTitlePrefix': 'Additional pathogen',
                'childFields': _additionalPathogenChildQuestions(),
              }
            : null,
      ),
  ];
}

Map<String, dynamic>? _haiDefaultCalculation(String fieldName) {
  return switch (fieldName) {
    '_40_Duration_of_hosp_ays_weeks_or_months' => const {
      'type': 'days_since_date',
      'sourceQuestionId': '_8_Date_of_admission',
      'endQuestionId': 'Date_of_discharge',
      'endFallback': 'today',
      'inclusive': true,
      'unit': 'days',
    },
    'Duration_on_device_days' => const {
      'type': 'days_since_date',
      'sourceQuestionId': 'Date_of_device_insertion',
      'endQuestionId': 'Date_of_device_removal',
      'endFallback': 'today',
      'inclusive': true,
      'unit': 'days',
    },
    _ => null,
  };
}

List<String> _antimicrobialBankChildQuestionIds() =>
    _antimicrobialBankChildFields().map((field) => field.name).toList();

List<Map<String, dynamic>> _antimicrobialBankChildQuestions() {
  return [
    for (final field in _antimicrobialBankChildFields())
      {
        'key': field.name,
        'label': field.label,
        'type': _builderTypeFromHai(field.type),
        'required': field.required,
        'options': field.options.map((option) => option.label).toList(),
        'optionValues': {
          for (final option in field.options) option.label: option.value,
        },
        if (field.calculation.isNotEmpty) 'calculation': field.calculation,
        if (field.relevant.trim().isNotEmpty) 'relevant': field.relevant,
      },
  ];
}

List<HaiQuestionnaireField> _antimicrobialBankChildFields() {
  final start = haiQuestionnaireFields.indexWhere(
    (field) => field.name == '_17_Please_specify',
  );
  final end = haiQuestionnaireFields.indexWhere(
    (field) => field.name == '_29_What_was_the_reason_for_th',
  );
  if (start < 0 || end <= start) return const <HaiQuestionnaireField>[];
  return haiQuestionnaireFields.sublist(start, end);
}

List<Map<String, dynamic>> _additionalPathogenChildQuestions() {
  return [
    for (final field in _additionalPathogenChildFields())
      {
        'key': field.name,
        'label': field.label,
        'type': _builderTypeFromHai(field.type),
        'required': field.required,
        'options': field.options.map((option) => option.label).toList(),
        'optionValues': {
          for (final option in field.options) option.label: option.value,
        },
        if (field.relevant.trim().isNotEmpty) 'relevant': field.relevant,
      },
  ];
}

List<HaiQuestionnaireField> _additionalPathogenChildFields() {
  final start = haiQuestionnaireFields.indexWhere(
    (field) => field.name == '_45_Specimen_collected',
  );
  var end = haiQuestionnaireFields.indexWhere(
    (field) => field.name == '_83_Type_of_Sample_Collected_2',
  );
  if (end < 0) {
    end = haiQuestionnaireFields.indexWhere(
      (field) => field.name == '_76_Sub_specy',
    );
  }
  if (start < 0 || end <= start) return const <HaiQuestionnaireField>[];
  return haiQuestionnaireFields
      .sublist(start, end)
      .where((field) => field.name != '_76_Sub_specy')
      .toList();
}

List<Map<String, dynamic>> _environmentalHealthTemplateQuestions() {
  return [
    for (final question in environmentalHealthQuestions)
      _templateQuestion(
        id: question.name,
        label: question.label,
        type: _builderTypeFromXlsType(question.type),
        required: question.required,
        section: 'Environmental Health Surveillance',
        options: question.choices.map((choice) => choice.label).toList(),
        optionValues: {
          for (final choice in question.choices) choice.label: choice.value,
        },
        relevant: question.relevant,
        hint: question.hint,
      ),
  ];
}

List<Map<String, dynamic>> _waterQualityTemplateQuestions() {
  return [
    for (final field in waterQualityFields)
      _templateQuestion(
        id: field.name,
        label: field.label,
        type: _builderTypeFromWater(field.type),
        required: field.required,
        section: field.section,
        options: field.options,
        relevant: field.visibleWhenField == null
            ? ''
            : 'Show when ${field.visibleWhenField} is one of ${field.visibleWhenValues.join(', ')}',
        hint: field.hint,
      ),
  ];
}

List<Map<String, dynamic>> _wardDenominatorTemplateQuestions() {
  return [
    for (final field in wardDenominatorFields)
      _templateQuestion(
        id: field.name,
        label: field.label,
        type: field.type == 'integer'
            ? 'number'
            : field.type == 'date'
            ? 'date'
            : field.type == 'select_one'
            ? 'multiple_choice'
            : 'short_text',
        required: field.required,
        section: 'Ward Denominator',
        options: _wardDenominatorOptions(field.name),
      ),
  ];
}

Map<String, dynamic> _templateQuestion({
  required String id,
  required String label,
  required String type,
  required bool required,
  required String section,
  List<String> options = const [],
  Map<String, String> optionValues = const {},
  String? relevant,
  String? hint,
  Map<String, dynamic>? calculation,
  Map<String, dynamic>? metadata,
}) {
  return {
    'id': id,
    'stableName': id,
    'label': label,
    'type': type,
    'required': required,
    'section': section,
    'options': options,
    'optionValues': optionValues,
    'gridRows': <String>[],
    'gridColumns': <String>[],
    'scaleMin': 1,
    'scaleMax': 5,
    'showIfQuestionId': '',
    'showIfValue': '',
    'showIfRules': <Map<String, String>>[],
    if ((relevant ?? '').trim().isNotEmpty) 'relevant': relevant,
    if ((hint ?? '').trim().isNotEmpty) 'hint': hint,
    if (calculation != null && calculation.isNotEmpty)
      'calculation': calculation,
    if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
  };
}

String _builderTypeFromHai(String type) {
  return switch (type) {
    'select' => 'multiple_choice',
    'multiselect' => 'checkbox',
    'date' => 'date',
    'integer' || 'decimal' => 'number',
    'multiline' => 'long_text',
    _ => 'short_text',
  };
}

String _builderTypeFromXlsType(String type) {
  return switch (type) {
    'select_one' => 'multiple_choice',
    'select_multiple' => 'checkbox',
    'integer' || 'decimal' => 'number',
    'date' => 'date',
    'note' => 'sub_heading',
    _ => 'short_text',
  };
}

String _builderTypeFromWater(String type) {
  return switch (type) {
    'select' => 'multiple_choice',
    'multiselect' => 'checkbox',
    'integer' || 'decimal' => 'number',
    'date' => 'date',
    'multiline' => 'long_text',
    _ => 'short_text',
  };
}

List<String> _wardDenominatorOptions(String fieldName) {
  return switch (fieldName) {
    'Department' =>
      wardDenominatorDepartmentChoices.map((choice) => choice.label).toList(),
    'Ward' => wardDenominatorWardChoices.map((choice) => choice.label).toList(),
    'Surveillance_Day' =>
      wardDenominatorDayChoices.map((choice) => choice.label).toList(),
    _ => const <String>[],
  };
}

class _IpcCustomFormBuilderScreen extends StatefulWidget {
  final String facilityName;
  final String? facilityId;
  final String? documentId;
  final Map<String, dynamic>? initialData;
  final String collectionName;
  final bool isBuiltInTemplate;
  final String? templateId;

  const _IpcCustomFormBuilderScreen({
    required this.facilityName,
    this.facilityId,
    this.documentId,
    this.initialData,
    this.collectionName = 'ipc_custom_forms',
    this.isBuiltInTemplate = false,
    this.templateId,
  });

  @override
  State<_IpcCustomFormBuilderScreen> createState() =>
      _IpcCustomFormBuilderScreenState();
}

class _IpcCustomFormBuilderScreenState
    extends State<_IpcCustomFormBuilderScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _questions = [];
  final Set<String> _expandedQuestionIds = {};
  String? _documentId;
  bool _saving = false;

  static const _questionTypes = {
    'sub_heading': 'Sub-heading',
    'short_text': 'Text field (short answer)',
    'long_text': 'Text field (long answer, paragraph)',
    'multiple_choice': 'Multiple choice (select one)',
    'checkbox': 'Check box',
    'number': 'Number',
    'calculated': 'Calculated answer',
    'date': 'Date',
    'time': 'Time',
    'file_upload': 'File upload',
    'multiple_choice_grid': 'Multiple choice - grid',
    'tickbox_grid': 'Tickbox grid',
    'linear_scale': 'Linear scale',
  };

  @override
  void initState() {
    super.initState();
    _documentId = widget.documentId;
    final data = widget.initialData;
    if (data != null) {
      _titleController.text = '${data['title'] ?? ''}';
      _descriptionController.text = '${data['description'] ?? ''}';
      final questions = data['questions'];
      if (questions is List) {
        _questions.addAll(
          questions.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
    }
    if (_questions.isEmpty) _addQuestion();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addQuestion({int? index}) {
    final id = 'q_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      final question = {
        'id': id,
        'label': '',
        'type': 'short_text',
        'required': false,
        'options': <String>[],
        'gridRows': <String>[],
        'gridColumns': <String>[],
        'scaleMin': 1,
        'scaleMax': 5,
        'showIfQuestionId': '',
        'showIfValue': '',
        'showIfRules': <Map<String, String>>[],
        'calculation': <String, dynamic>{},
      };
      if (index == null || index < 0 || index > _questions.length) {
        _questions.add(question);
      } else {
        _questions.insert(index, question);
      }
      _expandedQuestionIds.add(id);
      _renumberQuestions();
    });
  }

  void _reorderQuestion(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final question = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, question);
      _renumberQuestions();
    });
  }

  void _renumberQuestions() {
    for (var index = 0; index < _questions.length; index += 1) {
      _questions[index]['order'] = index;
      _questions[index]['displayNumber'] = index + 1;
    }
  }

  void _duplicateQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    final source = _questions[index];
    final duplicate = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    final id = 'q_${DateTime.now().microsecondsSinceEpoch}';
    duplicate['id'] = id;
    duplicate['stableName'] = _duplicatedStableName(source, id);
    duplicate['label'] = _duplicatedLabel('${source['label'] ?? ''}');
    setState(() {
      _questions.insert(index + 1, duplicate);
      _expandedQuestionIds.add(id);
      _renumberQuestions();
    });
  }

  String _duplicatedStableName(Map<String, dynamic> source, String fallbackId) {
    final raw = '${source['stableName'] ?? source['id'] ?? fallbackId}'.trim();
    final base = raw.isEmpty
        ? fallbackId
        : raw
              .replaceAll(RegExp(r'_copy_\d+$'), '')
              .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${base.isEmpty ? fallbackId : base}_copy_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _duplicatedLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('(copy)') ? trimmed : '$trimmed (copy)';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a form title')));
      return;
    }
    _renumberQuestions();
    final validQuestions = _questions
        .where((question) => '${question['label'] ?? ''}'.trim().isNotEmpty)
        .map(_normalizedQuestionForSave)
        .toList();
    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final isNewDocument = _documentId == null;
      final existingCreatedAt = widget.initialData?['createdAt'];
      final data = {
        'facilityName': widget.facilityName,
        if (widget.facilityId != null && widget.facilityId!.isNotEmpty)
          'facilityId': widget.facilityId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'questions': validQuestions,
        'isActive': true,
        if (widget.isBuiltInTemplate) ...{
          'formKind': 'built_in_surveillance_template',
          'templateId': widget.templateId,
          'lockedStableKeys': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNewDocument) 'createdAt': FieldValue.serverTimestamp(),
        if (!isNewDocument && existingCreatedAt != null)
          'createdAt': existingCreatedAt,
      };
      final collection = FirebaseFirestore.instance.collection(
        widget.collectionName,
      );
      if (_documentId == null) {
        final saved = await collection.add(data);
        _documentId = saved.id;
      } else {
        await collection.doc(_documentId).set(data);
      }
      await _reloadSavedTemplate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isBuiltInTemplate
                  ? 'Surveillance form template saved'
                  : 'Custom surveillance form saved',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save form: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadSavedTemplate() async {
    final documentId = _documentId;
    if (documentId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(documentId)
        .get();
    if (!mounted) return;
    final data = snapshot.data();
    final savedQuestions = data?['questions'];
    if (savedQuestions is! List) return;
    _questions
      ..clear()
      ..addAll(
        savedQuestions.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    _titleController.text = '${data?['title'] ?? _titleController.text}';
    _descriptionController.text =
        '${data?['description'] ?? _descriptionController.text}';
    _renumberQuestions();
  }

  Future<void> _importQuestionsFromSpreadsheet() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      final extension = (file.extension ?? file.name.split('.').last)
          .toLowerCase();
      final rows = extension == 'csv'
          ? _rowsFromCsv(bytes)
          : _rowsFromExcel(bytes);
      final imported = _questionsFromRows(rows);
      if (imported.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No questions found. Use columns such as question, type, options, required, section, show if question, and show if answer.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import questionnaire'),
          content: Text(
            'Found ${imported.length} questions in ${file.name}. Replace current questions or append them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Append'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace == null || !mounted) return;
      setState(() {
        if (replace) _questions.clear();
        _questions.addAll(imported);
        if (replace) _expandedQuestionIds.clear();
        _renumberQuestions();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} questions imported')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to import questionnaire: $error')),
      );
    }
  }

  List<List<String>> _rowsFromCsv(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    return const LineSplitter()
        .convert(content)
        .where((line) => line.trim().isNotEmpty)
        .map(_splitCsvLine)
        .toList();
  }

  List<String> _splitCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i += 1) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  List<List<String>> _rowsFromExcel(Uint8List bytes) {
    final workbook = excel.Excel.decodeBytes(bytes);
    for (final tableName in workbook.tables.keys) {
      final sheet = workbook.tables[tableName];
      if (sheet == null || sheet.rows.isEmpty) continue;
      final rows = sheet.rows
          .map(
            (row) =>
                row.map((cell) => cell?.value.toString().trim() ?? '').toList(),
          )
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList();
      if (rows.isNotEmpty) return rows;
    }
    return const [];
  }

  List<Map<String, dynamic>> _questionsFromRows(List<List<String>> rows) {
    if (rows.isEmpty) return const [];
    final headerIndex = rows.indexWhere(
      (row) => row.any((cell) => _headerKey(cell) == 'question'),
    );
    final headers = headerIndex >= 0
        ? rows[headerIndex].map(_headerKey).toList()
        : const <String>[];
    final dataRows = headerIndex >= 0 ? rows.skip(headerIndex + 1) : rows;
    final imported = <Map<String, dynamic>>[];
    var index = 0;
    for (final row in dataRows) {
      final questionText = headerIndex >= 0
          ? _rowValue(row, headers, 'question')
          : row.isEmpty
          ? ''
          : row.first;
      if (questionText.trim().isEmpty) continue;
      final typeText = headerIndex >= 0 ? _rowValue(row, headers, 'type') : '';
      final optionsText = headerIndex >= 0
          ? _rowValue(row, headers, 'options')
          : row.length > 1
          ? row[1]
          : '';
      imported.add({
        'id': _importedQuestionId(row, headers, headerIndex, index),
        'label': questionText.trim(),
        'type': _questionTypeFromImport(typeText, optionsText),
        'required': _truthy(
          headerIndex >= 0 ? _rowValue(row, headers, 'required') : '',
        ),
        'options': _splitOptions(optionsText),
        'gridRows': _splitOptions(
          headerIndex >= 0 ? _rowValue(row, headers, 'grid_rows') : '',
        ),
        'gridColumns': _splitOptions(
          headerIndex >= 0 ? _rowValue(row, headers, 'grid_columns') : '',
        ),
        'scaleMin':
            int.tryParse(
              headerIndex >= 0 ? _rowValue(row, headers, 'scale_min') : '',
            ) ??
            1,
        'scaleMax':
            int.tryParse(
              headerIndex >= 0 ? _rowValue(row, headers, 'scale_max') : '',
            ) ??
            5,
        'section': headerIndex >= 0 ? _rowValue(row, headers, 'section') : '',
        'showIfQuestionId': headerIndex >= 0
            ? _rowValue(row, headers, 'show_if_question').trim()
            : '',
        'showIfValue': headerIndex >= 0
            ? _rowValue(row, headers, 'show_if_answer').trim()
            : '',
        'showIfRules': _rulesFromImportedRow(row, headers, headerIndex),
      });
      index += 1;
    }
    return imported;
  }

  List<Map<String, String>> _rulesFromImportedRow(
    List<String> row,
    List<String> headers,
    int headerIndex,
  ) {
    if (headerIndex < 0) return const [];
    final parent = _rowValue(row, headers, 'show_if_question').trim();
    final answer = _rowValue(row, headers, 'show_if_answer').trim();
    if (parent.isEmpty || answer.isEmpty) return const [];
    return [
      {'questionId': parent, 'value': answer},
    ];
  }

  String _importedQuestionId(
    List<String> row,
    List<String> headers,
    int headerIndex,
    int index,
  ) {
    final importedId = headerIndex >= 0 ? _rowValue(row, headers, 'id') : '';
    if (importedId.trim().isNotEmpty) return importedId.trim();
    return 'q_${DateTime.now().microsecondsSinceEpoch}_$index';
  }

  String _rowValue(List<String> row, List<String> headers, String key) {
    final index = headers.indexOf(key);
    if (index < 0 || index >= row.length) return '';
    return row[index];
  }

  String _headerKey(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return switch (normalized) {
      'question' || 'question_text' || 'label' || 'prompt' => 'question',
      'question_type' || 'field_type' || 'answer_type' || 'style' => 'type',
      'choice' || 'choices' || 'option' || 'option_list' => 'options',
      'mandatory' || 'is_required' => 'required',
      'group' || 'sub_heading' || 'subhead' || 'sub_head' => 'section',
      'name' || 'field_name' || 'variable' || 'variable_name' => 'id',
      'show_if' ||
      'relevant_question' ||
      'condition_question' => 'show_if_question',
      'show_if_answer' ||
      'relevant_answer' ||
      'condition_answer' => 'show_if_answer',
      'rows' || 'grid_row' => 'grid_rows',
      'columns' || 'grid_column' => 'grid_columns',
      'min' => 'scale_min',
      'max' => 'scale_max',
      _ => normalized,
    };
  }

  String _questionTypeFromImport(String typeText, String optionsText) {
    final type = typeText.trim().toLowerCase();
    if (type.contains('long') || type.contains('paragraph')) {
      return 'long_text';
    }
    if (type.contains('heading') ||
        type.contains('subhead') ||
        type.contains('section') ||
        type == 'note') {
      return 'sub_heading';
    }
    if (type.contains('check') || type.contains('tickbox')) return 'checkbox';
    if (type.contains('multi') && type.contains('grid')) {
      return 'multiple_choice_grid';
    }
    if (type.contains('grid') && type.contains('tick')) return 'tickbox_grid';
    if (type.contains('scale')) return 'linear_scale';
    if (type.contains('calculate') || type.contains('computed')) {
      return 'calculated';
    }
    if (type.contains('date')) return 'date';
    if (type.contains('time')) return 'time';
    if (type.contains('file')) return 'file_upload';
    if (type.contains('number') || type.contains('integer')) return 'number';
    if (type.contains('select') ||
        type.contains('choice') ||
        type.contains('radio') ||
        optionsText.trim().isNotEmpty) {
      return 'multiple_choice';
    }
    return 'short_text';
  }

  List<String> _splitOptions(String value) {
    return value
        .split(RegExp(r'[;\n|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _truthy(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'yes' ||
        normalized == 'true' ||
        normalized == 'required' ||
        normalized == '1';
  }

  String _normalizeSkipLogicValue(Object? value) {
    final text = '${value ?? ''}'.trim();
    final normalized = text.toLowerCase();
    if (normalized == 'answered' ||
        normalized == 'is answered' ||
        normalized == 'any answer' ||
        normalized == 'not blank' ||
        normalized == '__answered__') {
      return '__answered__';
    }
    return text;
  }

  String _skipLogicValueLabel(String value) {
    return value == '__answered__' ? 'Answered' : value;
  }

  Map<String, dynamic> _normalizedQuestionForSave(
    Map<String, dynamic> question,
  ) {
    final normalized = Map<String, dynamic>.from(question);
    final stableName = '${normalized['stableName'] ?? normalized['id']}';
    if (widget.isBuiltInTemplate &&
        widget.templateId == 'hai_surveillance' &&
        _isAdditionalPathogenRepeatQuestion(normalized)) {
      final triggerQuestionId =
          _builderFirstQuestionIdByMeaning(const [
            'pathogen identified',
            'organism identified',
            'microorganism identified',
            'pathogen isolated',
            'organism isolated',
            'microorganism isolated',
          ]) ??
          'Pathogen_Identified';
      normalized
        ..['label'] = 'Add pathogen'
        ..['type'] = 'short_text'
        ..['required'] = false
        ..['options'] = <String>[]
        ..['optionValues'] = <String, String>{}
        ..['showIfQuestionId'] = ''
        ..['showIfValue'] = ''
        ..['showIfRules'] = <Map<String, String>>[]
        ..['relevant'] = "\${$triggerQuestionId} != ''";
    }
    if (widget.isBuiltInTemplate &&
        widget.templateId == 'hai_surveillance' &&
        stableName == 'Antimicrobials_001') {
      normalized['type'] = 'multiple_choice';
    }
    if (widget.isBuiltInTemplate &&
        widget.templateId == 'hai_surveillance' &&
        stableName == 'Duration_on_device_days') {
      normalized['relevant'] =
          r"selected(${Type_of_risk}, 'medical_device') and ${Date_of_device_insertion} != ''";
    }
    if (normalized['type'] == 'sub_heading') {
      normalized['required'] = false;
      normalized['options'] = <String>[];
      normalized['gridRows'] = <String>[];
      normalized['gridColumns'] = <String>[];
      normalized['showIfQuestionId'] = '';
      normalized['showIfValue'] = '';
      normalized['showIfRules'] = <Map<String, String>>[];
      normalized.remove('calculation');
    } else {
      final rules = _normalizedConditionalRules(normalized);
      normalized['showIfRules'] = rules;
      normalized['showIfQuestionId'] = rules.isEmpty
          ? ''
          : rules.first['questionId'];
      normalized['showIfValue'] = rules.isEmpty ? '' : rules.first['value'];
      final calculation = _normalizedCalculationRule(normalized);
      if (calculation.isEmpty) {
        normalized.remove('calculation');
      } else {
        normalized['calculation'] = calculation;
      }
    }
    final repeatMetadata = _haiRepeatMetadataForQuestion(normalized);
    if (repeatMetadata == null) {
      if (normalized['metadata'] is! Map ||
          (normalized['metadata'] as Map).isEmpty) {
        normalized.remove('metadata');
      }
    } else {
      normalized['metadata'] = repeatMetadata;
    }
    return normalized;
  }

  Map<String, dynamic>? _haiRepeatMetadataForQuestion(
    Map<String, dynamic> question,
  ) {
    if (!widget.isBuiltInTemplate || widget.templateId != 'hai_surveillance') {
      return null;
    }
    final stableName = '${question['stableName'] ?? question['id']}';
    if (stableName == 'Antimicrobials_001') {
      final childIds = _builderAntimicrobialChildIds();
      return {
        'behavior': 'antimicrobial_bank',
        'addButtonLabel': 'Add antimicrobial',
        'selectionTitle': 'Select antimicrobial',
        'detailsAnswerKey': 'Antimicrobials_001_details',
        'hideTemplateQuestions': childIds,
        'childFields': _builderChildQuestions(childIds),
      };
    }
    if (_isAdditionalPathogenRepeatQuestion(question)) {
      final childIds = _builderAdditionalPathogenChildIds(question);
      final pathogenSource = _builderFirstQuestionIdByMeaning(const [
        'pathogen identified',
        'organism identified',
        'microorganism identified',
        'pathogen isolated',
        'organism isolated',
        'microorganism isolated',
      ]);
      return {
        'behavior': 'repeat_group',
        'addButtonLabel': 'Add pathogen',
        'buttonVariant': 'link',
        'detailsAnswerKey': 'Additional_Pathogens_Details',
        'itemTitlePrefix': 'Additional pathogen',
        'triggerQuestionId': ?pathogenSource,
        'childFields': _builderChildQuestions(childIds),
      };
    }
    return null;
  }

  List<String> _builderAntimicrobialChildIds() {
    final childIds = _builderQuestionIdsBetween(
      startId: '_17_Please_specify',
      endBeforeId: '_29_What_was_the_reason_for_th',
    );
    for (final question in _questions) {
      if (!_builderQuestionMatchesMeaning(question, const [
        'date antimicrobial commenced',
        'date antimicrobial commencement',
        'antimicrobial commencement date',
        'date antimicrobial completed',
        'date antimicrobial completion',
        'antimicrobial completion date',
        'date antibiotic commenced',
        'date antibiotic completion',
        'duration on antimicrobial',
        'duration of antimicrobial',
        'antimicrobial duration',
        'route of administration',
        'reason for prescription',
      ])) {
        continue;
      }
      final id = '${question['stableName'] ?? question['id']}';
      if (id.trim().isNotEmpty && !childIds.contains(id)) childIds.add(id);
    }
    return childIds;
  }

  bool _isAdditionalPathogenRepeatQuestion(Map<String, dynamic> question) {
    final stableName = '${question['stableName'] ?? question['id']}';
    if (stableName == '_76_Sub_specy') return true;
    final metadata = question['metadata'];
    if (metadata is Map &&
        '${metadata['behavior'] ?? ''}' == 'repeat_group' &&
        '${metadata['detailsAnswerKey'] ?? ''}' ==
            'Additional_Pathogens_Details') {
      return true;
    }
    final normalizedLabel = _builderComparableToken(
      '${question['label'] ?? ''}',
    );
    return normalizedLabel == 'add_pathogen' ||
        normalizedLabel == 'add_additional_pathogen';
  }

  String _builderComparableToken(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  bool _builderQuestionMatchesMeaning(
    Map<String, dynamic> question,
    List<String> meanings,
  ) {
    final haystack = _builderComparableToken(
      '${question['label'] ?? ''} ${question['stableName'] ?? ''} ${question['id'] ?? ''}',
    );
    return meanings
        .map(_builderComparableToken)
        .any((meaning) => haystack.contains(meaning));
  }

  String? _builderFirstQuestionIdByMeaning(List<String> meanings) {
    for (final question in _questions) {
      if (_builderQuestionMatchesMeaning(question, meanings)) {
        return '${question['stableName'] ?? question['id']}';
      }
    }
    return null;
  }

  List<String> _builderAdditionalPathogenChildIds(
    Map<String, dynamic> addPathogenQuestion,
  ) {
    final addPathogenId =
        '${addPathogenQuestion['stableName'] ?? addPathogenQuestion['id']}';
    final addPathogenIndex = _questions.indexWhere(
      (question) =>
          '${question['id'] ?? ''}' == '${addPathogenQuestion['id'] ?? ''}' ||
          '${question['stableName'] ?? question['id']}' == addPathogenId ||
          _isAdditionalPathogenRepeatQuestion(question),
    );
    var start = _questions.indexWhere(
      (question) => _builderQuestionMatchesMeaning(question, const [
        'type of sample collected',
        'sample type',
        'specimen type',
        'specimen collected',
        'sample collected',
      ]),
    );
    if (start < 0) {
      start = _questions.indexWhere(
        (question) => _builderQuestionMatchesMeaning(question, const [
          'pathogen identified',
          'organism identified',
          'microorganism identified',
          'pathogen isolated',
          'organism isolated',
          'microorganism isolated',
        ]),
      );
    }
    var end = addPathogenIndex;
    if (start < 0) return const <String>[];
    if (end <= start) {
      var lastResistance = -1;
      for (var index = start; index < _questions.length; index += 1) {
        final question = _questions[index];
        if (_isAdditionalPathogenRepeatQuestion(question)) continue;
        if (_builderQuestionMatchesMeaning(question, const [
          'resistant pattern',
          'resistance pattern',
          'resistant type',
          'resistance type',
        ])) {
          lastResistance = index;
        }
      }
      end = lastResistance >= start ? lastResistance + 1 : _questions.length;
    }
    return _questions
        .sublist(start, end)
        .where((question) => !_isAdditionalPathogenRepeatQuestion(question))
        .map((question) => '${question['stableName'] ?? question['id']}')
        .where((id) => id.trim().isNotEmpty && id != addPathogenId)
        .toList();
  }

  List<String> _builderQuestionIdsBetween({
    required String startId,
    required String endBeforeId,
  }) {
    final start = _questions.indexWhere(
      (question) => '${question['stableName'] ?? question['id']}' == startId,
    );
    final end = _questions.indexWhere(
      (question) =>
          '${question['stableName'] ?? question['id']}' == endBeforeId,
    );
    if (start < 0 || end <= start) return const <String>[];
    return _questions
        .sublist(start, end)
        .map((question) => '${question['stableName'] ?? question['id']}')
        .where((id) => id.trim().isNotEmpty)
        .toList();
  }

  List<String> _builderQuestionIdsBeforeQuestion({
    required String startId,
    required Map<String, dynamic> endBeforeQuestion,
  }) {
    final start = _questions.indexWhere(
      (question) => '${question['stableName'] ?? question['id']}' == startId,
    );
    final endId = '${endBeforeQuestion['id'] ?? ''}';
    final endStableName =
        '${endBeforeQuestion['stableName'] ?? endBeforeQuestion['id']}';
    final end = _questions.indexWhere(
      (question) =>
          '${question['id'] ?? ''}' == endId ||
          '${question['stableName'] ?? question['id']}' == endStableName,
    );
    if (start < 0 || end <= start) return const <String>[];
    return _questions
        .sublist(start, end)
        .map((question) => '${question['stableName'] ?? question['id']}')
        .where((id) => id.trim().isNotEmpty && id != endStableName)
        .toList();
  }

  List<Map<String, dynamic>> _builderChildQuestions(List<String> ids) {
    final idSet = ids.toSet();
    return [
      for (final question in _questions)
        if (idSet.contains('${question['stableName'] ?? question['id']}'))
          {
            'key': '${question['stableName'] ?? question['id']}',
            'label': '${question['label'] ?? ''}',
            'type': '${question['type'] ?? 'short_text'}',
            'required': question['required'] == true,
            'options': _builderStringList(question['options']),
            'optionValues': question['optionValues'] is Map
                ? Map<String, dynamic>.from(question['optionValues'] as Map)
                : const <String, dynamic>{},
            if (_builderChildCalculation(question).isNotEmpty)
              'calculation': _builderChildCalculation(question),
            if ('${question['relevant'] ?? ''}'.trim().isNotEmpty)
              'relevant': '${question['relevant']}',
          },
    ];
  }

  List<String> _builderStringList(Object? value) {
    return (value as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _builderChildCalculation(Map<String, dynamic> question) {
    final calculation = _normalizedCalculationRule(question);
    if (calculation.isEmpty) return const {};
    String? stableQuestionId(String questionId) {
      for (final candidate in _questions) {
        if ('${candidate['id']}' == questionId ||
            '${candidate['stableName'] ?? candidate['id']}' == questionId) {
          return '${candidate['stableName'] ?? candidate['id']}';
        }
      }
      return null;
    }

    final sourceQuestionId = '${calculation['sourceQuestionId'] ?? ''}';
    final stableSourceQuestionId = stableQuestionId(sourceQuestionId);
    final endQuestionId = '${calculation['endQuestionId'] ?? ''}'.trim();
    final stableEndQuestionId = endQuestionId.isEmpty
        ? null
        : stableQuestionId(endQuestionId);
    if (stableSourceQuestionId == null) return calculation;
    return {
      ...calculation,
      'sourceQuestionId': stableSourceQuestionId,
      'endQuestionId': ?stableEndQuestionId,
    };
  }

  Map<String, dynamic> _normalizedCalculationRule(
    Map<String, dynamic> question,
  ) {
    if ('${question['type'] ?? ''}' != 'calculated') return const {};
    final raw = question['calculation'];
    final calculation = raw is Map ? Map<String, dynamic>.from(raw) : {};
    final inferred = _inferredRangeCalculation(question);
    final sourceQuestionId =
        '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? inferred['sourceQuestionId'] ?? ''}'
            .trim();
    if (sourceQuestionId.isEmpty) return const {};
    final endQuestionId =
        '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? inferred['endQuestionId'] ?? ''}'
            .trim();
    return {
      'type': 'days_since_date',
      'sourceQuestionId': sourceQuestionId,
      if (endQuestionId.isNotEmpty) 'endQuestionId': endQuestionId,
      'endFallback': '${calculation['endFallback'] ?? 'today'}',
      'inclusive': calculation['inclusive'] != false,
      'unit': 'days',
    };
  }

  Map<String, dynamic> _inferredRangeCalculation(
    Map<String, dynamic> question,
  ) {
    if ('${question['type'] ?? ''}' != 'calculated') return const {};
    final text = _builderComparableToken(
      '${question['label'] ?? ''} ${question['stableName'] ?? ''} ${question['id'] ?? ''}',
    );
    if (!text.contains('duration') && !text.contains('days')) {
      return const {};
    }

    String? firstDateByMeaning(List<String> meanings) {
      for (final candidate in _questions) {
        if ('${candidate['type'] ?? ''}' != 'date') continue;
        if (_builderQuestionMatchesMeaning(candidate, meanings)) {
          return '${candidate['id']}';
        }
      }
      return null;
    }

    if (text.contains('antimicrobial') ||
        text.contains('antibiotic') ||
        text.contains('antibiotics')) {
      final start = firstDateByMeaning(const [
        'date antimicrobial commenced',
        'date antimicrobial commencement',
        'antimicrobial commencement date',
        'date antibiotic commenced',
        'date antibiotic commencement',
        'antibiotic commencement date',
        'date antimicrobial started',
        'date antibiotic started',
      ]);
      final end = firstDateByMeaning(const [
        'date antimicrobial completed',
        'date antimicrobial completion',
        'antimicrobial completion date',
        'date antibiotic completed',
        'date antibiotic completion',
        'antibiotic completion date',
        'date antimicrobial stopped',
        'date antibiotic stopped',
      ]);
      if (start != null) {
        return {'sourceQuestionId': start, 'endQuestionId': ?end};
      }
    }

    if (text.contains('device') ||
        text.contains('catheter') ||
        text.contains('ventilator')) {
      final start = firstDateByMeaning(const [
        'date of device insertion',
        'device insertion date',
        'date device inserted',
        'date of catheter insertion',
        'catheter insertion date',
        'date of ventilator insertion',
        'ventilator insertion date',
      ]);
      final end = firstDateByMeaning(const [
        'date of device removal',
        'device removal date',
        'date device removed',
        'date of catheter removal',
        'catheter removal date',
        'date of ventilator removal',
        'ventilator removal date',
      ]);
      if (start != null) {
        return {'sourceQuestionId': start, 'endQuestionId': ?end};
      }
    }

    if (text.contains('hospital') ||
        text.contains('admission') ||
        text.contains('stay')) {
      final start = firstDateByMeaning(const [
        'date of admission',
        'admission date',
        'date admitted',
        'hospital admission date',
      ]);
      final end = firstDateByMeaning(const [
        'date of discharge',
        'discharge date',
        'date discharged',
        'hospital discharge date',
      ]);
      if (start != null) {
        return {'sourceQuestionId': start, 'endQuestionId': ?end};
      }
    }

    return const {};
  }

  List<Map<String, String>> _normalizedConditionalRules(
    Map<String, dynamic> question,
  ) {
    final rules = <Map<String, String>>[];
    final rawRules = question['showIfRules'];
    if (rawRules is List) {
      for (final raw in rawRules) {
        if (raw is! Map) continue;
        final questionId =
            '${raw['questionId'] ?? raw['showIfQuestionId'] ?? ''}'.trim();
        final value = _normalizeSkipLogicValue(
          raw['value'] ?? raw['showIfValue'],
        );
        if (questionId.isEmpty || value.isEmpty) continue;
        rules.add({
          'questionId': questionId,
          'value': _normalizeSkipLogicValue(value),
          if ('${raw['optionValue'] ?? ''}'.trim().isNotEmpty)
            'optionValue': '${raw['optionValue']}'.trim(),
        });
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = _normalizeSkipLogicValue(question['showIfValue']);
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      final exists = rules.any(
        (rule) =>
            rule['questionId'] == legacyQuestionId &&
            rule['value'] == legacyValue,
      );
      if (!exists) {
        rules.insert(0, {'questionId': legacyQuestionId, 'value': legacyValue});
      }
    }
    for (final rule in rules) {
      final questionId = rule['questionId'] ?? '';
      final parent = _questions.where(
        (item) =>
            '${item['id'] ?? ''}' == questionId ||
            '${item['stableName'] ?? ''}' == questionId,
      );
      if (parent.isEmpty) continue;
      final optionValues = parent.first['optionValues'] is Map
          ? Map<String, dynamic>.from(parent.first['optionValues'] as Map)
          : const <String, dynamic>{};
      final value = rule['value'] ?? '';
      final optionValue = '${optionValues[value] ?? ''}'.trim();
      if (optionValue.isNotEmpty) rule['optionValue'] = optionValue;
    }
    return rules;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? 'Create Surveillance'
              : widget.isBuiltInTemplate
              ? 'Edit Built-in Form'
              : 'Edit Surveillance Form',
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _previewForm,
            icon: const Icon(Icons.visibility_outlined, color: Colors.white),
            label: const Text('Preview', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Form title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description / purpose',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _importQuestionsFromSpreadsheet,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Excel questionnaire'),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _questions.length,
            onReorder: _reorderQuestion,
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey('${_questions[index]['id']}'),
              child: _buildQuestionCard(index),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add question at end'),
          ),
        ],
      ),
    );
  }

  void _previewForm() {
    _renumberQuestions();
    final title = _titleController.text.trim().isEmpty
        ? 'Surveillance form preview'
        : _titleController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _IpcFormPreviewScreen(
          title: title,
          description: _descriptionController.text.trim(),
          questions: _questions
              .where(
                (question) => '${question['label'] ?? ''}'.trim().isNotEmpty,
              )
              .map(_normalizedQuestionForSave)
              .toList(),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    final type = '${question['type'] ?? 'short_text'}';
    final id = '${question['id'] ?? index}';
    final expanded = _expandedQuestionIds.contains(id);
    final label = '${question['label'] ?? ''}'.trim();
    final displayNumber = question['displayNumber'] is int
        ? question['displayNumber'] as int
        : index + 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, expanded ? 12 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Tooltip(
                    message: 'Drag to reorder',
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _toggleQuestionExpanded(id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.isEmpty ? 'Question $displayNumber' : label,
                          maxLines: expanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _questionChip(_questionTypes[type] ?? type),
                            if (question['required'] == true)
                              _questionChip('Required'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Collapse question' : 'Expand question',
                  onPressed: () => _toggleQuestionExpanded(id),
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Insert question',
                  icon: const Icon(Icons.add_circle_outline),
                  onSelected: (value) {
                    if (value == 'above') _addQuestion(index: index);
                    if (value == 'below') _addQuestion(index: index + 1);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'above',
                      child: Text('Add question above'),
                    ),
                    PopupMenuItem(
                      value: 'below',
                      child: Text('Add question below'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Duplicate question',
                  onPressed: () => _duplicateQuestion(index),
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: 'Delete question',
                  onPressed: _questions.length == 1
                      ? null
                      : () => _confirmDeleteQuestion(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: '${question['label'] ?? ''}',
                decoration: InputDecoration(
                  labelText: 'Question $displayNumber',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  question['label'] = value;
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Question type',
                  border: OutlineInputBorder(),
                ),
                items: _questionTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => question['type'] = value);
                },
              ),
              if (type != 'sub_heading') ...[
                SwitchListTile(
                  value: question['required'] == true,
                  title: const Text('Required'),
                  onChanged: (value) =>
                      setState(() => question['required'] = value),
                ),
                if (_usesOptions(type))
                  _optionEditor(
                    question,
                    'options',
                    _isAntimicrobialBankQuestion(question)
                        ? 'Antimicrobial bank list'
                        : 'Options',
                  ),
                if (_isAntimicrobialBankQuestion(question))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'In the staff HAI form, this opens as an Add antimicrobial picker. Add or remove picker choices in the bank list above.',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (type == 'multiple_choice_grid' ||
                    type == 'tickbox_grid') ...[
                  _optionEditor(question, 'gridRows', 'Grid rows'),
                  _optionEditor(question, 'gridColumns', 'Grid columns'),
                ],
                if (type == 'linear_scale') _linearScaleEditor(question),
                if (type == 'calculated') _calculationEditor(question),
                _conditionalEditor(question),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _questionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        border: Border.all(color: Colors.teal.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
      ),
    );
  }

  void _toggleQuestionExpanded(String id) {
    setState(() {
      if (_expandedQuestionIds.contains(id)) {
        _expandedQuestionIds.remove(id);
      } else {
        _expandedQuestionIds.add(id);
      }
    });
  }

  Future<void> _confirmDeleteQuestion(int index) async {
    if (index < 0 || index >= _questions.length || _questions.length == 1) {
      return;
    }
    final question = _questions[index];
    final label = '${question['label'] ?? 'Question ${index + 1}'}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete question'),
        content: Text(
          widget.isBuiltInTemplate
              ? 'Delete "${label.isEmpty ? 'Question ${index + 1}' : label}" from this surveillance questionnaire? Existing submitted data will remain, but reports or calculations may depend on stable questions.'
              : 'Delete "${label.isEmpty ? 'Question ${index + 1}' : label}" from this form?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _expandedQuestionIds.remove('${_questions[index]['id'] ?? index}');
        _questions.removeAt(index);
        _renumberQuestions();
      });
    }
  }

  bool _usesOptions(String type) =>
      type == 'multiple_choice' || type == 'checkbox';

  Widget _calculationEditor(Map<String, dynamic> question) {
    final raw = question['calculation'];
    final calculation = raw is Map ? Map<String, dynamic>.from(raw) : {};
    final inferred = _inferredRangeCalculation(question);
    calculation['type'] = 'days_since_date';
    calculation['sourceQuestionId'] =
        '${calculation['sourceQuestionId'] ?? inferred['sourceQuestionId'] ?? ''}';
    final inferredEnd = '${inferred['endQuestionId'] ?? ''}'.trim();
    if ('${calculation['endQuestionId'] ?? ''}'.trim().isEmpty &&
        inferredEnd.isNotEmpty) {
      calculation['endQuestionId'] = inferredEnd;
    }
    calculation['endFallback'] = '${calculation['endFallback'] ?? 'today'}';
    calculation['inclusive'] = calculation['inclusive'] != false;
    question['calculation'] = calculation;
    final dateQuestions = _questions
        .where(
          (candidate) =>
              candidate['id'] != question['id'] &&
              '${candidate['type'] ?? ''}' == 'date',
        )
        .toList();
    final selectedSource = '${calculation['sourceQuestionId'] ?? ''}';
    final sourceExists =
        selectedSource.isEmpty ||
        dateQuestions.any((item) => '${item['id']}' == selectedSource);
    final selectedEnd = '${calculation['endQuestionId'] ?? ''}';
    final endExists =
        selectedEnd.isEmpty ||
        dateQuestions.any((item) => '${item['id']}' == selectedEnd);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calculation',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: sourceExists ? selectedSource : '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Start date question',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Select date question'),
              ),
              ...dateQuestions.map(
                (item) => DropdownMenuItem(
                  value: '${item['id']}',
                  child: Text(
                    '${item['label'] ?? 'Date question'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              calculation['sourceQuestionId'] = value ?? '';
              question['calculation'] = calculation;
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: endExists ? selectedEnd : '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'End date question (optional)',
              helperText: 'Leave blank to calculate up to today.',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Use today when no end date is available'),
              ),
              ...dateQuestions.map(
                (item) => DropdownMenuItem(
                  value: '${item['id']}',
                  child: Text(
                    '${item['label'] ?? 'Date question'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              final endValue = value ?? '';
              if (endValue.isEmpty) {
                calculation.remove('endQuestionId');
              } else {
                calculation['endQuestionId'] = endValue;
              }
              calculation['endFallback'] = 'today';
              question['calculation'] = calculation;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: calculation['inclusive'] != false,
            title: const Text('Count selected date as day 1'),
            onChanged: (value) => setState(() {
              calculation['inclusive'] = value;
              question['calculation'] = calculation;
            }),
          ),
        ],
      ),
    );
  }

  Widget _optionEditor(
    Map<String, dynamic> question,
    String key,
    String label,
  ) {
    final items = (question[key] as List<dynamic>? ?? []).cast<String>();
    if (items.isEmpty) items.add('');
    question[key] = items;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...List.generate(items.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: items[index],
                      decoration: InputDecoration(
                        labelText: '$label ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => items[index] = value.trim(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: items.length == 1
                        ? null
                        : () => setState(() => items.removeAt(index)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => items.add('')),
            icon: const Icon(Icons.add),
            label: Text('Add ${_singularOptionEditorLabel(label)}'),
          ),
        ],
      ),
    );
  }

  bool _isAntimicrobialBankQuestion(Map<String, dynamic> question) {
    final metadata = question['metadata'];
    return metadata is Map &&
        '${metadata['behavior'] ?? ''}' == 'antimicrobial_bank';
  }

  String _singularOptionEditorLabel(String label) {
    if (label == 'Antimicrobial bank list') return 'antimicrobial';
    final lower = label.toLowerCase();
    if (lower.endsWith('ies')) {
      return '${lower.substring(0, lower.length - 3)}y';
    }
    if (lower.endsWith('s')) return lower.substring(0, lower.length - 1);
    return lower;
  }

  Widget _linearScaleEditor(Map<String, dynamic> question) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            TextFormField(
              initialValue: '${question['scaleMin'] ?? 1}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scale min',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  question['scaleMin'] = int.tryParse(value) ?? 1,
            ),
            TextFormField(
              initialValue: '${question['scaleMax'] ?? 5}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scale max',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  question['scaleMax'] = int.tryParse(value) ?? 5,
            ),
          ];
          if (constraints.maxWidth < 420) {
            return Column(
              children: [fields.first, const SizedBox(height: 10), fields.last],
            );
          }
          return Row(
            children: [
              Expanded(child: fields.first),
              const SizedBox(width: 10),
              Expanded(child: fields.last),
            ],
          );
        },
      ),
    );
  }

  Widget _conditionalEditor(Map<String, dynamic> question) {
    final previousQuestions = _questions
        .where((candidate) => candidate['id'] != question['id'])
        .toList();
    final rules = _editableConditionalRules(question);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Skip logic',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: previousQuestions.isEmpty
                    ? null
                    : () => setState(() {
                        rules.add({'questionId': '', 'value': ''});
                        _syncLegacyConditionalFields(question, rules);
                      }),
                icon: const Icon(Icons.add),
                label: const Text('Add logic'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rules.isEmpty
                ? 'Always show this question.'
                : 'Show this question when any of these rules matches.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...List.generate(
            rules.length,
            (index) => _conditionalRuleEditor(
              question: question,
              rules: rules,
              ruleIndex: index,
              previousQuestions: previousQuestions,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _editableConditionalRules(
    Map<String, dynamic> question,
  ) {
    final rules = <Map<String, String>>[];
    final rawRules = question['showIfRules'];
    if (rawRules is List) {
      for (final raw in rawRules) {
        if (raw is! Map) continue;
        rules.add({
          'questionId': '${raw['questionId'] ?? raw['showIfQuestionId'] ?? ''}'
              .trim(),
          'value': '${raw['value'] ?? raw['showIfValue'] ?? ''}'.trim(),
          if ('${raw['optionValue'] ?? ''}'.trim().isNotEmpty)
            'optionValue': '${raw['optionValue']}'.trim(),
        });
      }
    }

    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = _normalizeSkipLogicValue(question['showIfValue']);
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      final exists = rules.any(
        (rule) =>
            rule['questionId'] == legacyQuestionId &&
            rule['value'] == legacyValue,
      );
      if (!exists) {
        rules.insert(0, {'questionId': legacyQuestionId, 'value': legacyValue});
      }
    }

    question['showIfRules'] = rules;
    _syncLegacyConditionalFields(question, rules);
    return rules;
  }

  void _syncLegacyConditionalFields(
    Map<String, dynamic> question,
    List<Map<String, String>> rules,
  ) {
    final validRules = rules
        .where(
          (rule) =>
              (rule['questionId'] ?? '').trim().isNotEmpty &&
              (rule['value'] ?? '').trim().isNotEmpty,
        )
        .toList();
    question['showIfQuestionId'] = validRules.isEmpty
        ? ''
        : validRules.first['questionId'];
    question['showIfValue'] = validRules.isEmpty
        ? ''
        : validRules.first['value'];
  }

  Widget _conditionalRuleEditor({
    required Map<String, dynamic> question,
    required List<Map<String, String>> rules,
    required int ruleIndex,
    required List<Map<String, dynamic>> previousQuestions,
  }) {
    final rule = rules[ruleIndex];
    final selectedQuestionId = rule['questionId'] ?? '';
    final selectedParent = previousQuestions.where(
      (item) => '${item['id']}' == selectedQuestionId,
    );
    final parentQuestion = selectedParent.isEmpty ? null : selectedParent.first;
    final answerChoices = parentQuestion == null
        ? const <String>[]
        : _conditionalAnswerChoices(parentQuestion);
    final selectedAnswer = rule['value'] ?? '';
    final dropdownAnswerChoices = ['__answered__', ...answerChoices];
    final normalizedAnswer = dropdownAnswerChoices.contains(selectedAnswer)
        ? selectedAnswer
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final questionSelector = DropdownButtonFormField<String>(
            value: selectedQuestionId.isEmpty ? '' : selectedQuestionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Logic ${ruleIndex + 1}: question',
              border: const OutlineInputBorder(),
            ),
            selectedItemBuilder: (context) => [
              const Text('Select question', overflow: TextOverflow.ellipsis),
              ...previousQuestions.map(
                (item) => Text(
                  '${item['label'] ?? 'Question'}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
            items: [
              const DropdownMenuItem(value: '', child: Text('Select question')),
              ...previousQuestions.map(
                (item) => DropdownMenuItem(
                  value: '${item['id']}',
                  child: Text(
                    '${item['label'] ?? 'Question'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() {
              rule['questionId'] = value ?? '';
              rule['value'] = '';
              _syncLegacyConditionalFields(question, rules);
            }),
          );
          final answerSelector = answerChoices.isEmpty
              ? DropdownButtonFormField<String>(
                  value: selectedAnswer == '__answered__' ? selectedAnswer : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                  selectedItemBuilder: (context) => const [
                    Text('Select condition', overflow: TextOverflow.ellipsis),
                    Text('Answered', overflow: TextOverflow.ellipsis),
                  ],
                  items: const [
                    DropdownMenuItem(
                      value: '',
                      child: Text('Select condition'),
                    ),
                    DropdownMenuItem(
                      value: '__answered__',
                      child: Text('Answered'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    rule['value'] = _normalizeSkipLogicValue(value);
                    _syncLegacyConditionalFields(question, rules);
                  }),
                )
              : DropdownButtonFormField<String>(
                  value: normalizedAnswer,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Answer equals',
                    border: OutlineInputBorder(),
                  ),
                  selectedItemBuilder: (context) => [
                    const Text(
                      'Select answer',
                      overflow: TextOverflow.ellipsis,
                    ),
                    ...dropdownAnswerChoices.map(
                      (answer) => Text(
                        _skipLogicValueLabel(answer),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Select answer'),
                    ),
                    ...dropdownAnswerChoices.map(
                      (answer) => DropdownMenuItem(
                        value: answer,
                        child: Text(
                          _skipLogicValueLabel(answer),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    rule['value'] = _normalizeSkipLogicValue(value);
                    _syncLegacyConditionalFields(question, rules);
                  }),
                );
          final removeButton = IconButton(
            tooltip: 'Remove logic',
            onPressed: () => setState(() {
              rules.removeAt(ruleIndex);
              _syncLegacyConditionalFields(question, rules);
            }),
            icon: const Icon(Icons.remove_circle_outline),
          );

          if (constraints.maxWidth < 680) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: questionSelector),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 8),
                answerSelector,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: questionSelector),
              const SizedBox(width: 10),
              Expanded(child: answerSelector),
              removeButton,
            ],
          );
        },
      ),
    );
  }

  List<String> _conditionalAnswerChoices(Map<String, dynamic> question) {
    final type = '${question['type'] ?? ''}';
    if (type == 'multiple_choice' || type == 'checkbox') {
      return (question['options'] as List<dynamic>? ?? [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (type == 'multiple_choice_grid' || type == 'tickbox_grid') {
      return (question['gridColumns'] as List<dynamic>? ?? [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (type == 'linear_scale') {
      final min = question['scaleMin'] is int ? question['scaleMin'] as int : 1;
      final max = question['scaleMax'] is int ? question['scaleMax'] as int : 5;
      return [for (var value = min; value <= max; value += 1) value.toString()];
    }
    return const [];
  }
}

class _IpcFormPreviewScreen extends StatefulWidget {
  final String title;
  final String description;
  final List<Map<String, dynamic>> questions;

  const _IpcFormPreviewScreen({
    required this.title,
    required this.description,
    required this.questions,
  });

  @override
  State<_IpcFormPreviewScreen> createState() => _IpcFormPreviewScreenState();
}

class _IpcFormPreviewScreenState extends State<_IpcFormPreviewScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isVisible(Map<String, dynamic> question) {
    final relevant = '${question['relevant'] ?? ''}'.trim();
    if (relevant.isNotEmpty && !_previewRelevantMatches(relevant)) {
      return false;
    }
    final rules = _conditionalRulesForPreview(question);
    if (rules.isEmpty) return true;
    return rules.any(_conditionalRuleMatches);
  }

  bool _previewRelevantMatches(String relevant) {
    return relevant
        .split(RegExp(r'\s+or\s+', caseSensitive: false))
        .any(
          (orClause) => orClause
              .split(RegExp(r'\s+and\s+', caseSensitive: false))
              .every(_previewRelevantConditionMatches),
        );
  }

  bool _previewRelevantConditionMatches(String clause) {
    final selectedMatch =
        RegExp(
          r"""selected\(\$\{([^}]+)\},\s*'((?:\\.|[^'])*)'\)""",
        ).firstMatch(clause) ??
        RegExp(
          r'''selected\(\$\{([^}]+)\},\s*"((?:\\.|[^"])*)"\)''',
        ).firstMatch(clause);
    if (selectedMatch != null) {
      return _previewAnswerMatchesExpected(
        selectedMatch.group(1) ?? '',
        _previewRelevantLiteral(selectedMatch.group(2)),
      );
    }

    final equalsMatch =
        RegExp(
          r"""\$\{([^}]+)\}\s*(!=|=)\s*'((?:\\.|[^'])*)'""",
        ).firstMatch(clause) ??
        RegExp(
          r'''\$\{([^}]+)\}\s*(!=|=)\s*"((?:\\.|[^"])*)"''',
        ).firstMatch(clause);
    if (equalsMatch == null) return false;
    final matches = _previewAnswerMatchesExpected(
      equalsMatch.group(1) ?? '',
      _previewRelevantLiteral(equalsMatch.group(3)),
    );
    return equalsMatch.group(2) == '!=' ? !matches : matches;
  }

  String _previewRelevantLiteral(String? value) => (value ?? '')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\');

  bool _previewAnswerMatchesExpected(String fieldId, String expected) {
    final value = _answers[fieldId];
    final expectedText = expected.trim();
    if (value == null) return expectedText.isEmpty;
    if (value is Iterable) {
      if (value.isEmpty) return expectedText.isEmpty;
      return value.any(
        (item) => _previewValueMatches(fieldId, item, expectedText),
      );
    }
    return '$value'
        .split(',')
        .map((item) => item.trim())
        .any((item) => _previewValueMatches(fieldId, item, expectedText));
  }

  bool _previewValueMatches(String fieldId, Object? value, String expected) {
    final valueText = '${value ?? ''}'.trim();
    if (expected.isEmpty) return valueText.isEmpty;
    if (_previewComparableToken(valueText) ==
        _previewComparableToken(expected)) {
      return true;
    }
    Map<String, dynamic>? question;
    for (final candidate in widget.questions) {
      if ('${candidate['id'] ?? ''}' == fieldId) {
        question = candidate;
        break;
      }
    }
    if (question == null) return false;
    final optionValues = question['optionValues'] is Map
        ? Map<String, dynamic>.from(question['optionValues'] as Map)
        : const <String, dynamic>{};
    for (final optionLabel in _stringList(question['options'])) {
      final optionValue = '${optionValues[optionLabel] ?? optionLabel}';
      final answerMatchesOption =
          _previewComparableToken(valueText) ==
              _previewComparableToken(optionLabel) ||
          _previewComparableToken(valueText) ==
              _previewComparableToken(optionValue);
      if (!answerMatchesOption) continue;
      return _previewComparableToken(expected) ==
              _previewComparableToken(optionLabel) ||
          _previewComparableToken(expected) ==
              _previewComparableToken(optionValue);
    }
    return false;
  }

  String _previewComparableToken(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  List<Map<String, String>> _conditionalRulesForPreview(
    Map<String, dynamic> question,
  ) {
    final rules = <Map<String, String>>[];
    final rawRules = question['showIfRules'];
    if (rawRules is List) {
      for (final raw in rawRules) {
        if (raw is! Map) continue;
        final questionId =
            '${raw['questionId'] ?? raw['showIfQuestionId'] ?? ''}'.trim();
        final value = _normalizeSkipLogicPreviewValue(
          raw['value'] ?? raw['showIfValue'],
        );
        if (questionId.isEmpty || value.isEmpty) continue;
        rules.add({'questionId': questionId, 'value': value});
      }
    }
    final legacyQuestionId = '${question['showIfQuestionId'] ?? ''}'.trim();
    final legacyValue = _normalizeSkipLogicPreviewValue(
      question['showIfValue'],
    );
    if (legacyQuestionId.isNotEmpty && legacyValue.isNotEmpty) {
      final exists = rules.any(
        (rule) =>
            rule['questionId'] == legacyQuestionId &&
            rule['value'] == legacyValue,
      );
      if (!exists) {
        rules.add({'questionId': legacyQuestionId, 'value': legacyValue});
      }
    }
    return rules;
  }

  bool _conditionalRuleMatches(Map<String, String> rule) {
    final parentId = (rule['questionId'] ?? '').trim();
    final expected = (rule['value'] ?? '').trim().toLowerCase();
    if (parentId.isEmpty || expected.isEmpty) return false;
    final value = _answers[parentId];
    if (expected == '__answered__') return _hasSkipLogicAnswer(value);
    if (value is List) {
      return value.map((item) => '$item'.toLowerCase()).contains(expected);
    }
    return '$value'.trim().toLowerCase() == expected;
  }

  String _normalizeSkipLogicPreviewValue(Object? value) {
    final text = '${value ?? ''}'.trim();
    final normalized = text.toLowerCase();
    if (normalized == 'answered' ||
        normalized == 'is answered' ||
        normalized == 'any answer' ||
        normalized == 'not blank' ||
        normalized == '__answered__') {
      return '__answered__';
    }
    return text;
  }

  bool _hasSkipLogicAnswer(Object? value) {
    if (value == null) return false;
    if (value is Iterable) return value.isNotEmpty;
    final text = '$value'.trim();
    return text.isNotEmpty && text != 'null';
  }

  DateTime? _dateFromPreviewAnswer(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _daysBetweenDates(
    DateTime startDate,
    DateTime endDate, {
    required bool inclusive,
  }) {
    final start = _startOfDay(startDate);
    final end = _startOfDay(endDate);
    final days = end.difference(start).inDays + (inclusive ? 1 : 0);
    return '${days < 0 ? 0 : days}';
  }

  void _syncPreviewCalculations() {
    for (final question in widget.questions) {
      final id = '${question['id'] ?? ''}'.trim();
      if (id.isEmpty || '${question['type'] ?? ''}' != 'calculated') {
        continue;
      }
      if (!_isVisible(question)) {
        _answers.remove(id);
        continue;
      }
      final rawCalculation = question['calculation'];
      final calculation = rawCalculation is Map
          ? Map<String, dynamic>.from(rawCalculation)
          : const <String, dynamic>{};
      if ('${calculation['type'] ?? ''}' != 'days_since_date') continue;
      final sourceQuestionId =
          '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? ''}'
              .trim();
      if (sourceQuestionId.isEmpty) continue;
      final sourceDate = _dateFromPreviewAnswer(_answers[sourceQuestionId]);
      if (sourceDate == null) {
        _answers.remove(id);
        continue;
      }
      final endQuestionId =
          '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
              .trim();
      final endDate = endQuestionId.isEmpty
          ? null
          : _dateFromPreviewAnswer(_answers[endQuestionId]);
      _answers[id] = _daysBetweenDates(
        sourceDate,
        endDate ?? DateTime.now(),
        inclusive: calculation['inclusive'] != false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncPreviewCalculations();
    final visibleQuestions = widget.questions.where(_isVisible).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Form'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.description),
          ],
          const SizedBox(height: 16),
          if (visibleQuestions.isEmpty)
            const Text('No questions available for preview.'),
          ...visibleQuestions.map(_previewQuestion),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Preview only. No data was submitted.'),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Test final submit'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickPreviewListItem({
    required String title,
    required List<String> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options.where((option) {
              final needle = query.trim().toLowerCase();
              return needle.isEmpty || option.toLowerCase().contains(needle);
            }).toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching item'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(option),
                                  onTap: () => Navigator.pop(context, option),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _previewQuestion(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final label = '${question['label'] ?? 'Question'}';
    final type = '${question['type'] ?? 'short_text'}';
    final required = question['required'] == true;
    final options = _stringList(question['options']);
    final metadata = question['metadata'] is Map
        ? Map<String, dynamic>.from(question['metadata'] as Map)
        : const <String, dynamic>{};
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
      style: const TextStyle(fontWeight: FontWeight.w600),
    );

    Widget field;
    if ('${metadata['behavior'] ?? ''}' == 'antimicrobial_bank') {
      final selected = (_answers[id] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList();
      final available = options
          .where((option) => !selected.contains(option))
          .toList();
      field = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: available.isEmpty
                ? null
                : () async {
                    final picked = await _pickPreviewListItem(
                      title:
                          '${metadata['selectionTitle'] ?? 'Select antimicrobial'}',
                      options: available,
                    );
                    if (picked == null) return;
                    setState(() {
                      selected.add(picked);
                      _answers[id] = selected;
                      _syncPreviewCalculations();
                    });
                  },
            icon: const Icon(Icons.add),
            label: Text('${metadata['addButtonLabel'] ?? 'Add antimicrobial'}'),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      onDeleted: () => setState(() {
                        selected.remove(item);
                        _answers[id] = selected;
                        _syncPreviewCalculations();
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      );
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: field);
    }

    if ('${metadata['behavior'] ?? ''}' == 'repeat_group') {
      final selected = (_answers[id] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList();
      final detailsKey = '${metadata['detailsAnswerKey'] ?? '${id}_details'}';
      final rawDetails = _answers[detailsKey] is Map
          ? Map<String, dynamic>.from(_answers[detailsKey] as Map)
          : <String, dynamic>{};
      final childFields = (metadata['childFields'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      field = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                final itemId = '${id}_${DateTime.now().microsecondsSinceEpoch}';
                selected.add(itemId);
                rawDetails[itemId] = <String, dynamic>{
                  '__title':
                      '${metadata['itemTitlePrefix'] ?? 'Item'} ${selected.length}',
                };
                _answers[id] = selected;
                _answers[detailsKey] = rawDetails;
              }),
              icon: const Icon(Icons.add),
              label: Text('${metadata['addButtonLabel'] ?? 'Add'}'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: Colors.teal.shade800,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...selected.map((itemId) {
              final itemDetails = rawDetails[itemId] is Map
                  ? Map<String, dynamic>.from(rawDetails[itemId] as Map)
                  : <String, dynamic>{};
              return Container(
                key: ValueKey('$detailsKey-preview-card-$itemId'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${itemDetails['__title'] ?? itemId}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => setState(() {
                            selected.remove(itemId);
                            rawDetails.remove(itemId);
                            _answers[id] = selected;
                            _answers[detailsKey] = rawDetails;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...childFields.map(
                      (child) => _previewRepeatChildField(
                        detailsKey: detailsKey,
                        itemId: itemId,
                        allDetails: rawDetails,
                        child: child,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: field);
    }

    switch (type) {
      case 'sub_heading':
        field = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            border: Border(
              left: BorderSide(color: Colors.teal.shade700, width: 4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.teal.shade900,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      case 'multiple_choice':
        field = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            ...options.map(
              (option) => RadioListTile<String>(
                dense: true,
                title: Text(option),
                value: option,
                groupValue: _answers[id] as String?,
                onChanged: (value) => setState(() {
                  _answers[id] = value;
                  _syncPreviewCalculations();
                }),
              ),
            ),
          ],
        );
        break;
      case 'checkbox':
        final selected = (_answers[id] as List<dynamic>? ?? []).cast<String>();
        field = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            ...options.map(
              (option) => CheckboxListTile(
                dense: true,
                title: Text(option),
                value: selected.contains(option),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    selected.add(option);
                  } else {
                    selected.remove(option);
                  }
                  _answers[id] = selected;
                  _syncPreviewCalculations();
                }),
              ),
            ),
          ],
        );
        break;
      case 'long_text':
        field = _textPreviewField(id, label, minLines: 3, maxLines: 6);
        break;
      case 'number':
        field = _textPreviewField(
          id,
          label,
          keyboardType: TextInputType.number,
        );
        break;
      case 'calculated':
        field = _textPreviewField(
          id,
          label,
          readOnly: true,
          keyboardType: TextInputType.number,
          suffixText: 'days',
        );
        break;
      case 'date':
        field = _dateTimePreviewField(id, label, isDate: true);
        break;
      case 'time':
        field = _dateTimePreviewField(id, label, isDate: false);
        break;
      case 'file_upload':
        field = ListTile(
          contentPadding: EdgeInsets.zero,
          title: title,
          subtitle: const Text('File upload placeholder'),
          trailing: const Icon(Icons.upload_file_outlined),
          onTap: () => setState(() => _answers[id] = 'Preview file selected'),
        );
        break;
      case 'linear_scale':
        field = _linearScalePreview(question);
        break;
      case 'multiple_choice_grid':
      case 'tickbox_grid':
        field = _gridPreview(question);
        break;
      case 'short_text':
      default:
        field = _textPreviewField(id, label);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: field);
  }

  String? _previewRepeatCalculatedValue({
    required Map<String, dynamic> child,
    required Map<String, dynamic> details,
  }) {
    final calculation = child['calculation'] is Map
        ? Map<String, dynamic>.from(child['calculation'] as Map)
        : const <String, dynamic>{};
    if ('${calculation['type'] ?? ''}' != 'days_since_date') return null;
    final sourceQuestionId =
        '${calculation['sourceQuestionId'] ?? calculation['sourceQuestion'] ?? ''}'
            .trim();
    if (sourceQuestionId.isEmpty) return null;
    final sourceDate = _dateFromPreviewAnswer(details[sourceQuestionId]);
    if (sourceDate == null) return null;
    final endQuestionId =
        '${calculation['endQuestionId'] ?? calculation['endQuestion'] ?? ''}'
            .trim();
    final endDate = endQuestionId.isEmpty
        ? null
        : _dateFromPreviewAnswer(details[endQuestionId]);
    return _daysBetweenDates(
      sourceDate,
      endDate ?? DateTime.now(),
      inclusive: calculation['inclusive'] != false,
    );
  }

  Widget _previewRepeatChildField({
    required String detailsKey,
    required String itemId,
    required Map<String, dynamic> allDetails,
    required Map<String, dynamic> child,
  }) {
    final key = '${child['key'] ?? ''}';
    if (key.isEmpty) return const SizedBox.shrink();
    final label = '${child['label'] ?? key}';
    final type = '${child['type'] ?? 'short_text'}';
    final required = child['required'] == true;
    final itemDetails = allDetails[itemId] is Map
        ? Map<String, dynamic>.from(allDetails[itemId] as Map)
        : <String, dynamic>{};
    final decoration = InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    );

    void updateValue(Object? value) {
      itemDetails[key] = value;
      allDetails[itemId] = itemDetails;
      _answers[detailsKey] = allDetails;
    }

    if (type == 'calculated') {
      final calculatedValue = _previewRepeatCalculatedValue(
        child: child,
        details: itemDetails,
      );
      if (calculatedValue != null) updateValue(calculatedValue);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: ValueKey('$detailsKey-$itemId-$key-calculated-$calculatedValue'),
          initialValue: calculatedValue ?? '${itemDetails[key] ?? ''}',
          readOnly: true,
          decoration: decoration.copyWith(
            suffixIcon: const Icon(Icons.calculate_outlined),
          ),
        ),
      );
    }

    if (type == 'select' || type == 'multiple_choice') {
      final labels = _stringList(child['options']);
      final optionValues = child['optionValues'] is Map
          ? Map<String, dynamic>.from(child['optionValues'] as Map)
          : const <String, dynamic>{};
      final currentValue = '${itemDetails[key] ?? ''}';
      final values = <String>{};
      final menuItems = <DropdownMenuItem<String>>[];
      for (final option in labels) {
        final value = '${optionValues[option] ?? option}';
        if (!values.add(value)) continue;
        menuItems.add(
          DropdownMenuItem<String>(
            value: value,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
        );
      }
      if (labels.length > 12) {
        final selectedLabel = labels.where((option) {
          return '${optionValues[option] ?? option}' == currentValue;
        }).firstOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InputDecorator(
            decoration: decoration,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(selectedLabel ?? 'Select an option'),
              trailing: const Icon(Icons.search),
              onTap: () async {
                final picked = await _pickPreviewListItem(
                  title: label,
                  options: labels,
                );
                if (picked == null) return;
                setState(
                  () => updateValue('${optionValues[picked] ?? picked}'),
                );
              },
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$detailsKey-$itemId-$key-select'),
          value: values.contains(currentValue) ? currentValue : null,
          isExpanded: true,
          decoration: decoration,
          items: menuItems,
          onChanged: (value) => setState(() => updateValue(value)),
        ),
      );
    }

    if (type == 'checkbox' || type == 'multiselect') {
      final selected = (itemDetails[key] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toSet();
      final labels = _stringList(child['options']);
      final optionValues = child['optionValues'] is Map
          ? Map<String, dynamic>.from(child['optionValues'] as Map)
          : const <String, dynamic>{};
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: decoration,
          child: Column(
            children: labels.map((option) {
              final value = '${optionValues[option] ?? option}';
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(option),
                value: selected.contains(value),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    selected.add(value);
                  } else {
                    selected.remove(value);
                  }
                  updateValue(selected.toList());
                }),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (type == 'date') {
      final parsed = _dateFromPreviewAnswer(itemDetails[key]);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: decoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: parsed ?? DateTime.now(),
                );
                if (picked == null) return;
                setState(() {
                  updateValue(picked.toIso8601String().split('T').first);
                });
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                parsed == null
                    ? 'Select date'
                    : parsed.toIso8601String().split('T').first,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: ValueKey('$detailsKey-$itemId-$key-text'),
        initialValue: '${itemDetails[key] ?? ''}',
        keyboardType: type == 'number' ? TextInputType.number : null,
        minLines: type == 'long_text' ? 2 : 1,
        maxLines: type == 'long_text' ? 4 : 1,
        decoration: decoration,
        onChanged: (value) => setState(() => updateValue(value)),
      ),
    );
  }

  Widget _textPreviewField(
    String id,
    String label, {
    int minLines = 1,
    int maxLines = 2,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? suffixText,
  }) {
    final controller = _controllers.putIfAbsent(
      id,
      () => TextEditingController(text: '${_answers[id] ?? ''}'),
    );
    if (readOnly && controller.text != '${_answers[id] ?? ''}') {
      controller.text = '${_answers[id] ?? ''}';
    }
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: suffixText,
      ),
      onChanged: readOnly
          ? null
          : (value) => setState(() {
              _answers[id] = value;
              _syncPreviewCalculations();
            }),
    );
  }

  Widget _dateTimePreviewField(
    String id,
    String label, {
    required bool isDate,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text('${_answers[id] ?? 'Not selected'}'),
      trailing: Icon(isDate ? Icons.calendar_today : Icons.schedule),
      onTap: () async {
        if (isDate) {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _answers[id] = picked.toIso8601String().split('T').first;
              _syncPreviewCalculations();
            });
          }
        } else {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null && mounted) {
            setState(() {
              _answers[id] = picked.format(context);
              _syncPreviewCalculations();
            });
          }
        }
      },
    );
  }

  Widget _linearScalePreview(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final min = question['scaleMin'] is int ? question['scaleMin'] as int : 1;
    final max = question['scaleMax'] is int ? question['scaleMax'] as int : 5;
    final value = ((_answers[id] as num?)?.toDouble() ?? min.toDouble()).clamp(
      min.toDouble(),
      max.toDouble(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${question['label']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min).abs(),
          value: value,
          label: '${value.round()}',
          onChanged: (newValue) => setState(() {
            _answers[id] = newValue.round();
            _syncPreviewCalculations();
          }),
        ),
      ],
    );
  }

  Widget _gridPreview(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final rows = _stringList(question['gridRows']);
    final columns = _stringList(question['gridColumns']);
    final tickbox = question['type'] == 'tickbox_grid';
    final answers = Map<String, dynamic>.from(
      _answers[id] as Map? ?? const <String, dynamic>{},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${question['label']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        ...rows.map(
          (row) => Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    row,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ...columns.map((column) {
                  final selected = (answers[row] as List<dynamic>? ?? [])
                      .cast<String>();
                  return tickbox
                      ? CheckboxListTile(
                          dense: true,
                          title: Text(column),
                          value: selected.contains(column),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              selected.add(column);
                            } else {
                              selected.remove(column);
                            }
                            answers[row] = selected;
                            _answers[id] = answers;
                            _syncPreviewCalculations();
                          }),
                        )
                      : RadioListTile<String>(
                          dense: true,
                          title: Text(column),
                          value: column,
                          groupValue: answers[row] as String?,
                          onChanged: (value) => setState(() {
                            answers[row] = value;
                            _answers[id] = answers;
                            _syncPreviewCalculations();
                          }),
                        );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
