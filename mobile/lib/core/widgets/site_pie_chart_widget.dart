import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/site_model.dart';

class SitePieChartWidget extends StatefulWidget {
  final Site site;
  final bool isCard;
  final bool showTitle;
  final VoidCallback? onTapDetails;

  const SitePieChartWidget({
    super.key,
    required this.site,
    this.isCard = true,
    this.showTitle = true,
    this.onTapDetails,
  });

  @override
  State<SitePieChartWidget> createState() => _SitePieChartWidgetState();
}

class _SitePieChartWidgetState extends State<SitePieChartWidget> {
  // 0: By Module (Expenses Breakdown), 1: Budget Utilization (Expenses + Remaining)
  int _viewMode = 0;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final hasBudget = site.assignedBudget > 0;
    final totalSpent = site.spent;
    final remainingBudget = max(0.0, site.assignedBudget - totalSpent);
    final isOverBudget = hasBudget && totalSpent > site.assignedBudget;
    final overBudgetAmount = isOverBudget ? (totalSpent - site.assignedBudget) : 0.0;

    // Define standard categories and their colors
    final rawModules = [
      _SiteCategoryData(
        title: 'Labour Costs',
        amount: site.labourSpent,
        icon: Icons.engineering_outlined,
        color: const Color(0xFFD97706), // Amber / Warm Orange
      ),
      _SiteCategoryData(
        title: 'Material Costs',
        amount: site.materialSpent,
        icon: Icons.inventory_outlined,
        color: const Color(0xFF10B981), // Emerald Green
      ),
      _SiteCategoryData(
        title: 'Sub-Contractors',
        amount: site.subcontractorSpent,
        icon: Icons.handshake_outlined,
        color: const Color(0xFF8B5CF6), // Purple
      ),
      _SiteCategoryData(
        title: 'Summary (Expenses)',
        amount: site.summarySpent,
        icon: Icons.table_chart_outlined,
        color: const Color(0xFF0B5ED7), // Royal Blue
      ),
      _SiteCategoryData(
        title: 'Additional Expenses',
        amount: site.additionalSpent,
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFEC4899), // Pink
      ),
    ];

    final List<_SitePieSlice> slices = [];
    double chartTotal = 0.0;

    if (_viewMode == 0 || !hasBudget) {
      // MODE 0: Expense breakdown only across modules
      chartTotal = totalSpent > 0 ? totalSpent : 1.0;
      for (final m in rawModules) {
        if (m.amount > 0) {
          slices.add(_SitePieSlice(
            label: m.title,
            amount: m.amount,
            color: m.color,
            icon: m.icon,
          ));
        }
      }
    } else {
      // MODE 1: Budget Utilization (All modules + Remaining/Over Budget)
      chartTotal = max(site.assignedBudget, totalSpent);
      for (final m in rawModules) {
        if (m.amount > 0) {
          slices.add(_SitePieSlice(
            label: m.title,
            amount: m.amount,
            color: m.color,
            icon: m.icon,
          ));
        }
      }
      if (!isOverBudget && remainingBudget > 0) {
        slices.add(_SitePieSlice(
          label: 'Remaining Budget',
          amount: remainingBudget,
          color: const Color(0xFF059669), // Dark Emerald Green
          icon: Icons.savings_outlined,
        ));
      } else if (isOverBudget && overBudgetAmount > 0) {
        slices.add(_SitePieSlice(
          label: 'Over Budget',
          amount: overBudgetAmount,
          color: const Color(0xFFDC2626), // Crimson Red
          icon: Icons.warning_amber_rounded,
        ));
      }
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Mode Selector
        if (widget.showTitle) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B5ED7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF0B5ED7)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Financial Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                ],
              ),
              if (hasBudget)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton(0, 'Expenses'),
                      _buildModeButton(1, 'Budget'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Center Donut Chart with Center Metric
        Center(
          child: SizedBox(
            height: 180,
            width: 180,
            child: CustomPaint(
              painter: _SitePieChartPainter(
                slices: slices,
                total: totalSpent > 0 || (hasBudget && _viewMode == 1) ? chartTotal : 0.0,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _viewMode == 0 || !hasBudget
                            ? 'TOTAL SPENT'
                            : (isOverBudget ? 'OVER BUDGET' : 'REMAINING'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isOverBudget && _viewMode == 1 ? Colors.red : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currencyFormat.format(
                          _viewMode == 0 || !hasBudget
                              ? totalSpent
                              : (isOverBudget ? overBudgetAmount : remainingBudget),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget && _viewMode == 1
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0A2540),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasBudget && totalSpent > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${((totalSpent / site.assignedBudget) * 100).toStringAsFixed(1)}% of Budget',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOverBudget ? Colors.red.shade700 : const Color(0xFF0B5ED7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Legend & Module List
        if (slices.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: CenterAlienation.center,
            child: Text(
              'No expense logs recorded for this site yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slices.map((s) {
              final pct = chartTotal > 0 ? ((s.amount / chartTotal) * 100).toStringAsFixed(1) : '0.0';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(s.icon, size: 14, color: s.color),
                    const SizedBox(width: 5),
                    Text(
                      s.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0A2540)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${currencyFormat.format(s.amount)} ($pct%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: s.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );

    if (!widget.isCard) return content;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: content,
    );
  }

  Widget _buildModeButton(int index, String label) {
    final isSelected = _viewMode == index;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B5ED7) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _SiteCategoryData {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  _SiteCategoryData({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });
}

class _SitePieSlice {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  _SitePieSlice({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class _SitePieChartPainter extends CustomPainter {
  final List<_SitePieSlice> slices;
  final double total;

  _SitePieChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    if (total <= 0 || slices.isEmpty) {
      final placeholderPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;
      canvas.drawCircle(center, radius, placeholderPaint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -pi / 2;

    for (final slice in slices) {
      if (slice.amount <= 0) continue;
      final sweepAngle = (slice.amount / total) * 2 * pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;

      // Draw arc with tiny gap if multiple slices
      final gap = slices.length > 1 ? 0.03 : 0.0;
      canvas.drawArc(rect, startAngle, max(0.01, sweepAngle - gap), false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SitePieChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}

class CenterAlienation {
  static const center = Alignment.center;
}
