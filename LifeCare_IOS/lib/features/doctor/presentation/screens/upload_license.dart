import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadLicenseScreen extends StatefulWidget {
  const UploadLicenseScreen({super.key});

  @override
  State<UploadLicenseScreen> createState() => _UploadLicenseScreenState();
}

class _UploadLicenseScreenState extends State<UploadLicenseScreen> {
  String? selectedFile;

  Future<void> pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      type: FileType.custom,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = result.files.single.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected file: ${result.files.single.name}')),
      );
    }
  }

  void simulateUpload() {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a license file to upload')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('License "$selectedFile" submitted (UI only)')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload License'),
        backgroundColor: Colors.green.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickLicenseFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Pick License File"),
            ),
            if (selectedFile != null) ...[
              const SizedBox(height: 20),
              Text("Selected File: $selectedFile"),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: simulateUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
