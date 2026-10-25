import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'captured_photo.dart';

/// Service to directly open the device's camera with no custom UI.
class AppCameraService {
  /// Directly opens the camera to take a photo.
  static Future<CapturedPhoto?> capturePhoto(
    BuildContext context, {
    String? preferredCameraDevice,
  }) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCameraDevice == 'front'
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final fileName = photo.name.isNotEmpty
            ? photo.name
            : 'photo_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.jpg';
        return CapturedPhoto(
          name: fileName,
          bytes: bytes,
          size: bytes.length,
          path: photo.path,
        );
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
      rethrow;
    }
    return null;
  }
}
