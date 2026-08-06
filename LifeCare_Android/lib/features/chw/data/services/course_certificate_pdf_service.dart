import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CourseCertificatePdfService {
  static Future<pw.Document> buildCertificate({
    required String learnerName,
    required String courseTitle,
    required DateTime issuedDate,
    required String certificateId,
    String? signatureUrl,
  }) async {
    final lifeCareLogo = await _loadAssetImage('assets/images/logo.png');
    final rhemnLogo = await _loadAssetImage(
      'assets/images/rhemn_logo_square.png',
    );
    final signature = await _loadNetworkImage(signatureUrl);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: PdfColors.teal800, width: 2.2),
          ),
          padding: const pw.EdgeInsets.all(10),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber600, width: 1.1),
            ),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 22,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLogo(lifeCareLogo),
                    pw.SizedBox(
                      width: 480,
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Rural Health Mission Nigeria',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'LifeCare Connect Training',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.teal900,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(
                                color: PdfColors.amber700,
                                width: 1.2,
                              ),
                            ),
                            child: pw.Text(
                              'CERTIFICATE OF COMPLETION',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 24.5,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildLogo(rhemnLogo),
                  ],
                ),
                pw.Spacer(),
                pw.Text(
                  'This certificate is proudly presented to',
                  style: const pw.TextStyle(fontSize: 14.5),
                ),
                pw.SizedBox(height: 12),
                pw.SizedBox(
                  width: 650,
                  height: 40,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      learnerName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  width: 450,
                  height: 1,
                  color: PdfColors.grey500,
                ),
                pw.Text(
                  'for successfully completing the professional training course',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 13.5),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.teal200),
                  ),
                  child: pw.Text(
                    courseTitle,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900,
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoBlock(
                      label: 'Issued Date',
                      value: _formatDate(issuedDate),
                    ),
                    pw.Column(
                      children: [
                        if (signature != null)
                          pw.Image(
                            signature,
                            width: 160,
                            height: 55,
                            fit: pw.BoxFit.contain,
                          )
                        else
                          pw.SizedBox(width: 160, height: 55),
                        pw.Container(
                          width: 190,
                          height: 1,
                          color: PdfColors.grey700,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Authorized Signature',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    _buildInfoBlock(
                      label: 'Certificate ID',
                      value: certificateId,
                      alignRight: true,
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(height: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Text(
                  'www.rhemn.org.ng | www.lifecare.rhemn.org.ng',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.teal900,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _buildLogo(pw.ImageProvider logo) {
    return pw.Container(
      width: 92,
      height: 92,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Image(logo, fit: pw.BoxFit.contain),
    );
  }

  static pw.Widget _buildInfoBlock({
    required String label,
    required String value,
    bool alignRight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: alignRight
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8.5,
            letterSpacing: 0.8,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  static Future<pw.MemoryImage> _loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  static Future<pw.MemoryImage?> _loadNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final trimmedUrl = url.trim();
    try {
      final response = await http.get(Uri.parse(trimmedUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Image request failed: ${response.statusCode}');
      }
      return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      try {
        final bytes = await FirebaseStorage.instance
            .refFromURL(trimmedUrl)
            .getData(5 * 1024 * 1024);
        if (bytes == null) return null;
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
