import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../../models/ipc_model.dart';

class IpcExcelGenerator {
  static Future<Uint8List> generateExcel(IpcDocument document) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'IPC Bill';

    final projectName = document.projectName.toUpperCase().startsWith('PROJECT:')
        ? document.projectName.toUpperCase()
        : 'PROJECT: ${document.projectName.toUpperCase()}';

    // 1. Row 1: Project Name Banner (A1:D1 merged for project name, E1 & F1 empty with borders)
    sheet.getRangeByName('A1:D1').merge();
    final pRange = sheet.getRangeByName('A1');
    pRange.setText(projectName);
    pRange.cellStyle.bold = true;
    pRange.cellStyle.fontSize = 11;
    pRange.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.getRangeByName('A1:F1').cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    // 2. Row 2: Table Headers
    final headers = ['Item', 'Description', 'unit', 'quantity', 'rate', 'Amount'];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(2, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#F8FAFC';
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      if (col == 0 || col == 2) {
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
      } else if (col >= 3) {
        cell.cellStyle.hAlign = xlsio.HAlignType.right;
      } else {
        cell.cellStyle.hAlign = xlsio.HAlignType.left;
      }
    }

    // 3. Rows 3..N: Data rows
    int currentRow = 3;
    final itemRows = <int>[];

    for (final item in document.items) {
      final rowRange = sheet.getRangeByIndex(currentRow, 1, currentRow, 6);
      rowRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      rowRange.cellStyle.vAlign = xlsio.VAlignType.center;

      if (item.isHeading) {
        // Class Heading
        sheet.getRangeByIndex(currentRow, 1).setText('');
        final descCell = sheet.getRangeByIndex(currentRow, 2);
        descCell.setText(item.description);
        descCell.cellStyle.bold = true;
        descCell.cellStyle.underline = true;
        descCell.cellStyle.fontSize = 10;
      } else if (item.isSubheading) {
        // Sub-heading or Clause note
        sheet.getRangeByIndex(currentRow, 1).setText('');
        final descCell = sheet.getRangeByIndex(currentRow, 2);
        descCell.setText(item.description);
        descCell.cellStyle.bold = true;
        descCell.cellStyle.fontSize = 9.5;
        if (item.description.toLowerCase().contains('clause') ||
            item.description.toLowerCase().contains('specification')) {
          descCell.cellStyle.underline = true;
        }
      } else {
        // Normal item row
        itemRows.add(currentRow);

        // Item Number
        final itemNoCell = sheet.getRangeByIndex(currentRow, 1);
        itemNoCell.setText(item.itemNumber ?? '');
        itemNoCell.cellStyle.hAlign = xlsio.HAlignType.center;

        // Description
        final descCell = sheet.getRangeByIndex(currentRow, 2);
        descCell.setText(item.description);
        descCell.cellStyle.hAlign = xlsio.HAlignType.left;

        // Unit
        final unitCell = sheet.getRangeByIndex(currentRow, 3);
        unitCell.setText(item.unit ?? '');
        unitCell.cellStyle.hAlign = xlsio.HAlignType.center;

        // Quantity (bold, 3 decimals)
        final qtyCell = sheet.getRangeByIndex(currentRow, 4);
        qtyCell.setNumber(item.quantity);
        qtyCell.numberFormat = '#,##0.000';
        qtyCell.cellStyle.bold = true;
        qtyCell.cellStyle.hAlign = xlsio.HAlignType.right;

        // Rate (3 decimals)
        final rateCell = sheet.getRangeByIndex(currentRow, 5);
        rateCell.setNumber(item.rate);
        rateCell.numberFormat = '#,##0.000';
        rateCell.cellStyle.hAlign = xlsio.HAlignType.right;

        // Amount formula: Quantity * Rate
        final amtCell = sheet.getRangeByIndex(currentRow, 6);
        amtCell.setFormula('=D$currentRow*E$currentRow');
        amtCell.numberFormat = '#,##0.000';
        amtCell.cellStyle.hAlign = xlsio.HAlignType.right;
      }

      currentRow++;
    }

    // 4. Total Amount Summary Row
    final totalRowRange = sheet.getRangeByIndex(currentRow, 1, currentRow, 6);
    totalRowRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    totalRowRange.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.double;

    final totalLabelCell = sheet.getRangeByIndex(currentRow, 2);
    totalLabelCell.setText('TOTAL AMOUNT (BHD)');
    totalLabelCell.cellStyle.bold = true;
    totalLabelCell.cellStyle.fontSize = 10;

    final totalValueCell = sheet.getRangeByIndex(currentRow, 6);
    if (itemRows.isNotEmpty) {
      totalValueCell.setFormula('=SUM(F${itemRows.first}:F${itemRows.last})');
    } else {
      totalValueCell.setNumber(document.totalAmount);
    }
    totalValueCell.numberFormat = '#,##0.000';
    totalValueCell.cellStyle.bold = true;
    totalValueCell.cellStyle.fontSize = 10;
    totalValueCell.cellStyle.hAlign = xlsio.HAlignType.right;

    // 5. Column Widths
    sheet.getRangeByName('A1').columnWidth = 8.0;   // Item
    sheet.getRangeByName('B1').columnWidth = 48.0;  // Description
    sheet.getRangeByName('C1').columnWidth = 8.0;   // unit
    sheet.getRangeByName('D1').columnWidth = 14.0;  // quantity
    sheet.getRangeByName('E1').columnWidth = 14.0;  // rate
    sheet.getRangeByName('F1').columnWidth = 18.0;  // Amount

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> generateExcelBytes(IpcDocument document) => generateExcel(document);
}
