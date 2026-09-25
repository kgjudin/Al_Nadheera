import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/income_budget_model.dart';
import 'package:intl/intl.dart';

class PieChartWidget extends StatelessWidget {
  final double totalIncome;
  final List<IncomeExpense> expenses;

  const PieChartWidget({
    super.key,
    required this.totalIncome,
    required this.expenses,
  });

  static const List<Color> _sliceColors = [
    Color(0xFFE53935), // Red
    Color(0xFFFB8C00), // Orange
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFF3949AB), // Indigo
    Color(0xFFD81B60), // Pink
    Color(0xFF00897B), // Teal
    Color(0xFFFDD835), // Yellow
    Color(0xFF6D4C41), // Brown
    Color(0xFF546E7A), // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'QAR ', decimalDigits: 0);
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final remaining = max(0.0, totalIncome - totalSpent);
    final isOverBudget = totalSpent > totalIncome;

    // Build data slices
    final List<_PieSlice> slices = [];

    for (int i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      if (exp.amount > 0) {
        slices.add(_PieSlice(
          label: exp.title,
          amount: exp.amount,
          color: _sliceColors[i % _sliceColors.length],
        ));
      }
    }

    if (!isOverBudget && remaining > 0) {
      slices.add(_PieSlice(
        label: 'Remaining Balance',
        amount: remaining,
        color: const Color(0xFF43A047), // Green
      ));
    } else if (isOverBudget) {
      slices.add(_PieSlice(
        label: 'Over Budget',
        amount: totalSpent - totalIncome,
        color: const Color(0xFFB71C1C), // Dark Red
      ));
    }

    final chartTotal = totalIncome > 0 ? totalIncome : (totalSpent > 0 ? totalSpent : 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Expenditure Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Income: ${currencyFormat.format(totalIncome)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                painter: _PieChartPainter(slices: slices, total: chartTotal),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOverBudget ? 'Over Budget' : 'Remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverBudget ? Colors.red : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(isOverBudget ? (totalSpent - totalIncome) : remaining),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? Colors.red : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: slices.map((slice) {
                final pct = (slice.amount / chartTotal * 100).toStringAsFixed(1);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: slice.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: slice.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${slice.label}: ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${currencyFormat.format(slice.amount)} ($pct%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: slice.color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieSlice {
  final String label;
  final double amount;
  final Color color;

  _PieSlice({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;
  final double total;

  _PieChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || slices.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 13, paint);
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.amount / total) * 2 * pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.03, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}
