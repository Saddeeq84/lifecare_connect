import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FluidBalanceChart extends StatefulWidget {
  final String patientId;
  final String patientName;

  const FluidBalanceChart({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<FluidBalanceChart> createState() => _FluidBalanceChartState();
}

class _FluidBalanceChartState extends State<FluidBalanceChart> {
  String _selectedRange = '24hours'; // 24hours, week, month
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date Range Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRangeButton('24 Hours', '24hours'),
                  _buildRangeButton('Week', 'week'),
                  _buildRangeButton('Month', 'month'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    _getDateRangeText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _selectedDate.isBefore(DateTime.now())
                        ? () => _changeDate(1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Fluid Balance Data
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getFluidDataStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No fluid balance data for this period',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final records = _processFluidRecords(snapshot.data!.docs);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(records),
                  const SizedBox(height: 16),
                  _buildDetailedRecords(records),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeButton(String label, String value) {
    final isSelected = _selectedRange == value;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedRange = value;
          _selectedDate = DateTime.now();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade700 : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.blue.shade700,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(color: Colors.blue.shade700),
      ),
      child: Text(label),
    );
  }

  void _changeDate(int direction) {
    setState(() {
      switch (_selectedRange) {
        case '24hours':
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case 'week':
          _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
          break;
        case 'month':
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + direction,
            _selectedDate.day,
          );
          break;
      }
    });
  }

  String _getDateRangeText() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    switch (_selectedRange) {
      case '24hours':
        return dateFormat.format(_selectedDate);
      case 'week':
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${dateFormat.format(startOfWeek)} - ${dateFormat.format(endOfWeek)}';
      case 'month':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      default:
        return dateFormat.format(_selectedDate);
    }
  }

  Stream<QuerySnapshot> _getFluidDataStream() {
    // Only query by patientId to avoid composite index requirement
    // Date filtering will be done in _processFluidRecords
    return FirebaseFirestore.instance
        .collection('nursing_procedures')
        .where('patientId', isEqualTo: widget.patientId)
        .snapshots();
  }

  Map<String, dynamic> _processFluidRecords(List<QueryDocumentSnapshot> docs) {
    // Calculate date range based on selected range
    DateTime startDate;
    DateTime endDate;

    switch (_selectedRange) {
      case '24hours':
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'week':
        startDate = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        break;
      default:
        startDate = DateTime.now().subtract(const Duration(days: 1));
        endDate = DateTime.now();
    }

    double totalIntake = 0;
    double totalOutput = 0;
    final List<Map<String, dynamic>> intakeRecords = [];
    final List<Map<String, dynamic>> outputRecords = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Filter by date range
      final performedAt = data['performedAt'] as Timestamp?;
      if (performedAt == null) continue;

      final performedDate = performedAt.toDate();
      if (performedDate.isBefore(startDate) || performedDate.isAfter(endDate)) {
        continue; // Skip records outside date range
      }

      // Process intake (Blood Transfusion, IV Fluid Therapy, Patient Feeding)
      if (data.containsKey('fluidIntake') && data['fluidIntake'] != null) {
        final intake = (data['fluidIntake'] as num).toDouble();
        totalIntake += intake;
        intakeRecords.add({
          'time': data['performedAt'],
          'type': data['procedureName'],
          'volume': intake,
          'details': data,
        });
      }

      // Process output (Fluid Output Monitoring)
      if (data.containsKey('fluidOutput') && data['fluidOutput'] != null) {
        final output = (data['fluidOutput'] as num).toDouble();
        totalOutput += output;
        outputRecords.add({
          'time': data['performedAt'],
          'type': 'Fluid Output',
          'volume': output,
          'details': data,
        });
      }
    }

    // Sort records by time (ascending)
    intakeRecords.sort((a, b) {
      final aTime = a['time'] as Timestamp?;
      final bTime = b['time'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    outputRecords.sort((a, b) {
      final aTime = a['time'] as Timestamp?;
      final bTime = b['time'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    return {
      'totalIntake': totalIntake,
      'totalOutput': totalOutput,
      'balance': totalIntake - totalOutput,
      'intakeRecords': intakeRecords,
      'outputRecords': outputRecords,
    };
  }

  Widget _buildSummaryCard(Map<String, dynamic> records) {
    final totalIntake = records['totalIntake'] as double;
    final totalOutput = records['totalOutput'] as double;
    final balance = records['balance'] as double;
    final isPositive = balance >= 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Fluid Balance Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Intake',
                  totalIntake,
                  Colors.blue.shade600,
                  Icons.arrow_downward,
                ),
                Container(width: 1, height: 60, color: Colors.grey.shade300),
                _buildSummaryItem(
                  'Total Output',
                  totalOutput,
                  Colors.orange.shade600,
                  Icons.arrow_upward,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPositive
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${balance.toStringAsFixed(0)} ml',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
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

  Widget _buildSummaryItem(
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} ml',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedRecords(Map<String, dynamic> records) {
    final intakeRecords =
        records['intakeRecords'] as List<Map<String, dynamic>>;
    final outputRecords =
        records['outputRecords'] as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intakeRecords.isNotEmpty) ...[
          Text(
            'Fluid Intake Records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...intakeRecords.map((record) => _buildRecordCard(record, true)),
          const SizedBox(height: 24),
        ],
        if (outputRecords.isNotEmpty) ...[
          Text(
            'Fluid Output Records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...outputRecords.map((record) => _buildRecordCard(record, false)),
        ],
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, bool isIntake) {
    final timestamp = (record['time'] as Timestamp).toDate();
    final type = record['type'] as String;
    final volume = record['volume'] as double;
    final details = record['details'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIntake
              ? Colors.blue.shade100
              : Colors.orange.shade100,
          child: Icon(
            isIntake ? Icons.water_drop : Icons.opacity,
            color: isIntake ? Colors.blue.shade700 : Colors.orange.shade700,
          ),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, hh:mm a').format(timestamp)),
            if (details.containsKey('timeStarted'))
              Text('Started: ${details['timeStarted']}'),
            if (details.containsKey('estimatedFinishTime'))
              Text('Est. Finish: ${details['estimatedFinishTime']}'),
            if (details.containsKey('urineOutput'))
              Text('Urine: ${details['urineOutput']} ml'),
            if (details.containsKey('vomitus'))
              Text('Vomitus: ${details['vomitus']} ml'),
            if (details.containsKey('diarrhea'))
              Text('Diarrhea: ${details['diarrhea']} ml'),
          ],
        ),
        trailing: Text(
          '${volume.toStringAsFixed(0)} ml',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isIntake ? Colors.blue.shade700 : Colors.orange.shade700,
          ),
        ),
      ),
    );
  }
}
