import 'package:flutter_test/flutter_test.dart';
import 'package:al_nadheera_construction/services/employee_id_service.dart';

void main() {
  group('EmployeeIdService Tests', () {
    test('formatId formats number to ANCC-EMP-(number) with 3 digits', () {
      expect(EmployeeIdService.formatId(1), 'ANCC-EMP-001');
      expect(EmployeeIdService.formatId(2), 'ANCC-EMP-002');
      expect(EmployeeIdService.formatId(42), 'ANCC-EMP-042');
      expect(EmployeeIdService.formatId(105), 'ANCC-EMP-105');
      expect(EmployeeIdService.formatId(1234), 'ANCC-EMP-1234');
    });

    test('generateInitialEmployeeId defaults to ANCC-EMP-001', () {
      expect(EmployeeIdService.generateInitialEmployeeId(), 'ANCC-EMP-001');
      expect(EmployeeIdService.generateInitialEmployeeId(5), 'ANCC-EMP-005');
    });
  });
}
