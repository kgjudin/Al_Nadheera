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
      dSheet.getRangeByName('A1:K1').merge();
      final t1 = dSheet.getRangeByName('A1');
      t1.setText(projectName);
      t1.cellStyle.bold = true;
      t1.cellStyle.fontSize = 11;
      t1.cellStyle.hAlign = xlsio.HAlignType.center;

      dSheet.getRangeByName('A2:K2').merge();
      final t2 = dSheet.getRangeByName('A2');
      t2.setText('MAIN CONTRACTOR : ${document.mainContractor.toUpperCase()}   |   SUB CONTRACTOR : ${document.subContractor.toUpperCase()}');
      t2.cellStyle.bold = true;
      t2.cellStyle.fontSize = 10;
      t2.cellStyle.hAlign = xlsio.HAlignType.center;

      dSheet.getRangeByName('A3:K3').merge();
      final t3 = dSheet.getRangeByName('A3');
      t3.setText('IPA # ${document.documentNumber} Until ${document.date.toIso8601String().split("T")[0]}');
      t3.cellStyle.bold = true;
      t3.cellStyle.fontSize = 9.5;
      t3.cellStyle.hAlign = xlsio.HAlignType.right;

      dSheet.getRangeByName('A1:K3').cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      // Column Headers
      final dHeaders = [
        'Item No.',
        'Item Description',
        'Unit',
        'Rate',
        'Prev Qty',
        'Prev Amount BD',
        'This Qty',
        'This Amount BD',
        'Cumul Qty',
        'Cumul Amount BD',
        'as per site'
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
        } else if (c >= 3 && c <= 9) {
          cell.cellStyle.hAlign = xlsio.HAlignType.right;
        }
      }

      int dRow = 5;
      final startRow = dRow;
      for (final it in document.deductions) {
        final rowRange = dSheet.getRangeByIndex(dRow, 1, dRow, 11);
        rowRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        rowRange.cellStyle.vAlign = xlsio.VAlignType.center;

        if (it.isHighlighted) {
          rowRange.cellStyle.backColor = it.highlightColorHex;
        }

        dSheet.getRangeByIndex(dRow, 1).setText(it.itemNumber ?? '');
        dSheet.getRangeByIndex(dRow, 2).setText(it.description);
        dSheet.getRangeByIndex(dRow, 3).setText(it.unit ?? '');

        if (it.contractRate != null) {
          final c = dSheet.getRangeByIndex(dRow, 4);
          c.setNumber(it.contractRate!);
          c.numberFormat = '#,##0.000';
        }

        if (it.previousQuantity != null) {
          final c = dSheet.getRangeByIndex(dRow, 5);
          c.setNumber(it.previousQuantity!);
          c.numberFormat = '#,##0.000';
        }

        if (it.previousAmount != null) {
          final c = dSheet.getRangeByIndex(dRow, 6);
          c.setNumber(it.previousAmount!);
          c.numberFormat = '#,##0.000';
        }

        if (it.thisPeriodQuantity != null) {
          final c = dSheet.getRangeByIndex(dRow, 7);
          c.setNumber(it.thisPeriodQuantity!);
          c.numberFormat = '#,##0.000';
        }

        if (it.thisPeriodAmount != null) {
          final c = dSheet.getRangeByIndex(dRow, 8);
          c.setNumber(it.thisPeriodAmount!);
          c.numberFormat = '#,##0.000';
        }

        if (it.cumulativeQuantity != null) {
          final c = dSheet.getRangeByIndex(dRow, 9);
          c.setNumber(it.cumulativeQuantity!);
          c.numberFormat = '#,##0.000';
        }

        if (it.cumulativeAmount != null) {
          final c = dSheet.getRangeByIndex(dRow, 10);
          c.setNumber(it.cumulativeAmount!);
          c.numberFormat = '#,##0.000';
        }

        dSheet.getRangeByIndex(dRow, 11).setText(it.remarks ?? '');

        dRow++;
      }

      // Total Row
      final totalRow = dRow;
      final totalRange = dSheet.getRangeByIndex(totalRow, 1, totalRow, 11);
      totalRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      totalRange.cellStyle.backColor = '#D9D9D9';
      totalRange.cellStyle.vAlign = xlsio.VAlignType.center;

      dSheet.getRangeByIndex(totalRow, 1, totalRow, 4).merge();
      final tLabel = dSheet.getRangeByIndex(totalRow, 1);
      tLabel.setText('TOTAL DEDUCTION FOR MATERIAL (TO SUMMARY)');
      tLabel.cellStyle.bold = true;
      tLabel.cellStyle.fontSize = 9.5;

      if (document.deductions.isNotEmpty) {
        final prevTotalCell = dSheet.getRangeByIndex(totalRow, 6);
        prevTotalCell.setFormula('=SUM(F$startRow:F${totalRow - 1})');
        prevTotalCell.numberFormat = '#,##0.000';
        prevTotalCell.cellStyle.bold = true;

        final thisTotalCell = dSheet.getRangeByIndex(totalRow, 8);
        thisTotalCell.setFormula('=SUM(H$startRow:H${totalRow - 1})');
        thisTotalCell.numberFormat = '#,##0.000';
        thisTotalCell.cellStyle.bold = true;

        final cumTotalCell = dSheet.getRangeByIndex(totalRow, 10);
        cumTotalCell.setFormula('=SUM(J$startRow:J${totalRow - 1})');
        cumTotalCell.numberFormat = '#,##0.000';
        cumTotalCell.cellStyle.bold = true;
      }

      dSheet.getRangeByName('A1').columnWidth = 8.0;
      dSheet.getRangeByName('B1').columnWidth = 32.0;
      dSheet.getRangeByName('C1').columnWidth = 8.0;
      dSheet.getRangeByName('D1').columnWidth = 12.0;
      dSheet.getRangeByName('E1').columnWidth = 12.0;
      dSheet.getRangeByName('F1').columnWidth = 15.0;
      dSheet.getRangeByName('G1').columnWidth = 12.0;
      dSheet.getRangeByName('H1').columnWidth = 15.0;
      dSheet.getRangeByName('I1').columnWidth = 12.0;
      dSheet.getRangeByName('J1').columnWidth = 15.0;
      dSheet.getRangeByName('K1').columnWidth = 14.0;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> generateExcelBytes(IpcDocument document) => generateExcel(document);
}
