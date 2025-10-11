// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_constructors_in_immutables, prefer_final_fields, prefer_const_literals_to_create_immutables, await_only_futures, avoid_print, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// If you use named routes elsewhere, ensure this screen is registered in your main router.
// Example for go_router or Navigator:
// routes: {
//   '/chwAncPncConsultation': (context) => CHWAncPncConsultationScreen(...),
// }

class CHWAncPncConsultationScreen extends StatefulWidget {
  final String appointmentId;
  final String patientName;
  final String patientId;
  final String appointmentType;

  CHWAncPncConsultationScreen({
    super.key,
    required this.appointmentId,
    required this.patientName,
    required this.patientId,
    required this.appointmentType,
  });

  @override
  State<CHWAncPncConsultationScreen> createState() =>
      _CHWAncPncConsultationScreenState();
}

class _CHWAncPncConsultationScreenState
    extends State<CHWAncPncConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  // Vitals fields
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _tempController = TextEditingController();
  final _pulseController = TextEditingController();
  // Other fields
  final _statusController = TextEditingController();
  final _counselingController = TextEditingController();
  final _notesController = TextEditingController();

  // Selectable lists
  List<String> _selectedDangerSigns = [];
  String _otherDangerSign = '';
  List<String> _selectedPrescriptions = [];
  String _otherPrescription = '';
  List<String> _selectedLabTests = [];
  String _otherLabTest = '';
  List<String> _selectedRadiology = [];
  String _otherRadiology = '';

  // Counseling notes dropdown
  List<String> _selectedCounselingNotes = [];
  String _otherCounselingNote = '';

  String _vitalsWarning = '';
  String _labWarning = '';

  @override
  void initState() {
    super.initState();
    _bpSystolicController.addListener(_checkVitals);
    _bpDiastolicController.addListener(_checkVitals);
    _tempController.addListener(_checkVitals);
    _pulseController.addListener(_checkVitals);
    // Lab test warning can be implemented if needed
  }

  void _checkVitals() {
    String warning = '';
    final systolic = int.tryParse(_bpSystolicController.text) ?? 0;
    final diastolic = int.tryParse(_bpDiastolicController.text) ?? 0;
    final temp = double.tryParse(_tempController.text) ?? 0;
    final pulse = int.tryParse(_pulseController.text) ?? 0;
    if (systolic >= 140 || diastolic >= 90) {
      warning += 'High blood pressure detected. Refer or monitor closely.\n';
    } else if (systolic < 90 || diastolic < 60) {
      warning += 'Low blood pressure detected. Assess for shock.\n';
    }
    if (temp >= 38.0) {
      warning += 'Fever detected. Assess for infection.\n';
    } else if (temp < 36.0 && temp > 0) {
      warning += 'Low temperature detected. Assess for hypothermia.\n';
    }
    if (pulse > 100) {
      warning +=
          'Tachycardia detected. Assess for dehydration, infection, or distress.\n';
    } else if (pulse < 60 && pulse > 0) {
      warning += 'Bradycardia detected. Assess for underlying causes.\n';
    }
    setState(() {
      _vitalsWarning = warning.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacementNamed('/');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.appointmentType.toUpperCase()} Consultation'),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Patient: ${widget.patientName}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Appointment ID: ${widget.appointmentId}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Consultation Type: ${widget.appointmentType}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'ANC/PNC Consultation Form',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Vital Signs',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bpSystolicController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'BP Systolic',
                            hintText: 'e.g. 120',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _bpDiastolicController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'BP Diastolic',
                            hintText: 'e.g. 80',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tempController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Temperature (°C)',
                            hintText: 'e.g. 37.0',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _pulseController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Pulse (bpm)',
                            hintText: 'e.g. 72',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_vitalsWarning.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text(
                        _vitalsWarning,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _statusController,
                    decoration: InputDecoration(
                      labelText:
                          widget.appointmentType.toLowerCase().contains('anc')
                          ? 'Pregnancy Status'
                          : 'Postnatal Status',
                      hintText:
                          widget.appointmentType.toLowerCase().contains('anc')
                          ? 'Gestational age, EDD, etc.'
                          : 'Mother and baby status',
                      prefixIcon: Icon(Icons.pregnant_woman),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MultiSelectDropdown(
                          label: 'Danger Signs',
                          options: [
                            'Bleeding',
                            'Severe pain',
                            'Fever',
                            'Convulsions',
                            'Loss of consciousness',
                            'Severe headache',
                            'Blurred vision',
                            'Swelling of hands/face',
                          ],
                          selected: _selectedDangerSigns,
                          onChanged: (selected) {
                            setState(() {
                              _selectedDangerSigns = selected;
                            });
                          },
                          otherValue: _otherDangerSign,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Add custom danger sign',
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            // rootNavigator: true removed for compatibility
                            builder: (ctx) {
                              String tempOther = '';
                              return AlertDialog(
                                title: Text('Add Custom Danger Sign'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom danger sign',
                                  ),
                                  onChanged: (val) {
                                    tempOther = val;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(tempOther);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.trim().isNotEmpty) {
                            setState(() {
                              _otherDangerSign = result.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MultiSelectDropdown(
                          label: 'Basic Counseling Notes',
                          options: [
                            'Nutrition',
                            'Hygiene',
                            'Birth preparedness',
                            'Family planning',
                            'Danger sign education',
                            'Breastfeeding',
                            'Immunization',
                            'Mental health',
                            'Newborn care',
                          ],
                          selected: _selectedCounselingNotes,
                          onChanged: (selected) {
                            setState(() {
                              _selectedCounselingNotes = selected;
                            });
                          },
                          otherValue: _otherCounselingNote,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Add custom counseling note',
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            // rootNavigator: true removed for compatibility
                            builder: (ctx) {
                              String tempOther = '';
                              return AlertDialog(
                                title: Text('Add Custom Counseling Note'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom counseling topic',
                                  ),
                                  onChanged: (val) {
                                    tempOther = val;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(tempOther);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.trim().isNotEmpty) {
                            setState(() {
                              _otherCounselingNote = result.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _counselingController,
                    decoration: InputDecoration(
                      labelText: 'Additional Counseling Notes',
                      hintText: 'Add details or topics not listed above.',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MultiSelectDropdown(
                          label: 'Prescriptions',
                          options: [
                            'Iron',
                            'Folic acid',
                            'Antimalarials',
                            'Antibiotics',
                            'Antihypertensives',
                            'Pain relief',
                          ],
                          selected: _selectedPrescriptions,
                          onChanged: (selected) {
                            setState(() {
                              _selectedPrescriptions = selected;
                            });
                          },
                          otherValue: _otherPrescription,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Add custom prescription',
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            // rootNavigator: true removed for compatibility
                            builder: (ctx) {
                              String tempOther = '';
                              return AlertDialog(
                                title: Text('Add Custom Prescription'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom medication',
                                  ),
                                  onChanged: (val) {
                                    tempOther = val;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(tempOther);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.trim().isNotEmpty) {
                            setState(() {
                              _otherPrescription = result.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MultiSelectDropdown(
                          label: 'Lab Tests',
                          options: [
                            'Malaria',
                            'Hemoglobin',
                            'Urinalysis',
                            'Blood sugar',
                            'HIV',
                            'Syphilis',
                          ],
                          selected: _selectedLabTests,
                          onChanged: (selected) {
                            setState(() {
                              _selectedLabTests = selected;
                            });
                          },
                          otherValue: _otherLabTest,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Add custom lab test',
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            // rootNavigator: true removed for compatibility
                            builder: (ctx) {
                              String tempOther = '';
                              return AlertDialog(
                                title: Text('Add Custom Lab Test'),
                                content: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom lab test',
                                  ),
                                  onChanged: (val) {
                                    tempOther = val;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(tempOther);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.trim().isNotEmpty) {
                            setState(() {
                              _otherLabTest = result.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_labWarning.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text(
                        _labWarning,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MultiSelectDropdown(
                          label: 'Radiological Investigations',
                          options: ['Ultrasound', 'X-ray', 'CT scan', 'MRI'],
                          selected: _selectedRadiology,
                          onChanged: (selected) {
                            setState(() {
                              _selectedRadiology = selected;
                            });
                          },
                          otherValue: _otherRadiology,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add),
                        tooltip: 'Add custom radiological investigation',
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            // rootNavigator: true removed for compatibility
                            builder: (ctx) {
                              String tempOther = '';
                              return AlertDialog(
                                title: Text(
                                  'Add Custom Radiological Investigation',
                                ),
                                content: TextField(
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Enter custom investigation',
                                  ),
                                  onChanged: (val) {
                                    tempOther = val;
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(tempOther);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.trim().isNotEmpty) {
                            setState(() {
                              _otherRadiology = result.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Additional Notes',
                      hintText: 'Any other observations or instructions',
                      prefixIcon: Icon(Icons.note_add),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text('Save Consultation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          final now = DateTime.now();
                          final healthRecordData = {
                            'appointmentId': widget.appointmentId,
                            'patientId': widget.patientId,
                            'patientName': widget.patientName,
                            'chwId':
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                            'consultationType': widget.appointmentType,
                            'vitals':
                                'BP: ${_bpSystolicController.text}/${_bpDiastolicController.text}, Temp: ${_tempController.text}, Pulse: ${_pulseController.text}',
                            'status': _statusController.text.trim(),
                            'dangerSigns': [
                              ..._selectedDangerSigns,
                              if (_otherDangerSign.isNotEmpty) _otherDangerSign,
                            ].join(', '),
                            'counseling': [
                              ..._selectedCounselingNotes,
                              if (_otherCounselingNote.isNotEmpty)
                                _otherCounselingNote,
                              if (_counselingController.text.trim().isNotEmpty)
                                _counselingController.text.trim(),
                            ].join(', '),
                            'prescriptions': [
                              ..._selectedPrescriptions,
                              if (_otherPrescription.isNotEmpty)
                                _otherPrescription,
                            ].join(', '),
                            'labTests': [
                              ..._selectedLabTests,
                              if (_otherLabTest.isNotEmpty) _otherLabTest,
                            ].join(', '),
                            'radiology': [
                              ..._selectedRadiology,
                              if (_otherRadiology.isNotEmpty) _otherRadiology,
                            ].join(', '),
                            'notes': _notesController.text.trim(),
                            'consultationDate': now.toIso8601String(),
                            'createdAt': now,
                            'type': widget.appointmentType,
                            'statusFlag': 'completed',
                          };
                          try {
                            // Save completed consultation to health_records with required top-level fields
                            final chwUid =
                                FirebaseAuth.instance.currentUser?.uid ?? '';
                            print(
                              'DEBUG: Saving completed consultation to Firestore with:',
                            );
                            print('chwId: ' + chwUid);
                            print('statusFlag: completed');
                            await FirebaseFirestore.instance
                                .collection('health_records')
                                .add({
                                  'appointmentId': widget.appointmentId,
                                  'patientId': widget.patientId,
                                  'patientName': widget.patientName,
                                  'chwId': chwUid,
                                  'chwUid': chwUid,
                                  'providerName': 'Community Health Worker',
                                  'providerType': 'CHW',
                                  'consultationType': widget.appointmentType,
                                  'statusFlag': 'completed',
                                  'createdAt': now,
                                  'updatedAt': now,
                                  'completedAt': now,
                                  'timestamp': now,
                                  // Add any other top-level fields needed for display/filtering
                                  'accessibleBy': ['patient', 'doctor', 'chw'],
                                  // Consultation details
                                  'data': healthRecordData,
                                });
                            // Update appointment status to completed in Firestore for any type
                            await Future.delayed(Duration(milliseconds: 100));
                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(widget.appointmentId)
                                .update({
                                  'status': 'completed',
                                  'completedAt': now,
                                  'statusFlag': 'completed',
                                });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consultation saved successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            context.go('/');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error saving consultation: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// MultiSelectDropdown widget (must be outside any class)
class MultiSelectDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final Function(List<String>) onChanged;
  final String otherValue;

  const MultiSelectDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.otherValue,
  });

  @override
  Widget build(BuildContext context) {
    String displayText;
    if (selected.isEmpty && otherValue.isEmpty) {
      displayText = 'Select $label';
    } else {
      displayText = [
        ...selected,
        if (otherValue.isNotEmpty) 'Other: $otherValue',
      ].join(', ');
    }
    return InkWell(
      onTap: () async {
        List<String> tempSelected = List.from(selected);
        final result = await showDialog<List<String>>(
          context: context,
          // rootNavigator: true removed for compatibility
          builder: (ctx) {
            return AlertDialog(
              title: Text('Select $label'),
              content: SingleChildScrollView(
                child: Column(
                  children: options
                      .map(
                        (opt) => CheckboxListTile(
                          title: Text(opt),
                          value:
                              tempSelected.contains(opt) ||
                              (opt == 'Other' && otherValue.isNotEmpty),
                          onChanged: (checked) {
                            if (opt == 'Other') {
                              // handled in parent dialog in parent widget
                            } else {
                              if (checked == true) {
                                tempSelected.add(opt);
                              } else {
                                tempSelected.remove(opt);
                              }
                            }
                            (ctx as Element).markNeedsBuild();
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(tempSelected);
                  },
                ),
              ],
            );
          },
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: selected.isEmpty && otherValue.isEmpty
                ? Colors.grey
                : Colors.black,
          ),
        ),
      ),
    );
  }
}
