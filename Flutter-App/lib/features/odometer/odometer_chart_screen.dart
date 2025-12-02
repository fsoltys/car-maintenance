import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/api/vehicle_service.dart';
import '../../core/api/odometer_service.dart';

class OdometerChartScreen extends StatefulWidget {
  final Vehicle vehicle;

  const OdometerChartScreen({super.key, required this.vehicle});

  @override
  State<OdometerChartScreen> createState() => _OdometerChartScreenState();
}

class _OdometerChartScreenState extends State<OdometerChartScreen> {
  final OdometerService _odometerService = OdometerService();
  List<OdometerHistoryItem> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _odometerService.getOdometerGraph(
        widget.vehicle.id,
      );
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load odometer data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'Odometer Chart',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              widget.vehicle.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadEntries,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No data to display',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add odometer entries to see the chart',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stats summary
                    _buildStatsSummary(),
                    const SizedBox(height: 24),
                    // Chart
                    _buildChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSummary() {
    if (_entries.isEmpty) return const SizedBox.shrink();

    final sortedEntries = List<OdometerHistoryItem>.from(_entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final firstEntry = sortedEntries.first;
    final lastEntry = sortedEntries.last;
    final totalDistance = lastEntry.odometerKm - firstEntry.odometerKm;
    final daysDiff = lastEntry.timestamp
        .difference(firstEntry.timestamp)
        .inDays;
    final avgPerDay = daysDiff > 0 ? totalDistance / daysDiff : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Distance',
                '${totalDistance.toStringAsFixed(0)} km',
                Icons.route,
              ),
              _buildStatItem('Entries', '${_entries.length}', Icons.event_note),
              _buildStatItem(
                'Avg/Day',
                '${avgPerDay.toStringAsFixed(1)} km',
                Icons.speed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accentSecondary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_entries.isEmpty) return const SizedBox.shrink();

    final sortedEntries = List<OdometerHistoryItem>.from(_entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final minOdometer = sortedEntries.first.odometerKm;
    final maxOdometer = sortedEntries.last.odometerKm;
    final range = maxOdometer - minOdometer;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mileage Over Time',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          // Chart area
          SizedBox(
            height: 300,
            child: CustomPaint(
              painter: OdometerChartPainter(
                entries: sortedEntries,
                minOdometer: minOdometer,
                maxOdometer: maxOdometer,
                textStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem('Fueling', AppColors.accentSecondary),
        _buildLegendItem('Service', const Color(0xFF4CAF50)),
        _buildLegendItem('Manual', AppColors.accentPrimary),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class OdometerChartPainter extends CustomPainter {
  final List<OdometerHistoryItem> entries;
  final double minOdometer;
  final double maxOdometer;
  final TextStyle textStyle;

  OdometerChartPainter({
    required this.entries,
    required this.minOdometer,
    required this.maxOdometer,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.accentSecondary.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.1)
      ..strokeWidth = 1;

    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Draw grid lines
    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );

      // Draw y-axis labels
      final odometerValue = maxOdometer - ((maxOdometer - minOdometer) / 5) * i;
      final textSpan = TextSpan(
        text: odometerValue.toStringAsFixed(0),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Calculate points
    final points = <Offset>[];
    final range = maxOdometer - minOdometer;
    final timeRange =
        entries.last.timestamp.millisecondsSinceEpoch -
        entries.first.timestamp.millisecondsSinceEpoch;

    for (final entry in entries) {
      final x =
          padding +
          (chartWidth *
              (entry.timestamp.millisecondsSinceEpoch -
                  entries.first.timestamp.millisecondsSinceEpoch) /
              timeRange);
      final y =
          padding +
          chartHeight -
          (chartHeight * (entry.odometerKm - minOdometer) / range);
      points.add(Offset(x, y));
    }

    // Draw line
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw points with different colors based on source
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final source = entry.source.toLowerCase();
      Color pointColor;

      switch (source) {
        case 'fueling':
          pointColor = AppColors.accentSecondary;
          break;
        case 'service':
          pointColor = const Color(0xFF4CAF50);
          break;
        case 'manual':
          pointColor = AppColors.accentPrimary;
          break;
        default:
          pointColor = AppColors.textSecondary;
      }

      pointPaint.color = pointColor;
      canvas.drawCircle(points[i], 5, pointPaint);

      // Draw white border
      canvas.drawCircle(
        points[i],
        5,
        Paint()
          ..color = AppColors.bgSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Draw x-axis labels (dates)
    if (entries.length > 1) {
      final firstDate = DateFormat('dd MMM').format(entries.first.timestamp);
      final lastDate = DateFormat('dd MMM').format(entries.last.timestamp);

      final firstTextPainter = TextPainter(
        text: TextSpan(text: firstDate, style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      firstTextPainter.paint(
        canvas,
        Offset(padding, size.height - padding + 10),
      );

      final lastTextPainter = TextPainter(
        text: TextSpan(text: lastDate, style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      lastTextPainter.paint(
        canvas,
        Offset(
          size.width - padding - lastTextPainter.width,
          size.height - padding + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
