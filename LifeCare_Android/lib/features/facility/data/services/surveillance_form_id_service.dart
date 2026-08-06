import 'package:cloud_firestore/cloud_firestore.dart';

class SurveillanceFormIdService {
  static Future<String> nextFormId({
    required String facilityId,
    required String surveillanceCode,
    DateTime? date,
  }) async {
    final now = date ?? DateTime.now();
    final year = now.year.toString();
    final code = _sanitize(surveillanceCode);
    final counterId = '${_sanitize(facilityId)}_${code}_$year';
    final counterRef = FirebaseFirestore.instance
        .collection('surveillance_form_counters')
        .doc(counterId);

    final nextNumber = await FirebaseFirestore.instance.runTransaction<int>((
      transaction,
    ) async {
      final snapshot = await transaction.get(counterRef);
      final current = snapshot.data()?['lastNumber'] as int? ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {
        'facilityId': facilityId,
        'surveillanceCode': code,
        'year': year,
        'lastNumber': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });

    return '$code-$year-${nextNumber.toString().padLeft(6, '0')}';
  }

  static String _sanitize(String value) {
    final cleaned = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'SURV' : cleaned;
  }
}
