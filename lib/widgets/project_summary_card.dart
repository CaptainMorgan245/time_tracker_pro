// lib/widgets/project_summary_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker_pro/models.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

class ProjectSummaryCard extends StatelessWidget {
  final ProjectSummaryViewModel summaryData;
  const ProjectSummaryCard({super.key, required this.summaryData});

  String getPricingModelLabel() {
    if (summaryData.pricingModel == 'hourly') return 'Hourly';
    if (summaryData.pricingModel == 'fixed' || summaryData.pricingModel == 'project_price') return 'Fixed Price';
    return 'Unknown';
  }

  String getBilledRateValue() {
    if (summaryData.pricingModel == 'hourly') {
      return '${_currencyFormat.format(summaryData.billedRate)}/hr';
    }
    // For fixed price projects, this is the total price, not a rate.
    return _currencyFormat.format(summaryData.fixedPrice ?? 0.0);
  }

  String getBilledRateLabel() {
    if (summaryData.pricingModel == 'hourly') return 'Billed Rate:';
    return 'Fixed Price:';
  }


  @override
  Widget build(BuildContext context) {
    final pLColor = summaryData.profitLoss >= 0 ? Colors.green[700] : Colors.red[700];

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Project | Pricing Model | Billed Rate
            _buildInfoRow(
              context,
              [
                _InfoPair('Project:', summaryData.projectName),
                _InfoPair('Pricing Model:', getPricingModelLabel()),
                _InfoPair(getBilledRateLabel(), getBilledRateValue()),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Total Hours | Labor Cost | Materials Cost
            _buildInfoRow(
              context,
              [
                _InfoPair('Total Hours:', summaryData.totalHours.toStringAsFixed(2)),
                _InfoPair('Labor Cost:', _currencyFormat.format(summaryData.laborCost)),
                _InfoPair('Materials Cost:', _currencyFormat.format(summaryData.materialsCost)),
              ],
            ),
            const Divider(height: 24, thickness: 1.5),

            // Row 3: Total Cost | Total Billed Value | Profit/Loss
            _buildTotalRow(
              context,
              [
                _InfoPair('Total Cost:', _currencyFormat.format(summaryData.totalCost)),
                _InfoPair('Total Billed Value:', _currencyFormat.format(summaryData.totalBilledValue)),
                _InfoPair('Profit/Loss:', _currencyFormat.format(summaryData.profitLoss), valueColor: pLColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, List<_InfoPair> pairs) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
      children: pairs.map((pair) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add some horizontal padding
            child: Text.rich(
              TextSpan(
                style: textTheme.bodyMedium,
                children: [
                  TextSpan(text: '${pair.label} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: pair.value),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTotalRow(BuildContext context, List<_InfoPair> pairs) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
      children: pairs.map((pair) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add some horizontal padding
            child: Text.rich(
              TextSpan(
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: '${pair.label} '),
                  TextSpan(
                    text: pair.value,
                    style: TextStyle(color: pair.valueColor ?? Theme.of(context).primaryColor, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InfoPair {
  final String label;
  final String value;
  final Color? valueColor;

  _InfoPair(this.label, this.value, {this.valueColor});
}
