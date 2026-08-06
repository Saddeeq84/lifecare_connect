import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ClinicalNotesFormScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const ClinicalNotesFormScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ClinicalNotesFormScreen> createState() =>
      _ClinicalNotesFormScreenState();
}

class _ClinicalNotesFormScreenState extends State<ClinicalNotesFormScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  /// Opens modal to add or edit clinical note
  Future<void> _addOrEditNote({
    DocumentSnapshot<Map<String, dynamic>>? noteDoc,
  }) async {
    final titleCtrl = TextEditingController(
      text: noteDoc?.data()?['title'] ?? '',
    );
    final noteCtrl = TextEditingController(
      text: noteDoc?.data()?['note'] ?? '',
    );
    final isEditing = noteDoc != null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEditing ? 'Edit Clinical Note' : 'New Clinical Note'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'title': titleCtrl.text.trim(),
                'note': noteCtrl.text.trim(),
                'date': FieldValue.serverTimestamp(),
                'doctorId': currentUser?.uid,
                'lastUpdated': FieldValue.serverTimestamp(),
              };

              final notesRef = FirebaseFirestore.instance
                  .collection('patients')
                  .doc(widget.patientId)
                  .collection('clinical_notes');

              if (isEditing) {
                await notesRef.doc(noteDoc.id).update(data);
              } else {
                await notesRef.add(data);
              }

              Navigator.pop(context);
            },
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  /// Exports notes to PDF
  void _exportToPdf(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> notes,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Clinical Notes for ${widget.patientName}',
            style: const pw.TextStyle(fontSize: 20),
          ),
          pw.SizedBox(height: 10),
          for (var note in notes)
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    note.data()['title'] ?? '',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (note.data()['date'] != null)
                    pw.Text(
                      DateFormat.yMMMd().format(
                        (note.data()['date'] as Timestamp).toDate(),
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(note.data()['note'] ?? ''),
                ],
              ),
            ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final notesRef = FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.patientId)
        .collection('clinical_notes')
        .orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text("Clinical Notes - ${widget.patientName}"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: () async {
              final snap = await notesRef.get();
              if (snap.docs.isNotEmpty) {
                _exportToPdf(snap.docs);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No notes to export")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Note',
            onPressed: () => _addOrEditNote(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notes = snapshot.data?.docs ?? [];
          if (notes.isEmpty) {
            return const Center(child: Text("No clinical notes yet."));
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (ctx, i) {
              final note = notes[i];
              final date = (note.data()['date'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(note.data()['title'] ?? 'Untitled'),
                  subtitle: Text(
                    "${note.data()['note'] ?? ''}\nDate: ${date != null ? DateFormat.yMMMd().format(date) : 'Unknown'}",
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _addOrEditNote(noteDoc: note),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
