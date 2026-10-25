import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Represents a photo captured via camera or fallback image picker.
class CapturedPhoto {
  final String name;
  final Uint8List bytes;
  final int size;
  final String? path;

  CapturedPhoto({
    required this.name,
    required this.bytes,
    required this.size,
    this.path,
  });

  /// Converts this captured photo into an [XFile] for interoperability.
  XFile toXFile() {
    if (path != null && path!.isNotEmpty) {
      return XFile(path!, name: name, bytes: bytes);
    }
    return XFile.fromData(bytes, name: name);
  }
}
