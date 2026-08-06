import 'package:open_file/open_file.dart';

Future<void> openFile(String filePath) async {
  await OpenFile.open(filePath);
}
