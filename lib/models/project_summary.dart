// lib/models/project_summary.dart

class ProjectSummary {
  final String projectName;
  final String? clientName;
  final String pricingModel;final double totalHours;
  final double totalCost;
  final double? billedValue; // Nullable for non-hourly projects
  final double? profitLoss; // Nullable for non-hourly projects

  ProjectSummary({
    required this.projectName,
    this.clientName,
    required this.pricingModel,
    required this.totalHours,
    required this.totalCost,
    this.billedValue,
    this.profitLoss,
  });
}
