import 'package:cloud_firestore/cloud_firestore.dart';

class QuerySnapshotFake implements QuerySnapshot {
  @override
  final List<QueryDocumentSnapshot> docs;
  QuerySnapshotFake(this.docs);

  // The following are not used in our code, so we can leave them unimplemented or empty
  @override
  List<DocumentChange> get docChanges => [];
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
  // Query get query => throw UnimplementedError();
  @override
  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
}
