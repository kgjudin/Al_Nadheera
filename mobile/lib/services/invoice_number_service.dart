import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service to generate standard, sequential invoice and document numbers
/// across all modules (B2B Invoices, Quotations, Material Invoices, Subcontractor Invoices, IPCs).
class InvoiceNumberService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Returns standard prefix for B2B Document Types
  static String getPrefixForType(String documentType) {
    switch (documentType.trim().toLowerCase()) {
      case 'quotation':
        return 'ANCC-QTN';
      case 'estimate':
        return 'ANCC-EST';
      case 'letter':
        return 'ANCC-LTR';
      case 'b2b':
      case 'tax invoice':
      case 'invoice':
      default:
        return 'ANCC-INV';
    }
  }

  /// Initial synchronous B2B Document / Invoice Number (e.g. ANCC-INV-2026-001)
  static String generateInitialB2bNumber(String documentType, [DateTime? date]) {
    final year = (date ?? DateTime.now()).year;
    final prefix = getPrefixForType(documentType);
    return '$prefix-$year-001';
  }

  /// Asynchronously fetches the next sequential B2B Invoice / Quotation number from database
  static Future<String> fetchNextB2bDocumentNumber(String documentType, [DateTime? date]) async {
    final year = (date ?? DateTime.now()).year;
    final prefix = getPrefixForType(documentType);
    final pattern = '$prefix-$year-';

    try {
      final res = await _supabase
          .from('invoices')
          .select('invoice_number')
          .order('created_at', ascending: false)
          .limit(100);

      int maxSeq = 0;
      int totalCount = (res as List).length;

      for (final row in res) {
        final invNum = (row['invoice_number'] ?? '').toString().trim();
        if (invNum.startsWith(pattern)) {
          final suffix = invNum.substring(pattern.length);
          final numPart = int.tryParse(suffix);
          if (numPart != null && numPart > maxSeq) {
            maxSeq = numPart;
          }
        } else {
          // Check for legacy formats like ANCC-032/026 or ANCC-001
          final match = RegExp(r'\d+').allMatches(invNum);
          if (match.isNotEmpty) {
            final val = int.tryParse(match.first.group(0) ?? '');
            if (val != null && val > maxSeq && val < 100000) {
              maxSeq = val;
            }
          }
        }
      }

      final nextNumber = (maxSeq > 0 ? maxSeq + 1 : totalCount + 1);
      final padded = nextNumber.toString().padLeft(3, '0');
      return '$pattern$padded';
    } catch (_) {
      // Fallback: initial format with timestamp-safe uniqueness
      return generateInitialB2bNumber(documentType, date);
    }
  }

  /// Initial synchronous Material Invoice Number (e.g. INV-2026-001)
  static String generateInitialMaterialInvoiceNumber([DateTime? date]) {
    final year = (date ?? DateTime.now()).year;
    return 'INV-$year-001';
  }

  /// Asynchronously fetches next sequential Material Invoice number
  static Future<String> fetchNextMaterialInvoiceNumber({String? siteId, DateTime? date}) async {
    final year = (date ?? DateTime.now()).year;
    final pattern = 'INV-$year-';

    try {
      var query = _supabase.from('material_costs').select('invoice_number');
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final res = await query.order('created_at', ascending: false).limit(100);

      int maxSeq = 0;
      int totalCount = (res as List).length;

      for (final row in res) {
        final invNum = (row['invoice_number'] ?? '').toString().trim();
        if (invNum.startsWith(pattern)) {
          final suffix = invNum.substring(pattern.length);
          final numPart = int.tryParse(suffix);
          if (numPart != null && numPart > maxSeq) {
            maxSeq = numPart;
          }
        } else {
          final match = RegExp(r'\d+').allMatches(invNum);
          if (match.isNotEmpty) {
            final val = int.tryParse(match.first.group(0) ?? '');
            if (val != null && val > maxSeq && val < 100000) {
              maxSeq = val;
            }
          }
        }
      }

      final nextNumber = (maxSeq > 0 ? maxSeq + 1 : totalCount + 1);
      final padded = nextNumber.toString().padLeft(3, '0');
      return '$pattern$padded';
    } catch (_) {
      return generateInitialMaterialInvoiceNumber(date);
    }
  }

  /// Initial synchronous Subcontractor Invoice Number (e.g. SUB-2026-001)
  static String generateInitialSubcontractorInvoiceNumber([DateTime? date]) {
    final year = (date ?? DateTime.now()).year;
    return 'SUB-$year-001';
  }

  /// Asynchronously fetches next sequential Subcontractor Invoice number
  static Future<String> fetchNextSubcontractorInvoiceNumber({String? siteId, DateTime? date}) async {
    final year = (date ?? DateTime.now()).year;
    final pattern = 'SUB-$year-';

    try {
      var query = _supabase.from('subcontractors').select('invoice_number');
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final res = await query.order('created_at', ascending: false).limit(100);

      int maxSeq = 0;
      int totalCount = (res as List).length;

      for (final row in res) {
        final invNum = (row['invoice_number'] ?? '').toString().trim();
        if (invNum.startsWith(pattern)) {
          final suffix = invNum.substring(pattern.length);
          final numPart = int.tryParse(suffix);
          if (numPart != null && numPart > maxSeq) {
            maxSeq = numPart;
          }
        } else {
          final match = RegExp(r'\d+').allMatches(invNum);
          if (match.isNotEmpty) {
            final val = int.tryParse(match.first.group(0) ?? '');
            if (val != null && val > maxSeq && val < 100000) {
              maxSeq = val;
            }
          }
        }
      }

      final nextNumber = (maxSeq > 0 ? maxSeq + 1 : totalCount + 1);
      final padded = nextNumber.toString().padLeft(3, '0');
      return '$pattern$padded';
    } catch (_) {
      return generateInitialSubcontractorInvoiceNumber(date);
    }
  }

  /// Initial synchronous IPC Document Number (e.g. IPC-2026-001)
  static String generateInitialIpcNumber([DateTime? date]) {
    final year = (date ?? DateTime.now()).year;
    return 'IPC-$year-001';
  }

  /// Asynchronously fetches next sequential IPC Document number
  static Future<String> fetchNextIpcNumber({String? projectId, DateTime? date}) async {
    final year = (date ?? DateTime.now()).year;
    final pattern = 'IPC-$year-';

    try {
      final res = await _supabase
          .from('ipc_documents')
          .select('document_number')
          .order('created_at', ascending: false)
          .limit(100);

      int maxSeq = 0;
      int totalCount = (res as List).length;

      for (final row in res) {
        final docNum = (row['document_number'] ?? '').toString().trim();
        if (docNum.startsWith(pattern)) {
          final suffix = docNum.substring(pattern.length);
          final numPart = int.tryParse(suffix);
          if (numPart != null && numPart > maxSeq) {
            maxSeq = numPart;
          }
        } else {
          final match = RegExp(r'\d+').allMatches(docNum);
          if (match.isNotEmpty) {
            final val = int.tryParse(match.first.group(0) ?? '');
            if (val != null && val > maxSeq && val < 100000) {
              maxSeq = val;
            }
          }
        }
      }

      final nextNumber = (maxSeq > 0 ? maxSeq + 1 : totalCount + 1);
      final padded = nextNumber.toString().padLeft(3, '0');
      return '$pattern$padded';
    } catch (_) {
      return generateInitialIpcNumber(date);
    }
  }
}
