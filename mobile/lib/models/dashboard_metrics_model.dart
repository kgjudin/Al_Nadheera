import 'site_model.dart';

class DashboardMetrics {
  final int totalSites;
  final int activeSites;
  final int totalEmployees;
  final double totalAssignedBudget;
  final double totalSpent;
  final double remainingBudget;
  final List<Site> recentSites;

  DashboardMetrics({
    required this.totalSites,
    required this.activeSites,
    required this.totalEmployees,
    required this.totalAssignedBudget,
    required this.totalSpent,
    required this.remainingBudget,
    required this.recentSites,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    var sitesList = json['recentSites'] as List? ?? [];
    List<Site> recentSites = sitesList.map((i) => Site.fromJson(i)).toList();

    return DashboardMetrics(
      totalSites: json['totalSites'] ?? 0,
      activeSites: json['activeSites'] ?? 0,
      totalEmployees: json['totalEmployees'] ?? 0,
      totalAssignedBudget: (json['totalAssignedBudget'] ?? 0).toDouble(),
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      remainingBudget: (json['remainingBudget'] ?? 0).toDouble(),
      recentSites: recentSites,
    );
  }
}
