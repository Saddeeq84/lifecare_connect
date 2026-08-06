import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AncPncChecklistScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String checklistType; // 'ANC' or 'PNC'

  const AncPncChecklistScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.checklistType,
  });

  @override
  State<AncPncChecklistScreen> createState() => _AncPncChecklistScreenState();
}

class _AncPncChecklistScreenState extends State<AncPncChecklistScreen> {
  DateTime? selectedFollowUpDate;
  late Map<String, Map<String, List<String>>> groupedSections;
  late List<String> sectionOrder;
  late Map<String, List<bool>> checkedMap;
  final TextEditingController followUpPlanController = TextEditingController();
  final TextEditingController followUpDateController = TextEditingController();
  final TextEditingController followUpNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    groupedSections = {
      'ANC': {
        'Screening & Assessment': [
          'Blood Pressure Checked',
          'Weight Measured',
          'Urine Test for Protein/Sugar',
          'Blood Test (Hemoglobin, HIV, Syphilis)',
          'Screening for Gestational Diabetes',
          'Screening for Pre-eclampsia',
          'Assessment of Fetal Growth',
          'Assessment of Fetal Presentation',
          'Assessment of Amniotic Fluid Volume',
          'Screening for Sexually Transmitted Infections (STIs)',
        ],
        'Clinical Care': [
          'Iron/Folic Acid Tablets Given',
          'Tetanus Toxoid Immunization',
          'Abdominal Examination',
          'Fetal Heart Rate Checked',
          'Malaria Prevention (if endemic)',
        ],
        'Education & Counseling': [
          'Diet and Nutrition Counseling',
          'Birth Preparedness Counseling',
          'Danger Signs Explained',
          'Hygiene and Rest Advice',
          'Family Planning Counseling',
          'Education on Birth Spacing',
          'Education on Early Initiation of Breastfeeding',
          'Education on Postpartum Care',
        ],
        'Follow-up & Documentation': [
          'Follow-up Visit Scheduled',
          'Assessment of Maternal Mental Health',
          'Review of Medication Use',
          'Assessment of Social Support',
          'Referral to Specialist (if needed)',
          'Documentation of All Findings',
        ],
      },
      'PNC': {
        'Mother Assessment': [
          'Mother’s General Health Checked',
          'Maternal Mental Health Screening',
          'Assessment of Uterine Involution',
          'Assessment of Lochia',
          'Screening for Postpartum Hemorrhage',
          'Screening for Infection (Mother and Baby)',
          'Nutrition and Rest Advice',
          'Danger Signs Explained',
          'Hygiene Advice',
          'Assessment of Maternal Sleep and Rest',
          'Assessment of Social Support',
        ],
        'Baby Assessment': [
          'Baby’s General Health Checked',
          'Assessment of Baby’s Weight Gain',
          'Assessment of Baby’s Feeding',
          'Screening for Jaundice in Baby',
        ],
        'Education & Counseling': [
          'Breastfeeding Counseling',
          'Support for Exclusive Breastfeeding',
          'Education on Newborn Danger Signs',
          'Education on Maternal Danger Signs',
          'Education on Infant Immunization Schedule',
          'Education on Maternal Nutrition',
          'Education on Family Planning Options',
        ],
        'Follow-up & Documentation': [
          'Cord Care Explained',
          'Immunization Advice',
          'Postpartum Family Planning',
          'Follow-up Visit Scheduled',
          'Referral to Specialist (if needed)',
          'Documentation of All Findings',
        ],
      },
    };
    sectionOrder = groupedSections[widget.checklistType]!.keys.toList();
    checkedMap = {};
    for (var section in sectionOrder) {
      checkedMap[section] = List.filled(
        groupedSections[widget.checklistType]![section]!.length,
        false,
      );
    }
  }

  void _saveChecklist() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Save'),
          content: const Text('Are you sure you want to save the checklist?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                _performSaveChecklist();
              },
            ),
          ],
        );
      },
    );
  }

  void _performSaveChecklist() {
    // Prepare checklist data
    final Map<String, dynamic> checklistData = {
      'patientId': widget.patientId,
      'patientName': widget.patientName,
      'checklistType': widget.checklistType,
      'timestamp': FieldValue.serverTimestamp(),
      'followUpPlan': followUpPlanController.text,
      'followUpDate': followUpDateController.text,
      'followUpNotes': followUpNotesController.text,
      'sections': {
        for (var section in sectionOrder)
          section: List.generate(
            groupedSections[widget.checklistType]![section]!.length,
            (i) => {
              'item': groupedSections[widget.checklistType]![section]![i],
              'checked': checkedMap[section]![i],
            },
          ),
      },
    };

    // Save to Firestore 'health_records' collection
    FirebaseFirestore.instance
        .collection('health_records')
        .add(checklistData)
        .then((_) {
          setState(() {
            // Clear all checkboxes
            for (var section in sectionOrder) {
              checkedMap[section] = List.filled(
                groupedSections[widget.checklistType]![section]!.length,
                false,
              );
            }
            // Clear text fields
            followUpPlanController.clear();
            followUpDateController.clear();
            followUpNotesController.clear();
            selectedFollowUpDate = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checklist saved to health_records!')),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error saving checklist: '
                '${error.toString()}',
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.checklistType == 'ANC' ? 'ANC' : 'PNC'} Checklist',
        ),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient: ${widget.patientName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Patient ID: ${widget.patientId}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              widget.checklistType == 'ANC'
                  ? 'Antenatal Care (ANC) Checklist'
                  : 'Postnatal Care (PNC) Checklist',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            ...sectionOrder.map(
              (section) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    groupedSections[widget.checklistType]![section]!.length,
                    (index) {
                      final item =
                          groupedSections[widget
                              .checklistType]![section]![index];
                      return CheckboxListTile(
                        title: Text(item),
                        value: checkedMap[section]![index],
                        onChanged: (val) {
                          setState(() {
                            checkedMap[section]![index] = val ?? false;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Follow-up Plan:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            TextField(
              controller: followUpPlanController,
              decoration: const InputDecoration(
                hintText: 'Describe follow-up actions or advice',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Next Visit Date:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedFollowUpDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setState(() {
                    selectedFollowUpDate = picked;
                    followUpDateController.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: IgnorePointer(
                child: TextField(
                  controller: followUpDateController,
                  decoration: const InputDecoration(
                    hintText: 'Select date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Additional Notes:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            TextField(
              controller: followUpNotesController,
              decoration: const InputDecoration(
                hintText: 'Any extra notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveChecklist,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save Checklist'),
            ),
          ],
        ),
      ),
    );
  }
}
