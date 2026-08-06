import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FluidBalanceChartScreen extends StatefulWidget {
  final String facilityId;
  final String patientId;
  final String patientName;

  const FluidBalanceChartScreen({
    super.key,
    required this.facilityId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<FluidBalanceChartScreen> createState() =>
      _FluidBalanceChartScreenState();
}

class _FluidBalanceChartScreenState extends State<FluidBalanceChartScreen> {
  String _selectedRange = 'Days';
  int _daysToShow = 7;
  bool _isLoading = true;
  List<FluidBalanceData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _loadFluidRecords();
  }

  Future<void> _loadFluidRecords() async {
    setState(() => _isLoading = true);

    try {
      // Calculate date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: _daysToShow));

      // Query fluid intake and output records
      final snapshot = await FirebaseFirestore.instance
          .collection('nursing_procedures')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('patientId', isEqualTo: widget.patientId)
          .where(
            'performedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'performedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .get();

      final records = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Only include records with fluid tracking
            if (data['fluidType'] == 'intake' ||
                data['fluidType'] == 'output') {
              return {'id': doc.id, ...data};
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      // Process data into 24-hour periods
      _processFluidData(records);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading fluid records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processFluidData(List<Map<String, dynamic>> records) {
    final Map<String, FluidBalanceData> dailyData = {};

    for (final record in records) {
      final timestamp = (record['performedAt'] as Timestamp?)?.toDate();
      if (timestamp == null) continue;

      final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = FluidBalanceData(
          date: DateTime(timestamp.year, timestamp.month, timestamp.day),
          intake: 0,
          output: 0,
        );
      }

      final fluidType = record['fluidType'] as String?;

      if (fluidType == 'intake') {
        // Add intake volumes
        final volumeMl = (record['volumeMl'] as num?)?.toDouble() ?? 0;
        final oralFluidMl = (record['oralFluidMl'] as num?)?.toDouble() ?? 0;
        dailyData[dateKey]!.intake += volumeMl + oralFluidMl;
      } else if (fluidType == 'output') {
        // Add output volumes
        final urineOutputMl =
            (record['urineOutputMl'] as num?)?.toDouble() ?? 0;
        final vomitusMl = (record['vomitusMl'] as num?)?.toDouble() ?? 0;
        final diarrheaMl = (record['diarrheaMl'] as num?)?.toDouble() ?? 0;
        final sweatEstimateMl =
            (record['sweatEstimateMl'] as num?)?.toDouble() ?? 0;
        dailyData[dateKey]!.output +=
            urineOutputMl + vomitusMl + diarrheaMl + sweatEstimateMl;
      }
    }

    // Convert to sorted list
    final sortedData = dailyData.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _chartData = sortedData;
    });
  }

  void _updateRange(String range) {
    setState(() {
      _selectedRange = range;
      switch (range) {
        case 'Days':
          _daysToShow = 7;
          break;
        case 'Weeks':
          _daysToShow = 28;
          break;
        case 'Months':
          _daysToShow = 90;
          break;
      }
    });
    _loadFluidRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fluid Balance Chart'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Patient Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patientName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fluid Balance Monitoring',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Range Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Time Range:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Days', label: Text('7 Days')),
                            ButtonSegment(
                              value: 'Weeks',
                              label: Text('4 Weeks'),
                            ),
                            ButtonSegment(
                              value: 'Months',
                              label: Text('3 Months'),
                            ),
                          ],
                          selected: {_selectedRange},
                          onSelectionChanged: (Set<String> selection) {
                            _updateRange(selection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Chart
                if (_chartData.isEmpty)
                  Expanded(
                    child: Center(
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
                            'No fluid records found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start recording fluid procedures to see data',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Summary Cards
                        _buildSummaryCards(),
                        const SizedBox(height: 24),

                        // Simple Bar Chart
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daily Fluid Balance',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildSimpleBarChart(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Data Table
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detailed Records',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDataTable(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    final totalIntake = _chartData.fold<double>(
      0,
      (sum, item) => sum + item.intake,
    );
    final totalOutput = _chartData.fold<double>(
      0,
      (sum, item) => sum + item.output,
    );
    final balance = totalIntake - totalOutput;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.water_drop,
                    color: Colors.green.shade700,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalIntake.toStringAsFixed(0)} ml',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const Text(
                    'Total Intake',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    color: Colors.orange.shade700,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalOutput.toStringAsFixed(0)} ml',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const Text(
                    'Total Output',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            color: balance >= 0 ? Colors.blue.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    balance >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: balance >= 0
                        ? Colors.blue.shade700
                        : Colors.red.shade700,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${balance >= 0 ? '+' : ''}${balance.toStringAsFixed(0)} ml',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: balance >= 0
                          ? Colors.blue.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  const Text(
                    'Net Balance',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleBarChart() {
    if (_chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find max value for scaling
    final maxValue = _chartData
        .map((e) => e.intake > e.output ? e.intake : e.output)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Intake', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 24),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Output', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 24),
        // Bars
        SizedBox(
          height: 250,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _chartData.asMap().entries.map((entry) {
                final data = entry.value;
                final intakeHeight = maxValue > 0
                    ? (data.intake / maxValue) * 200
                    : 0.0;
                final outputHeight = maxValue > 0
                    ? (data.output / maxValue) * 200
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Values above bars
                      if (data.intake > 0 || data.output > 0)
                        Container(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (data.intake > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    data.intake.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (data.intake > 0 && data.output > 0)
                                const SizedBox(width: 4),
                              if (data.output > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    data.output.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // Bars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Intake bar
                          Container(
                            width: 20,
                            height: intakeHeight.clamp(0.0, 200.0),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Output bar
                          Container(
                            width: 20,
                            height: outputHeight.clamp(0.0, 200.0),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Date label
                      SizedBox(
                        width: 44,
                        child: Text(
                          DateFormat('MM/dd').format(data.date),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Intake (ml)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Output (ml)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Balance (ml)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: _chartData.map((data) {
          final balance = data.intake - data.output;
          final isPositive = balance >= 0;

          return DataRow(
            cells: [
              DataCell(Text(DateFormat('MMM dd, yyyy').format(data.date))),
              DataCell(
                Text(
                  data.intake.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Text(
                  data.output.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${isPositive ? '+' : ''}${balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPositive
                        ? Colors.blue.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.blue.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPositive ? 'Positive' : 'Negative',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPositive
                          ? Colors.blue.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class FluidBalanceData {
  final DateTime date;
  double intake;
  double output;

  FluidBalanceData({
    required this.date,
    required this.intake,
    required this.output,
  });

  double get balance => intake - output;
}
