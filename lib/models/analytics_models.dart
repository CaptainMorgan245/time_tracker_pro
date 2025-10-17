// lib/models/analytics_models.dart

enum AnalyticsView { none, singleProjectCard, projectListTable, personnelSummary, customReport, companyExpenses }
enum ReportType { activeProjects, completedProjects }
enum ReportSubject { projects, personnel }

class CustomReportSettings {
  final ReportSubject subject;
  final Map<String, bool> includes;
  final int? projectId;
  final int? clientId;
  final int? employeeId;
  final DateTime? startDate;
  final DateTime? endDate;

  CustomReportSettings({
    required this.subject,
    required this.includes,
    this.projectId,
    this.clientId,
    this.employeeId,
    this.startDate,
    this.endDate,
  });
}

// lib/models/analytics_models.dart