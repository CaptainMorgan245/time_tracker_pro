// lib/models/analytics_models.dart

enum AnalyticsView { none, singleProjectCard, projectListTable, personnelSummary, customReport, companyExpenses, importErrors }
enum ReportType { activeProjects, completedProjects }
enum ReportSubject { projects, personnel, timeEntries }

class CustomReportSettings {
  final ReportSubject subject;
  final Map<String, bool> includes;
  final int? projectId;
  final int? clientId;
  final int? employeeId;
  final int? costCodeId;
  final DateTime? startDate;
  final DateTime? endDate;

  CustomReportSettings({
    required this.subject,
    required this.includes,
    this.projectId,
    this.clientId,
    this.employeeId,
    this.costCodeId,
    this.startDate,
    this.endDate,
  });
}

// lib/models/analytics_models.dart