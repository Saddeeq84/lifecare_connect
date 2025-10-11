// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientFacilityBookingScreen extends StatefulWidget {
  final String facilityId;
  final Map<String, dynamic> facilityData;

  const PatientFacilityBookingScreen({
    super.key,
    required this.facilityId,
    required this.facilityData,
  });

  @override
  State<PatientFacilityBookingScreen> createState() =>
      _PatientFacilityBookingScreenState();
}

class _PatientFacilityBookingScreenState
    extends State<PatientFacilityBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customServiceController = TextEditingController();

  String? _selectedServiceType;
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  bool _isSubmitting = false;
  bool _showCustomServiceInput = false;

  // Get facility-specific services based on facility type
  List<Map<String, dynamic>> get _facilityServices {
    final facilityType = widget.facilityData['type'] ?? 'hospital';

    switch (facilityType) {
      case 'hospital':
        return [
          {
            'value': 'general_consultation',
            'label': 'General Medical Consultation',
            'icon': Icons.person_search,
          },
          {
            'value': 'specialist_consultation',
            'label': 'Specialist Consultation',
            'icon': Icons.local_hospital,
          },
          {
            'value': 'emergency_care',
            'label': 'Emergency Department Services',
            'icon': Icons.emergency,
          },
          {
            'value': 'pre_surgical_consultation',
            'label': 'Pre-Surgical Consultation',
            'icon': Icons.medical_services,
          },
          {
            'value': 'post_operative_care',
            'label': 'Post-Operative Follow-up',
            'icon': Icons.healing,
          },
          {
            'value': 'vaccination_immunization',
            'label': 'Vaccination & Immunization',
            'icon': Icons.vaccines,
          },
          {
            'value': 'preventive_health_screening',
            'label': 'Preventive Health Screening',
            'icon': Icons.health_and_safety,
          },
          {
            'value': 'inpatient_services',
            'label': 'Inpatient Admission Services',
            'icon': Icons.hotel,
          },
        ];

      case 'laboratory':
        return [
          {
            'value': 'complete_blood_count',
            'label': 'Complete Blood Count (CBC)',
            'icon': Icons.bloodtype,
          },
          {
            'value': 'lipid_profile',
            'label': 'Lipid Profile & Cholesterol',
            'icon': Icons.monitor_heart,
          },
          {
            'value': 'diabetes_screening',
            'label': 'Diabetes Screening (HbA1c, FBG)',
            'icon': Icons.medical_services,
          },
          {
            'value': 'liver_function',
            'label': 'Liver Function Tests (LFT)',
            'icon': Icons.biotech,
          },
          {
            'value': 'kidney_function',
            'label': 'Kidney Function Tests (KFT)',
            'icon': Icons.water_drop,
          },
          {
            'value': 'thyroid_function',
            'label': 'Thyroid Function Tests (TFT)',
            'icon': Icons.healing,
          },
          {
            'value': 'urine_analysis',
            'label': 'Comprehensive Urine Analysis',
            'icon': Icons.science,
          },
          {
            'value': 'culture_sensitivity',
            'label': 'Culture & Sensitivity Testing',
            'icon': Icons.coronavirus,
          },
        ];

      case 'pharmacy':
        return [
          {
            'value': 'prescription_order',
            'label': 'Medical Prescription Order',
            'icon': Icons.receipt_long,
          },
          {
            'value': 'medication_inquiry',
            'label': 'Medication Availability Inquiry',
            'icon': Icons.search,
          },
          {
            'value': 'medication_counseling',
            'label': 'Medication Counseling & Guidance',
            'icon': Icons.support_agent,
          },
          {
            'value': 'drug_interaction_check',
            'label': 'Drug Interaction Consultation',
            'icon': Icons.warning_amber,
          },
          {
            'value': 'otc_consultation',
            'label': 'Over-the-Counter Medication Advice',
            'icon': Icons.medical_information,
          },
          {
            'value': 'medication_delivery',
            'label': 'Home Delivery Service',
            'icon': Icons.delivery_dining,
          },
        ];

      case 'scan_center':
        return [
          {
            'value': 'abdominal_ultrasound',
            'label': 'Abdominal Ultrasound',
            'icon': Icons.monitor_heart,
          },
          {
            'value': 'ct_scan',
            'label': 'CT Scan (Computed Tomography)',
            'icon': Icons.medical_services,
          },
          {
            'value': 'mri_scan',
            'label': 'MRI Scan (Magnetic Resonance)',
            'icon': Icons.psychology,
          },
          {
            'value': 'chest_xray',
            'label': 'Chest X-Ray',
            'icon': Icons.monitor_heart_outlined,
          },
          {
            'value': 'pelvic_ultrasound',
            'label': 'Pelvic Ultrasound',
            'icon': Icons.pregnant_woman,
          },
          {
            'value': 'mammography',
            'label': 'Mammography Screening',
            'icon': Icons.favorite,
          },
          {
            'value': 'bone_density_scan',
            'label': 'Bone Density Scan (DEXA)',
            'icon': Icons.accessibility_new,
          },
          {
            'value': 'echocardiogram',
            'label': 'Echocardiogram (Heart Ultrasound)',
            'icon': Icons.favorite_border,
          },
        ];

      case 'physiotherapy_center':
        return [
          {
            'value': 'musculoskeletal_therapy',
            'label': 'Musculoskeletal Physical Therapy',
            'icon': Icons.accessibility,
          },
          {
            'value': 'post_surgical_rehab',
            'label': 'Post-Surgical Rehabilitation',
            'icon': Icons.healing,
          },
          {
            'value': 'sports_injury_therapy',
            'label': 'Sports Injury Rehabilitation',
            'icon': Icons.sports,
          },
          {
            'value': 'chronic_pain_management',
            'label': 'Chronic Pain Management',
            'icon': Icons.self_improvement,
          },
          {
            'value': 'neurological_rehab',
            'label': 'Neurological Rehabilitation',
            'icon': Icons.psychology,
          },
          {
            'value': 'manual_therapy',
            'label': 'Manual Therapy & Massage',
            'icon': Icons.pan_tool,
          },
          {
            'value': 'exercise_therapy',
            'label': 'Therapeutic Exercise Programs',
            'icon': Icons.fitness_center,
          },
        ];

      case 'dental_clinic':
        return [
          {
            'value': 'routine_dental_exam',
            'label': 'Routine Dental Examination',
            'icon': Icons.medical_information,
          },
          {
            'value': 'dental_prophylaxis',
            'label': 'Dental Prophylaxis (Deep Cleaning)',
            'icon': Icons.clean_hands,
          },
          {
            'value': 'restorative_filling',
            'label': 'Restorative Dental Filling',
            'icon': Icons.build,
          },
          {
            'value': 'tooth_extraction',
            'label': 'Tooth Extraction (Simple/Surgical)',
            'icon': Icons.content_cut,
          },
          {
            'value': 'root_canal_therapy',
            'label': 'Root Canal Therapy (Endodontics)',
            'icon': Icons.healing,
          },
          {
            'value': 'orthodontic_consultation',
            'label': 'Orthodontic Consultation',
            'icon': Icons.straighten,
          },
          {
            'value': 'dental_prosthetics',
            'label': 'Dental Prosthetics (Dentures/Crowns)',
            'icon': Icons.architecture,
          },
          {
            'value': 'oral_surgery',
            'label': 'Oral & Maxillofacial Surgery',
            'icon': Icons.medical_services,
          },
        ];

      case 'eye_clinic':
        return [
          {
            'value': 'comprehensive_eye_exam',
            'label': 'Comprehensive Eye Examination',
            'icon': Icons.visibility,
          },
          {
            'value': 'visual_acuity_test',
            'label': 'Visual Acuity & Refraction Test',
            'icon': Icons.remove_red_eye,
          },
          {
            'value': 'contact_lens_fitting',
            'label': 'Contact Lens Fitting & Training',
            'icon': Icons.lens,
          },
          {
            'value': 'cataract_evaluation',
            'label': 'Cataract Evaluation & Surgery Consultation',
            'icon': Icons.blur_on,
          },
          {
            'value': 'glaucoma_screening',
            'label': 'Glaucoma Screening & Monitoring',
            'icon': Icons.visibility_off,
          },
          {
            'value': 'retinal_examination',
            'label': 'Retinal Examination & Imaging',
            'icon': Icons.center_focus_strong,
          },
          {
            'value': 'pediatric_eye_care',
            'label': 'Pediatric Eye Care & Vision Screening',
            'icon': Icons.child_care,
          },
        ];

      case 'mental_health_center':
        return [
          {
            'value': 'individual_counseling',
            'label': 'Individual Counseling Session',
            'icon': Icons.psychology,
          },
          {
            'value': 'cognitive_behavioral_therapy',
            'label': 'Cognitive Behavioral Therapy (CBT)',
            'icon': Icons.self_improvement,
          },
          {
            'value': 'psychiatric_evaluation',
            'label': 'Psychiatric Evaluation & Consultation',
            'icon': Icons.medical_services,
          },
          {
            'value': 'group_therapy_session',
            'label': 'Group Therapy Session',
            'icon': Icons.groups,
          },
          {
            'value': 'addiction_counseling',
            'label': 'Addiction & Substance Abuse Counseling',
            'icon': Icons.healing,
          },
          {
            'value': 'family_therapy',
            'label': 'Family & Couples Therapy',
            'icon': Icons.family_restroom,
          },
          {
            'value': 'crisis_intervention',
            'label': 'Crisis Intervention & Support',
            'icon': Icons.support,
          },
          {
            'value': 'psychological_assessment',
            'label': 'Psychological Assessment & Testing',
            'icon': Icons.assignment,
          },
        ];

      default:
        return [
          {
            'value': 'consultation',
            'label': 'General Consultation',
            'icon': Icons.person_search,
          },
          {
            'value': 'appointment',
            'label': 'General Appointment',
            'icon': Icons.event,
          },
          {
            'value': 'information',
            'label': 'Information Request',
            'icon': Icons.info,
          },
        ];
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _phoneController.dispose();
    _customServiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book with ${widget.facilityData['name'] ?? 'Facility'}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Facility Information Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade50, Colors.teal.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital,
                          size: 32,
                          color: Colors.teal.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.facilityData['name'] ?? 'Facility Name',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.facilityData['address'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.facilityData['address'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.facilityData['contact'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            widget.facilityData['contact'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Service Type Selection
              const Text(
                'Service Type *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 1,
                            mainAxisSpacing: 1,
                          ),
                      itemCount: _facilityServices.length,
                      itemBuilder: (context, index) {
                        final service = _facilityServices[index];
                        final isSelected =
                            _selectedServiceType == service['value'];

                        return InkWell(
                          onTap: () => setState(
                            () => _selectedServiceType = service['value'],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.teal.shade50
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.teal
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  service['icon'],
                                  color: isSelected
                                      ? Colors.teal
                                      : Colors.grey.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    service['label'],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.grey.shade700,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Custom service option
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() {
                        _showCustomServiceInput = !_showCustomServiceInput;
                        if (_showCustomServiceInput) {
                          _selectedServiceType = 'custom';
                        }
                      }),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedServiceType == 'custom'
                              ? Colors.orange.shade50
                              : Colors.grey.shade50,
                          border: Border.all(
                            color: _selectedServiceType == 'custom'
                                ? Colors.orange
                                : Colors.grey.shade300,
                            width: _selectedServiceType == 'custom' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: _selectedServiceType == 'custom'
                                  ? Colors.orange
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Request Custom Service',
                              style: TextStyle(
                                color: _selectedServiceType == 'custom'
                                    ? Colors.orange
                                    : Colors.grey.shade700,
                                fontWeight: _selectedServiceType == 'custom'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Custom service input field
                    if (_showCustomServiceInput) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customServiceController,
                        decoration: InputDecoration(
                          labelText: 'Describe the service you need',
                          hintText:
                              'Enter the specific service you\'re looking for...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.edit_note),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (_selectedServiceType == 'custom' &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please describe the service you need';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Description
              const Text(
                'Description/Notes *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Describe your symptoms, requirements, or any specific notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Please provide a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Contact Phone
              const Text(
                'Contact Phone *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter your phone number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Phone number is required';
                  }
                  if (value!.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Preferred Date and Time
              const Text(
                'Preferred Date & Time (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _preferredDate != null
                                  ? '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}'
                                  : 'Select Date',
                              style: TextStyle(
                                color: _preferredDate != null
                                    ? Colors.black
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.teal),
                            const SizedBox(width: 12),
                            Text(
                              _preferredTime != null
                                  ? _preferredTime!.format(context)
                                  : 'Select Time',
                              style: TextStyle(
                                color: _preferredTime != null
                                    ? Colors.black
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting Request...'),
                          ],
                        )
                      : const Text(
                          'Submit Service Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your request will be sent to this facility for review. You will be contacted once approved.',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) {
      setState(() => _preferredDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _preferredTime = time);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get patient data
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final patientData = patientDoc.data() ?? {};

      // Get service type and label
      String serviceType = _selectedServiceType!;
      String serviceLabel;

      if (_selectedServiceType == 'custom') {
        serviceType = 'custom';
        serviceLabel = _customServiceController.text.trim();
      } else {
        final selectedService = _facilityServices.firstWhere(
          (service) => service['value'] == _selectedServiceType,
          orElse: () => {'label': _selectedServiceType},
        );
        serviceLabel = selectedService['label'] ?? _selectedServiceType!;
      }

      // Prepare the request data
      final requestData = {
        'patientId': user.uid,
        'patientName':
            patientData['fullName'] ?? patientData['name'] ?? 'Unknown Patient',
        'patientEmail': user.email,
        'patientPhone': _phoneController.text.trim(),
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityData['name'] ?? 'Unknown Facility',
        'facilityType': widget.facilityData['type'] ?? 'unknown',
        'serviceType': serviceType,
        'serviceLabel': serviceLabel,
        'description': _descriptionController.text.trim(),
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add custom service details if applicable
      if (_selectedServiceType == 'custom') {
        requestData['customServiceDescription'] = _customServiceController.text
            .trim();
      }

      // Add preferred date/time if selected
      if (_preferredDate != null && _preferredTime != null) {
        final preferredDateTime = DateTime(
          _preferredDate!.year,
          _preferredDate!.month,
          _preferredDate!.day,
          _preferredTime!.hour,
          _preferredTime!.minute,
        );
        requestData['preferredDate'] = Timestamp.fromDate(preferredDateTime);
      }

      // Submit the request
      await FirebaseFirestore.instance
          .collection('service_requests')
          .add(requestData);

      // Send automatic message to patient-facility chat
      await _sendFacilityMessage(
        patientId: user.uid,
        facilityId: widget.facilityId,
        content:
            'New service request submitted: '
            '${requestData['serviceLabel'] ?? requestData['customServiceDescription'] ?? ''}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Service request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back with success
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting request: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Helper: Send a system message to the chat between patient and facility using the main messaging system
  Future<void> _sendFacilityMessage({
    required String patientId,
    required String facilityId,
    required String content,
  }) async {
    // Get facility name (from widget or Firestore if needed)
    final facilityName = widget.facilityData['name'] ?? 'Facility';
    // Get patient name from Firestore
    final patientDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .get();
    final patientName =
        patientDoc.data()?['fullName'] ??
        patientDoc.data()?['name'] ??
        'Patient';

    // Add message directly to the central messages collection
    final messageRef = await FirebaseFirestore.instance
        .collection('messages')
        .add({
          'conversationId': '${facilityId}_${patientId}',
          'senderId': facilityId,
          'senderName': facilityName,
          'senderRole': 'facility',
          'receiverId': patientId,
          'receiverName': patientName,
          'receiverRole': 'patient',
          'content': content,
          'type': 'patient_facility',
          'timestamp': FieldValue.serverTimestamp(),
          'isSystem': true,
        });

    // Update or create the conversation document
    final conversationId = '${facilityId}_${patientId}';
    final conversationDoc = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    await conversationDoc.set({
      'participantIds': [facilityId, patientId],
      'participants': [facilityId, patientId],
      'participantNames': {facilityId: facilityName, patientId: patientName},
      'participantRoles': {facilityId: 'facility', patientId: 'patient'},
      'title': 'Private Chat',
      'type': 'patient_facility',
      'recipientType': 'patient',
      'isActive': true,
      'lastMessage': content,
      'lastMessageId': messageRef.id,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': facilityId,
      'unreadCounts': {facilityId: 0, patientId: 1},
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': null,
    }, SetOptions(merge: true));
  }
}
