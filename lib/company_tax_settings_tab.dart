// lib/company_tax_settings_tab.dart

import 'package:flutter/material.dart';

class CompanyTaxSettingsTab extends StatelessWidget {
  final TextEditingController companyNameController;
  final TextEditingController companyAddressController;
  final TextEditingController companyCityController;
  final TextEditingController companyProvinceController;
  final TextEditingController companyPostalCodeController;
  final TextEditingController companyPhoneController;
  final TextEditingController companyEmailController;
  final TextEditingController tax1NameController;
  final TextEditingController tax1RateController;
  final TextEditingController tax1RegController;
  final TextEditingController tax2NameController;
  final TextEditingController tax2RateController;
  final TextEditingController tax2RegController;
  final TextEditingController termsController;
  final VoidCallback onSave;

  const CompanyTaxSettingsTab({
    super.key,
    required this.companyNameController,
    required this.companyAddressController,
    required this.companyCityController,
    required this.companyProvinceController,
    required this.companyPostalCodeController,
    required this.companyPhoneController,
    required this.companyEmailController,
    required this.tax1NameController,
    required this.tax1RateController,
    required this.tax1RegController,
    required this.tax2NameController,
    required this.tax2RateController,
    required this.tax2RegController,
    required this.termsController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Company Information'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  TextField(
                    controller: companyNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Company Name'),
                  ),
                  TextField(
                    controller: companyAddressController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Street Address'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: companyCityController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: companyProvinceController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Province'),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: companyPostalCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Postal Code'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: companyPhoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: companyEmailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Tax Settings (e.g., GST)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: tax1NameController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Tax 1 Name (e.g. GST)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tax1RateController,
                          decoration: const InputDecoration(
                            labelText: 'Rate %',
                            hintText: '5.0',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: tax1RegController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Tax 1 Registration #'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Secondary Tax (Optional, e.g. PST)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: tax2NameController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Tax 2 Name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tax2RateController,
                          decoration: const InputDecoration(labelText: 'Rate %'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: tax2RegController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Tax 2 Registration #'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Invoice Terms'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: termsController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Default Terms',
                  hintText: 'Payable on Receipt',
                ),
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Company Settings'),
            ),
          ),
          const SizedBox(height: 100), // Added extra scroll space
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }
}
