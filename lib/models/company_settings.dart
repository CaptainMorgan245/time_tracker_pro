class CompanySettings {
  final int id;
  final String? companyName;
  final String? companyAddress;
  final String? companyCity;
  final String? companyProvince;
  final String? companyPostalCode;
  final String? companyPhone;
  final String? companyEmail;
  final String defaultTax1Name;
  final double defaultTax1Rate;
  final String? defaultTax1RegistrationNumber;
  final String? defaultTax2Name;
  final double? defaultTax2Rate;
  final String? defaultTax2RegistrationNumber;
  final String defaultTerms;
  final double taxRate;
  final String postalCodeLabel;
  final String regionLabel;
  final String country;
  final String invoicePrefix;
  final int invoiceStartingNumber;
  final String? paymentEtransferEmail;

  CompanySettings({
    this.id = 1,
    this.companyName,
    this.companyAddress,
    this.companyCity,
    this.companyProvince,
    this.companyPostalCode,
    this.companyPhone,
    this.companyEmail,
    this.defaultTax1Name = 'GST',
    this.defaultTax1Rate = 0.05,
    this.defaultTax1RegistrationNumber,
    this.defaultTax2Name,
    this.defaultTax2Rate,
    this.defaultTax2RegistrationNumber,
    this.defaultTerms = 'Payable on Receipt',
    this.taxRate = 5.0,
    this.postalCodeLabel = 'Postal Code',
    this.regionLabel = 'Province',
    this.country = 'Canada',
    this.invoicePrefix = 'INV',
    this.invoiceStartingNumber = 1,
    this.paymentEtransferEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_name': companyName,
      'company_address': companyAddress,
      'company_city': companyCity,
      'company_province': companyProvince,
      'company_postal_code': companyPostalCode,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'default_tax1_name': defaultTax1Name,
      'default_tax1_rate': defaultTax1Rate,
      'default_tax1_registration_number': defaultTax1RegistrationNumber,
      'default_tax2_name': defaultTax2Name,
      'default_tax2_rate': defaultTax2Rate,
      'default_tax2_registration_number': defaultTax2RegistrationNumber,
      'default_terms': defaultTerms,
      'tax_rate': taxRate,
      'postal_code_label': postalCodeLabel,
      'region_label': regionLabel,
      'country': country,
      'invoice_prefix': invoicePrefix,
      'invoice_starting_number': invoiceStartingNumber,
      'payment_etransfer_email': paymentEtransferEmail,
    };
  }

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      id: map['id'] as int? ?? 1,
      companyName: map['company_name'] as String?,
      companyAddress: map['company_address'] as String?,
      companyCity: map['company_city'] as String?,
      companyProvince: map['company_province'] as String?,
      companyPostalCode: map['company_postal_code'] as String?,
      companyPhone: map['company_phone'] as String?,
      companyEmail: map['company_email'] as String?,
      defaultTax1Name: map['default_tax1_name'] as String? ?? 'GST',
      defaultTax1Rate: (map['default_tax1_rate'] as num?)?.toDouble() ?? 0.05,
      defaultTax1RegistrationNumber: map['default_tax1_registration_number'] as String?,
      defaultTax2Name: map['default_tax2_name'] as String?,
      defaultTax2Rate: (map['default_tax2_rate'] as num?)?.toDouble(),
      defaultTax2RegistrationNumber: map['default_tax2_registration_number'] as String?,
      defaultTerms: map['default_terms'] as String? ?? 'Payable on Receipt',
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 5.0,
      postalCodeLabel: (map['postal_code_label'] as String?) ?? 'Postal Code',
      regionLabel: (map['region_label'] as String?) ?? 'Province',
      country: (map['country'] as String?) ?? 'Canada',
      invoicePrefix: (map['invoice_prefix'] as String?) ?? 'INV',
      invoiceStartingNumber: (map['invoice_starting_number'] as int?) ?? 1,
      paymentEtransferEmail: map['payment_etransfer_email'] as String?,
    );
  }

  CompanySettings copyWith({
    int? id,
    String? companyName,
    String? companyAddress,
    String? companyCity,
    String? companyProvince,
    String? companyPostalCode,
    String? companyPhone,
    String? companyEmail,
    String? defaultTax1Name,
    double? defaultTax1Rate,
    String? defaultTax1RegistrationNumber,
    String? defaultTax2Name,
    double? defaultTax2Rate,
    String? defaultTax2RegistrationNumber,
    String? defaultTerms,
    double? taxRate,
    String? postalCodeLabel,
    String? regionLabel,
    String? country,
    String? invoicePrefix,
    int? invoiceStartingNumber,
    String? paymentEtransferEmail,
  }) {
    return CompanySettings(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      companyCity: companyCity ?? this.companyCity,
      companyProvince: companyProvince ?? this.companyProvince,
      companyPostalCode: companyPostalCode ?? this.companyPostalCode,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      defaultTax1Name: defaultTax1Name ?? this.defaultTax1Name,
      defaultTax1Rate: defaultTax1Rate ?? this.defaultTax1Rate,
      defaultTax1RegistrationNumber: defaultTax1RegistrationNumber ?? this.defaultTax1RegistrationNumber,
      defaultTax2Name: defaultTax2Name ?? this.defaultTax2Name,
      defaultTax2Rate: defaultTax2Rate ?? this.defaultTax2Rate,
      defaultTax2RegistrationNumber: defaultTax2RegistrationNumber ?? this.defaultTax2RegistrationNumber,
      defaultTerms: defaultTerms ?? this.defaultTerms,
      taxRate: taxRate ?? this.taxRate,
      postalCodeLabel: postalCodeLabel ?? this.postalCodeLabel,
      regionLabel: regionLabel ?? this.regionLabel,
      country: country ?? this.country,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceStartingNumber: invoiceStartingNumber ?? this.invoiceStartingNumber,
      paymentEtransferEmail: paymentEtransferEmail ?? this.paymentEtransferEmail,
    );
  }
}
