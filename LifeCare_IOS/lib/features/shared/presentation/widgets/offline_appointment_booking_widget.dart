// Offline Appointment Booking Widget
// Allows booking appointments even without internet connectivity

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/services/offline_database_service.dart';
import '../../../../core/services/batch_sync_manager.dart';

class OfflineAppointmentBookingWidget extends StatefulWidget {
  final String patientId;
  final String providerId;
  final String? facilityId;

  const OfflineAppointmentBookingWidget({
    super.key,
    required this.patientId,
    required this.providerId,
    this.facilityId,
  });

  @override
  State<OfflineAppointmentBookingWidget> createState() =>
      _OfflineAppointmentBookingWidgetState();
}

class _OfflineAppointmentBookingWidgetState
    extends State<OfflineAppointmentBookingWidget> {
  final OfflineDatabaseService _db = OfflineDatabaseService();
  final BatchSyncManager _syncManager = BatchSyncManager();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _appointmentType = 'consultation';
  String _notes = '';
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);
    });
  }

  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Please select date and time');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final appointmentData = {
        'id': 'offline_${DateTime.now().millisecondsSinceEpoch}',
        'patientId': widget.patientId,
        'providerId': widget.providerId,
        'facilityId': widget.facilityId ?? '',
        'appointmentDate': appointmentDateTime,
        'status': 'pending',
        'type': _appointmentType,
        'notes': _notes,
        'createdAt': DateTime.now().toIso8601String(),
        'syncStatus': 'pending',
        'createdOffline': !_isOnline,
      };

      // Save to local database
      await _db.saveAppointment(appointmentData);

      // Add to sync queue
      await _db.addToSyncQueue(
        operationType: 'create',
        entityType: 'appointment',
        entityId: appointmentData['id'] as String,
        operationData: appointmentData,
        priority: 2,
      );

      // Try to sync immediately if online
      if (_isOnline) {
        await _syncManager.triggerManualSync();
      }

      if (mounted) {
        _showMessage(
          _isOnline
              ? 'Appointment booked successfully!'
              : 'Appointment saved offline. Will sync when internet is available.',
          isSuccess: true,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('Failed to book appointment: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        actions: [
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, size: 16),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are offline. Appointment will be saved locally and synced when you reconnect.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Date Selection
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Select date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time Selection
            const Text(
              'Select Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime == null
                          ? 'Select time'
                          : _selectedTime!.format(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Appointment Type
            const Text(
              'Appointment Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _appointmentType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'consultation',
                  child: Text('Consultation'),
                ),
                DropdownMenuItem(value: 'follow_up', child: Text('Follow-up')),
                DropdownMenuItem(value: 'check_up', child: Text('Check-up')),
                DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _appointmentType = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Notes
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add any additional notes...',
              ),
              onChanged: (value) => _notes = value,
            ),

            const SizedBox(height: 24),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isOnline
                            ? 'Book Appointment'
                            : 'Save Appointment (Offline)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
