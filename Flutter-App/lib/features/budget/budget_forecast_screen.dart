import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/budget_service.dart';

class BudgetForecastScreen extends StatefulWidget {
  final Vehicle vehicle;

  const BudgetForecastScreen({super.key, required this.vehicle});

  @override
  State<BudgetForecastScreen> createState() => _BudgetForecastScreenState();
}

class _BudgetForecastScreenState extends State<BudgetForecastScreen> {
  final BudgetService _budgetService = BudgetService();

  BudgetForecastResponse? _forecast;
  BudgetStatistics? _statistics;
  bool _isLoading = true;
  String? _error;

  // User settings
  int _monthsAhead = 6;
  bool _includeIrregular = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final forecast = await _budgetService.getBudgetForecast(
        widget.vehicle.id,
        monthsAhead: _monthsAhead,
        includeIrregular: _includeIrregular,
      );

      final statistics = await _budgetService.getBudgetStatistics(
        widget.vehicle.id,
      );

      setState(() {
        _forecast = forecast;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(2)} PLN';
  }

  String _formatMonth(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFF10B981);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'LOW':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        title: const Text('Budget Forecast'),
        backgroundColor: AppColors.bgSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatisticsCard(),
                    const SizedBox(height: 24),
                    _buildSettingsCard(),
                    const SizedBox(height: 24),
                    _buildForecastChart(),
                    const SizedBox(height: 24),
                    _buildForecastList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppColors.accentPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Last 12 Months Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem(
              'Regular Expenses',
              _formatCurrency(_statistics!.totalRegularLast12m),
              'Avg: ${_formatCurrency(_statistics!.avgMonthlyRegular)}/month',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStatItem(
              'Irregular Expenses',
              _formatCurrency(_statistics!.totalIrregularLast12m),
              'Avg: ${_formatCurrency(_statistics!.avgMonthlyIrregular)}/month',
              Colors.orange,
            ),
            if (_statistics!.largestExpenseLast12m != null) ...[
              const SizedBox(height: 8),
              _buildStatItem(
                'Largest Single Expense',
                _formatCurrency(_statistics!.largestExpenseLast12m!),
                _statistics!.largestExpenseCategory ?? 'Unknown category',
                AppColors.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecast Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Months ahead:',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_monthsAhead months',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _monthsAhead.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_monthsAhead months',
              activeColor: AppColors.accentPrimary,
              onChanged: (value) {
                setState(() => _monthsAhead = value.toInt());
              },
              onChangeEnd: (_) => _loadData(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Include buffer for unexpected expenses',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Adds ${(_statistics?.avgMonthlyIrregular.toStringAsFixed(2) ?? "0")} PLN/month (15% of irregular expense average)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              value: _includeIrregular,
              activeColor: AppColors.accentPrimary,
              onChanged: (value) {
                setState(() => _includeIrregular = value);
                _loadData();
              },
            ),
            if (_forecast != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.speed, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Avg. mileage: ${_forecast!.avgMonthlyMileage.toStringAsFixed(0)} km/month',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForecastChart() {
    if (_forecast == null || _forecast!.forecasts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Forecast',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxYValue(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final forecast = _forecast!.forecasts[group.x.toInt()];
                        String label;
                        switch (rodIndex) {
                          case 0:
                            label = 'Regular';
                            break;
                          case 1:
                            label = 'Scheduled';
                            break;
                          case 2:
                            label = 'Buffer';
                            break;
                          default:
                            label = '';
                        }
                        return BarTooltipItem(
                          '$label\n${_formatCurrency(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _forecast!.forecasts.length) {
                            return const SizedBox.shrink();
                          }
                          final date =
                              _forecast!.forecasts[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getMaxYValue() / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.textMuted.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _forecast!.forecasts
                      .asMap()
                      .entries
                      .map((entry) => _buildBarGroup(entry.key, entry.value))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int index, MonthlyBudgetForecast forecast) {
    final barRods = <BarChartRodData>[
      // Regular costs (blue)
      BarChartRodData(
        toY: forecast.regularCosts,
        color: Colors.blue,
        width: 12,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
    ];

    // Scheduled maintenance (orange)
    if (forecast.scheduledMaintenance > 0) {
      barRods.add(
        BarChartRodData(
          toY: forecast.scheduledMaintenance,
          color: Colors.orange,
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      );
    }

    // Irregular buffer (red, semi-transparent)
    if (_includeIrregular && forecast.irregularBuffer > 0) {
      barRods.add(
        BarChartRodData(
          toY: forecast.irregularBuffer,
          color: Colors.red.withOpacity(0.5),
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      );
    }

    return BarChartGroupData(x: index, barRods: barRods, barsSpace: 4);
  }

  double _getMaxYValue() {
    if (_forecast == null || _forecast!.forecasts.isEmpty) return 1000;

    double maxValue = 0;
    for (final forecast in _forecast!.forecasts) {
      final total =
          forecast.regularCosts +
          forecast.scheduledMaintenance +
          (_includeIrregular ? forecast.irregularBuffer : 0);
      if (total > maxValue) maxValue = total;
    }

    // Round up to next hundred
    return ((maxValue / 100).ceil() * 100).toDouble() + 100;
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(Colors.blue, 'Regular costs'),
        _buildLegendItem(Colors.orange, 'Scheduled maintenance'),
        if (_includeIrregular)
          _buildLegendItem(Colors.red.withOpacity(0.5), 'Unexpected buffer'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildForecastList() {
    if (_forecast == null || _forecast!.forecasts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Forecast',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._forecast!.forecasts.map((forecast) => _buildForecastCard(forecast)),
      ],
    );
  }

  Widget _buildForecastCard(MonthlyBudgetForecast forecast) {
    return Card(
      color: AppColors.bgSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonth(forecast.month),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(
                      forecast.confidenceLevel,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    forecast.confidenceLevel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(forecast.confidenceLevel),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCostRow('Regular costs', forecast.regularCosts, Colors.blue),
            if (forecast.scheduledMaintenance > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow(
                'Scheduled maintenance',
                forecast.scheduledMaintenance,
                Colors.orange,
              ),
              // Show scheduled service details
              if (forecast.scheduledMaintenanceDetails.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...forecast.scheduledMaintenanceDetails.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 4),
                    child: Text(
                      '• ${detail.name}: ${_formatCurrency(detail.cost)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (_includeIrregular && forecast.irregularBuffer > 0) ...[
              const SizedBox(height: 8),
              _buildCostRow(
                'Unexpected buffer',
                forecast.irregularBuffer,
                Colors.red.withOpacity(0.7),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Predicted',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatCurrency(forecast.totalPredicted),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text(
          'How Budget Forecast Works',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(
                Icons.analytics,
                'Regular Costs',
                'Average of your monthly totals from the last 12 months. '
                    'Only includes regular expenses (irregular large outliers are automatically excluded).',
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                Icons.build,
                'Scheduled Maintenance',
                'Predicted based on your vehicle\'s service rules (mileage or time intervals). '
                    'Uses your average monthly mileage to estimate when services are due.',
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                Icons.warning_amber,
                'Unexpected Buffer',
                'Reserve fund: 15% of your average monthly irregular expenses. '
                    'Helps you prepare for unexpected repairs based on past outliers.',
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                Icons.info,
                'Confidence Level',
                'HIGH: Next 3 months (most reliable)\n'
                    'MEDIUM: 4-6 months ahead\n'
                    'LOW: 7+ months ahead',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accentPrimary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
