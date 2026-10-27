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

      if (item.isHighlighted) {
        rowRange.cellStyle.backColor = item.highlightColorHex;
      }

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

    // 6. Optional Material Deduction Sheet
    if (document.hasDeductions) {
      final xlsio.Worksheet dSheet = workbook.worksheets.addWithName('Material Deduction');

      // Top Header
      dSheet.getRangeByName('A1:F1').merge();
      final t1 = dSheet.getRangeByName('A1');
      t1.setText(projectName);
      t1.cellStyle.bold = true;
      t1.cellStyle.fontSize = 11;
      t1.cellStyle.hAlign = xlsio.HAlignType.center;

      dSheet.getRangeByName('A2:F2').merge();
      final t2 = dSheet.getRangeByName('A2');
      t2.setText('MAIN CONTRACTOR : ${document.mainContractor.toUpperCase()}   |   SUB CONTRACTOR : ${document.subContractor.toUpperCase()}');
      t2.cellStyle.bold = true;
      t2.cellStyle.fontSize = 10;
      t2.cellStyle.hAlign = xlsio.HAlignType.center;

      dSheet.getRangeByName('A3:F3').merge();
      final t3 = dSheet.getRangeByName('A3');
      t3.setText('IPA # ${document.documentNumber} Until ${document.date.toIso8601String().split("T")[0]}');
      t3.cellStyle.bold = true;
      t3.cellStyle.fontSize = 9.5;
      t3.cellStyle.hAlign = xlsio.HAlignType.right;

      dSheet.getRangeByName('A1:F3').cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // Column Headers
      final dHeaders = [
        'Item No.',
        'Item Description',
        'Unit',
        'Quantity',
        'Rate (BD)',
        'Amount (BD)',
      ];
      for (int c = 0; c < dHeaders.length; c++) {
        final cell = dSheet.getRangeByIndex(4, c + 1);
        cell.setText(dHeaders[c]);
        cell.cellStyle.bold = true;
        cell.cellStyle.fontSize = 9.5;
        cell.cellStyle.backColor = '#FDE8D7';
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        if (c == 0 || c == 2) {
          cell.cellStyle.hAlign = xlsio.HAlignType.center;
        } else if (c >= 3) {
          cell.cellStyle.hAlign = xlsio.HAlignType.right;
        } else {
          cell.cellStyle.hAlign = xlsio.HAlignType.left;
        }
      }

      int dRow = 5;
      final startRow = dRow;
      for (final it in document.deductions) {
        final rowRange = dSheet.getRangeByIndex(dRow, 1, dRow, 6);
        rowRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        rowRange.cellStyle.vAlign = xlsio.VAlignType.center;

        if (it.isHighlighted) {
          rowRange.cellStyle.backColor = it.highlightColorHex;
        }

        final itemNoCell = dSheet.getRangeByIndex(dRow, 1);
        itemNoCell.setText(it.itemNumber ?? '');
        itemNoCell.cellStyle.hAlign = xlsio.HAlignType.center;

        final descCell = dSheet.getRangeByIndex(dRow, 2);
        descCell.setText(it.description);
        descCell.cellStyle.hAlign = xlsio.HAlignType.left;

        final unitCell = dSheet.getRangeByIndex(dRow, 3);
        unitCell.setText(it.unit ?? '');
        unitCell.cellStyle.hAlign = xlsio.HAlignType.center;

        if (it.effectiveQuantity > 0) {
          final c = dSheet.getRangeByIndex(dRow, 4);
          c.setNumber(it.effectiveQuantity);
          c.numberFormat = '#,##0.000';
          c.cellStyle.hAlign = xlsio.HAlignType.right;
        }

        if (it.effectiveRate > 0) {
          final c = dSheet.getRangeByIndex(dRow, 5);
          c.setNumber(it.effectiveRate);
          c.numberFormat = '#,##0.000';
          c.cellStyle.hAlign = xlsio.HAlignType.right;
        }

        final amtCell = dSheet.getRangeByIndex(dRow, 6);
        if (it.effectiveQuantity > 0 && it.effectiveRate > 0) {
          amtCell.setFormula('=D$dRow*E$dRow');
        } else {
          amtCell.setNumber(it.effectiveAmount);
        }
        amtCell.numberFormat = '#,##0.000';
        amtCell.cellStyle.bold = true;
        amtCell.cellStyle.hAlign = xlsio.HAlignType.right;

        dRow++;
      }

      // Total Row
      final totalRow = dRow;
      final totalRange = dSheet.getRangeByIndex(totalRow, 1, totalRow, 6);
      totalRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      totalRange.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.double;
      totalRange.cellStyle.backColor = '#D9D9D9';
      totalRange.cellStyle.vAlign = xlsio.VAlignType.center;

      dSheet.getRangeByIndex(totalRow, 1, totalRow, 5).merge();
      final tLabel = dSheet.getRangeByIndex(totalRow, 1);
      tLabel.setText('TOTAL DEDUCTION FOR MATERIAL (TO SUMMARY)');
      tLabel.cellStyle.bold = true;
      tLabel.cellStyle.fontSize = 9.5;

      if (document.deductions.isNotEmpty) {
        final totalCell = dSheet.getRangeByIndex(totalRow, 6);
        totalCell.setFormula('=SUM(F$startRow:F${totalRow - 1})');
        totalCell.numberFormat = '#,##0.000';
        totalCell.cellStyle.bold = true;
        totalCell.cellStyle.hAlign = xlsio.HAlignType.right;
      }

      dSheet.getRangeByName('A1').columnWidth = 10.0;
      dSheet.getRangeByName('B1').columnWidth = 40.0;
      dSheet.getRangeByName('C1').columnWidth = 10.0;
      dSheet.getRangeByName('D1').columnWidth = 14.0;
      dSheet.getRangeByName('E1').columnWidth = 14.0;
      dSheet.getRangeByName('F1').columnWidth = 18.0;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> generateExcelBytes(IpcDocument document) => generateExcel(document);
}
