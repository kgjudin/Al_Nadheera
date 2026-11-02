enum AppFileType {
  image,
  pdf,
  excel,
  doc,
  other,
}

class FileHelper {
  /// Returns standard MIME type string for common file extensions.
  static String getMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Determines the file category based on extension or URL.
  static AppFileType getFileType(String urlOrName) {
    final clean = urlOrName.split('?').first.toLowerCase();
    if (clean.endsWith('.pdf')) return AppFileType.pdf;
    if (clean.endsWith('.xlsx') || clean.endsWith('.xls') || clean.endsWith('.csv')) {
      return AppFileType.excel;
    }
    if (clean.endsWith('.doc') || clean.endsWith('.docx')) {
      return AppFileType.doc;
    }
    if (clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif')) {
      return AppFileType.image;
    }
    return AppFileType.other;
  }

  /// Extracts the original human-readable filename from a Supabase URL or storage key.
  /// If the filename was stored in `${uuid}_originalName.ext` format, returns `originalName.ext`.
  static String getDisplayName(String url) {
    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
      final decoded = Uri.decodeComponent(lastSegment);
      final underscoreIdx = decoded.indexOf('_');
      if (underscoreIdx != -1 && underscoreIdx < decoded.length - 1) {
        return decoded.substring(underscoreIdx + 1);
      }
      return decoded;
    } catch (_) {
      return 'Document';
    }
  }

  /// Sanitizes a file name for safe storage path and URL compatibility.
  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
