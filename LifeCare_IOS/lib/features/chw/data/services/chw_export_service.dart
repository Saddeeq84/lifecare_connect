import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CHWExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  final dateFormat = DateFormat('MMM dd, yyyy');
  final dateTimeFormat = DateFormat('MMM dd, yyyy - hh:mm a');

  /// Export transactions as CSV
  Future<File> exportTransactionsCSV({
    required String chwId,
    required String chwName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get transactions
    Query query = _firestore
        .collection('chw_transactions')
        .where('chwId', isEqualTo: chwId);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(Duration(days: 1))),
      );
    }

    final snapshot = await query.orderBy('timestamp', descending: true).get();

    // Build CSV content
    StringBuffer csv = StringBuffer();
    csv.writeln(
      'Date,Service Type,Patient Name,Total Amount,CHW Earning (70%),Admin Share (30%)',
    );

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final serviceType = _formatServiceName(
        data['serviceType'] as String? ?? 'Unknown',
      );
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final chwAmount = (data['chwAmount'] as num?)?.toDouble() ?? 0;
      final adminAmount = (data['adminAmount'] as num?)?.toDouble() ?? 0;
      final patientId = data['patientId'] as String?;

      String patientName = 'Unknown';
      if (patientId != null) {
        try {
          final patientDoc = await _firestore
              .collection('chw_patients')
              .doc(patientId)
              .get();
          if (patientDoc.exists) {
            patientName =
                (patientDoc.data()?['fullName'] as String?) ?? 'Unknown';
          }
        } catch (e) {
          // Ignore error, keep Unknown
        }
      }

      csv.writeln(
        '"${timestamp != null ? dateTimeFormat.format(timestamp) : 'N/A'}",'
        '"$serviceType",'
        '"$patientName",'
        '${totalAmount.toStringAsFixed(2)},'
        '${chwAmount.toStringAsFixed(2)},'
        '${adminAmount.toStringAsFixed(2)}',
      );
    }

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'CHW_Transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv.toString());

    return file;
  }

  /// Export patient records as CSV
  Future<File> exportPatientsCSV({
    required String chwId,
    required String chwName,
  }) async {
    final snapshot = await _firestore
        .collection('chw_patients')
        .where('registeredBy', isEqualTo: chwId)
        .orderBy('createdAt', descending: true)
        .get();

    StringBuffer csv = StringBuffer();
    csv.writeln('Name,Phone,Email,Age,Gender,Address,Registration Date');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['fullName'] ?? '';
      final phone = data['phone'] ?? '';
      final email = data['email'] ?? '';
      final age = data['age'] ?? '';
      final gender = data['gender'] ?? '';
      final address = data['address'] ?? '';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      csv.writeln(
        '"$name",'
        '"$phone",'
        '"$email",'
        '"$age",'
        '"$gender",'
        '"$address",'
        '"${createdAt != null ? dateFormat.format(createdAt) : 'N/A'}"',
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'CHW_Patients_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv.toString());

    return file;
  }

  /// Export earnings report as PDF
  Future<File> exportEarningsPDF({
    required String chwId,
    required String chwName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Get transactions
    Query query = _firestore
        .collection('chw_transactions')
        .where('chwId', isEqualTo: chwId);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(Duration(days: 1))),
      );
    }

    final snapshot = await query.orderBy('timestamp', descending: false).get();

    // Calculate summary statistics
    double totalEarnings = 0;
    int totalServices = snapshot.docs.length;
    Map<String, double> earningsByService = {};
    Map<String, int> countByService = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final serviceType = data['serviceType'] as String? ?? 'Unknown';
      final chwAmount = (data['chwAmount'] as num?)?.toDouble() ?? 0;

      totalEarnings += chwAmount;
      earningsByService[serviceType] =
          (earningsByService[serviceType] ?? 0) + chwAmount;
      countByService[serviceType] = (countByService[serviceType] ?? 0) + 1;
    }

    // Build PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CHW Earnings Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      chwName,
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                    pw.Text(
                      startDate != null && endDate != null
                          ? 'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}'
                          : 'All Time',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Statistics
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPDFStat(
                      'Total Earnings',
                      currencyFormat.format(totalEarnings),
                    ),
                    _buildPDFStat(
                      'Services Delivered',
                      totalServices.toString(),
                    ),
                    _buildPDFStat(
                      'Avg per Service',
                      totalServices > 0
                          ? currencyFormat.format(totalEarnings / totalServices)
                          : '₦0.00',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Earnings Breakdown
              pw.Text(
                'Earnings by Service Type',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              if (earningsByService.isEmpty)
                pw.Text('No services delivered in this period')
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Service Type', isHeader: true),
                        _buildTableCell('Count', isHeader: true),
                        _buildTableCell('Earnings', isHeader: true),
                        _buildTableCell('Avg/Service', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...earningsByService.entries.map((entry) {
                      final count = countByService[entry.key] ?? 0;
                      final avg = count > 0 ? entry.value / count : 0;
                      return pw.TableRow(
                        children: [
                          _buildTableCell(_formatServiceName(entry.key)),
                          _buildTableCell(count.toString()),
                          _buildTableCell(currencyFormat.format(entry.value)),
                          _buildTableCell(currencyFormat.format(avg)),
                        ],
                      );
                    }),
                  ],
                ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: pw.EdgeInsets.only(top: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Text(
                  'Generated on ${dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'CHW_Earnings_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Export service analytics report as PDF
  Future<File> exportServiceAnalyticsPDF({
    required String chwId,
    required String chwName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    // Get transactions
    Query query = _firestore
        .collection('chw_transactions')
        .where('chwId', isEqualTo: chwId);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(Duration(days: 1))),
      );
    }

    final snapshot = await query.orderBy('timestamp', descending: false).get();

    // Group by date and service type
    Map<String, Map<String, int>> dailyServices = {};
    Map<String, int> serviceBreakdown = {};
    Set<String> uniquePatients = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final serviceType = data['serviceType'] as String? ?? 'Unknown';
      final patientId = data['patientId'] as String?;

      if (timestamp != null) {
        final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
        dailyServices[dateKey] ??= {};
        dailyServices[dateKey]![serviceType] =
            (dailyServices[dateKey]![serviceType] ?? 0) + 1;
      }

      serviceBreakdown[serviceType] = (serviceBreakdown[serviceType] ?? 0) + 1;

      if (patientId != null) {
        uniquePatients.add(patientId);
      }
    }

    final totalServices = snapshot.docs.length;

    // Build PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CHW Service Analytics Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      chwName,
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                    pw.Text(
                      startDate != null && endDate != null
                          ? 'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}'
                          : 'All Time',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPDFStat('Total Services', totalServices.toString()),
                    _buildPDFStat(
                      'Patients Served',
                      uniquePatients.length.toString(),
                    ),
                    _buildPDFStat(
                      'Service Types',
                      serviceBreakdown.length.toString(),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Service Breakdown
              pw.Text(
                'Service Breakdown',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              if (serviceBreakdown.isEmpty)
                pw.Text('No services delivered in this period')
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Service Type', isHeader: true),
                        _buildTableCell('Count', isHeader: true),
                        _buildTableCell('Percentage', isHeader: true),
                      ],
                    ),
                    ...serviceBreakdown.entries.map((entry) {
                      final percentage = (entry.value / totalServices * 100)
                          .toStringAsFixed(1);
                      return pw.TableRow(
                        children: [
                          _buildTableCell(_formatServiceName(entry.key)),
                          _buildTableCell(entry.value.toString()),
                          _buildTableCell('$percentage%'),
                        ],
                      );
                    }),
                  ],
                ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: pw.EdgeInsets.only(top: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Text(
                  'Generated on ${dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'CHW_Service_Analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Share file using the share dialog
  Future<void> shareFile(File file) async {
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'CHW Report - ${file.path.split('/').last}');
  }

  // Helper methods
  pw.Widget _buildPDFStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _formatServiceName(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'consultation':
        return 'Consultation';
      case 'anc':
        return 'Antenatal Care';
      case 'pnc':
        return 'Postnatal Care';
      case 'home_visit':
        return 'Home Visit';
      case 'immunization':
        return 'Immunization';
      case 'appointment':
        return 'Appointment Booking';
      default:
        return serviceType;
    }
  }
}
