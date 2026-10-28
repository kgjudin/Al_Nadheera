import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service to generate standard, sequential Employee IDs
/// in the format ANCC-EMP-(number), e.g. ANCC-EMP-001, ANCC-EMP-002.
class EmployeeIdService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static const String prefix = 'ANCC-EMP-';

  /// Format sequence number into standard badge ID
  static String formatId(int sequence) {
    final padded = sequence.toString().padLeft(3, '0');
    return '$prefix$padded';
  }

  /// Initial synchronous fallback
  static String generateInitialEmployeeId([int sequence = 1]) {
    return formatId(sequence);
  }

  /// Asynchronously fetches the next sequential employee ID from the database
  static Future<String> fetchNextEmployeeId() async {
    try {
      final res = await _supabase
          .from('employees')
          .select('employee_id');

      int maxSeq = 0;
      final regExp = RegExp(r'ANCC-EMP-(\d+)', caseSensitive: false);

      for (final row in (res as List)) {
        final rawId = (row['employee_id'] ?? '').toString().trim();
        if (rawId.isEmpty) continue;

        final match = regExp.firstMatch(rawId);
        if (match != null) {
          final seq = int.tryParse(match.group(1) ?? '');
          if (seq != null && seq > maxSeq) {
            maxSeq = seq;
          }
        } else {
          // Check for numbers in other legacy formats (e.g. SA-001 or '2')
          final numMatch = RegExp(r'(\d+)').firstMatch(rawId);
          if (numMatch != null) {
            final val = int.tryParse(numMatch.group(1) ?? '');
            if (val != null && val > maxSeq && val < 100000) {
              maxSeq = val;
            }
          }
        }
      }

      final nextNumber = maxSeq + 1;
      return formatId(nextNumber);
    } catch (e) {
      debugPrint('Error generating next employee id: $e');
      return formatId(1);
    }
  }
}
