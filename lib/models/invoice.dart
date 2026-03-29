class Invoice {
  final int? id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final int clientId;
  final int projectId;
  final String? projectAddress;
  final double labourSubtotal;
  final double materialsSubtotal;
  final double materialsPickupCost;
  final double otherCosts;
  final String? otherCostsDescription;
  final double discountAmount;
  final String? discountDescription;
  final double discountPercent;
  final String? tax1Name;
  final double? tax1Rate;
  final double tax1Amount;
  final String? tax1RegistrationNumber;
  final String? tax2Name;
  final double? tax2Rate;
  final double tax2Amount;
  final String? tax2RegistrationNumber;
  final double subtotal;
  final double totalAmount;
  final String terms;
  final String? poNumber;
  final bool isPaid;
  final double? amountPaid;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final bool isDeleted;
  final String? deletedReasonCode;
  final DateTime? deletedDate;
  final String? deletedNotes;
  final int? supersededByInvoiceId;
  final String? notes;
  final String? internalNotes;
  final String? workDescription;
  final bool isSent;
  final String invoiceType;

  // Display-only fields (non-persisted)
  final String? projectName;
  final String? clientName;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.clientId,
    required this.projectId,
    this.projectAddress,
    this.labourSubtotal = 0,
    this.materialsSubtotal = 0,
    this.materialsPickupCost = 0,
    this.otherCosts = 0,
    this.otherCostsDescription,
    this.discountAmount = 0,
    this.discountDescription,
    this.discountPercent = 0,
    this.tax1Name,
    this.tax1Rate,
    this.tax1Amount = 0,
    this.tax1RegistrationNumber,
    this.tax2Name,
    this.tax2Rate,
    this.tax2Amount = 0,
    this.tax2RegistrationNumber,
    this.subtotal = 0,
    this.totalAmount = 0,
    this.terms = 'Payable on Receipt',
    this.poNumber,
    this.isPaid = false,
    this.amountPaid,
    this.paymentDate,
    this.paymentMethod,
    this.isDeleted = false,
    this.deletedReasonCode,
    this.deletedDate,
    this.deletedNotes,
    this.supersededByInvoiceId,
    this.notes,
    this.internalNotes,
    this.workDescription,
    this.isSent = false,
    this.invoiceType = 'progress',
    this.projectName,
    this.clientName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'client_id': clientId,
      'project_id': projectId,
      'project_address': projectAddress,
      'labour_subtotal': labourSubtotal,
      'materials_subtotal': materialsSubtotal,
      'materials_pickup_cost': materialsPickupCost,
      'other_costs': otherCosts,
      'other_costs_description': otherCostsDescription,
      'discount_amount': discountAmount,
      'discount_description': discountDescription,
      'discount_percent': discountPercent,
      'tax1_name': tax1Name,
      'tax1_rate': tax1Rate,
      'tax1_amount': tax1Amount,
      'tax1_registration_number': tax1RegistrationNumber,
      'tax2_name': tax2Name,
      'tax2_rate': tax2Rate,
      'tax2_amount': tax2Amount,
      'tax2_registration_number': tax2RegistrationNumber,
      'subtotal': subtotal,
      'total_amount': totalAmount,
      'terms': terms,
      'po_number': poNumber,
      'is_paid': isPaid ? 1 : 0,
      'amount_paid': amountPaid,
      'payment_date': paymentDate?.toIso8601String(),
      'payment_method': paymentMethod,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_reason_code': deletedReasonCode,
      'deleted_date': deletedDate?.toIso8601String(),
      'deleted_notes': deletedNotes,
      'superseded_by_invoice_id': supersededByInvoiceId,
      'notes': notes,
      'internal_notes': internalNotes,
      'work_description': workDescription,
      'is_sent': isSent ? 1 : 0,
      'invoice_type': invoiceType,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      invoiceDate: DateTime.parse(map['invoice_date'] as String),
      clientId: map['client_id'] as int,
      projectId: map['project_id'] as int,
      projectAddress: map['project_address'] as String?,
      labourSubtotal: (map['labour_subtotal'] as num?)?.toDouble() ?? 0,
      materialsSubtotal: (map['materials_subtotal'] as num?)?.toDouble() ?? 0,
      materialsPickupCost: (map['materials_pickup_cost'] as num?)?.toDouble() ?? 0,
      otherCosts: (map['other_costs'] as num?)?.toDouble() ?? 0,
      otherCostsDescription: map['other_costs_description'] as String?,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      discountDescription: map['discount_description'] as String?,
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0,
      tax1Name: map['tax1_name'] as String?,
      tax1Rate: (map['tax1_rate'] as num?)?.toDouble(),
      tax1Amount: (map['tax1_amount'] as num?)?.toDouble() ?? 0,
      tax1RegistrationNumber: map['tax1_registration_number'] as String?,
      tax2Name: map['tax2_name'] as String?,
      tax2Rate: (map['tax2_rate'] as num?)?.toDouble(),
      tax2Amount: (map['tax2_amount'] as num?)?.toDouble() ?? 0,
      tax2RegistrationNumber: map['tax2_registration_number'] as String?,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      terms: map['terms'] as String? ?? 'Payable on Receipt',
      poNumber: map['po_number'] as String?,
      isPaid: (map['is_paid'] as int?) == 1,
      amountPaid: (map['amount_paid'] as num?)?.toDouble(),
      paymentDate: map['payment_date'] != null ? DateTime.parse(map['payment_date'] as String) : null,
      paymentMethod: map['payment_method'] as String?,
      isDeleted: (map['is_deleted'] as int?) == 1,
      deletedReasonCode: map['deleted_reason_code'] as String?,
      deletedDate: map['deleted_date'] != null ? DateTime.parse(map['deleted_date'] as String) : null,
      deletedNotes: map['deleted_notes'] as String?,
      supersededByInvoiceId: map['superseded_by_invoice_id'] as int?,
      notes: map['notes'] as String?,
      internalNotes: map['internal_notes'] as String?,
      workDescription: map['work_description'] as String?,
      isSent: (map['is_sent'] as int?) == 1,
      invoiceType: map['invoice_type'] as String? ?? 'progress',
      projectName: map['project_name'] as String?,
      clientName: map['client_name'] as String?,
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    int? clientId,
    int? projectId,
    String? projectAddress,
    double? labourSubtotal,
    double? materialsSubtotal,
    double? materialsPickupCost,
    double? otherCosts,
    String? otherCostsDescription,
    double? discountAmount,
    String? discountDescription,
    double? discountPercent,
    String? tax1Name,
    double? tax1Rate,
    double? tax1Amount,
    String? tax1RegistrationNumber,
    String? tax2Name,
    double? tax2Rate,
    double? tax2Amount,
    String? tax2RegistrationNumber,
    double? subtotal,
    double? totalAmount,
    String? terms,
    String? poNumber,
    bool? isPaid,
    double? amountPaid,
    DateTime? paymentDate,
    String? paymentMethod,
    bool? isDeleted,
    String? deletedReasonCode,
    DateTime? deletedDate,
    String? deletedNotes,
    int? supersededByInvoiceId,
    String? notes,
    String? internalNotes,
    String? workDescription,
    bool? isSent,
    String? invoiceType,
    String? projectName,
    String? clientName,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      clientId: clientId ?? this.clientId,
      projectId: projectId ?? this.projectId,
      projectAddress: projectAddress ?? this.projectAddress,
      labourSubtotal: labourSubtotal ?? this.labourSubtotal,
      materialsSubtotal: materialsSubtotal ?? this.materialsSubtotal,
      materialsPickupCost: materialsPickupCost ?? this.materialsPickupCost,
      otherCosts: otherCosts ?? this.otherCosts,
      otherCostsDescription: otherCostsDescription ?? this.otherCostsDescription,
      discountAmount: discountAmount ?? this.discountAmount,
      discountDescription: discountDescription ?? this.discountDescription,
      discountPercent: discountPercent ?? this.discountPercent,
      tax1Name: tax1Name ?? this.tax1Name,
      tax1Rate: tax1Rate ?? this.tax1Rate,
      tax1Amount: tax1Amount ?? this.tax1Amount,
      tax1RegistrationNumber: tax1RegistrationNumber ?? this.tax1RegistrationNumber,
      tax2Name: tax2Name ?? this.tax2Name,
      tax2Rate: tax2Rate ?? this.tax2Rate,
      tax2Amount: tax2Amount ?? this.tax2Amount,
      tax2RegistrationNumber: tax2RegistrationNumber ?? this.tax2RegistrationNumber,
      subtotal: subtotal ?? this.subtotal,
      totalAmount: totalAmount ?? this.totalAmount,
      terms: terms ?? this.terms,
      poNumber: poNumber ?? this.poNumber,
      isPaid: isPaid ?? this.isPaid,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedReasonCode: deletedReasonCode ?? this.deletedReasonCode,
      deletedDate: deletedDate ?? this.deletedDate,
      deletedNotes: deletedNotes ?? this.deletedNotes,
      supersededByInvoiceId: supersededByInvoiceId ?? this.supersededByInvoiceId,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      workDescription: workDescription ?? this.workDescription,
      isSent: isSent ?? this.isSent,
      invoiceType: invoiceType ?? this.invoiceType,
      projectName: projectName ?? this.projectName,
      clientName: clientName ?? this.clientName,
    );
  }
}
