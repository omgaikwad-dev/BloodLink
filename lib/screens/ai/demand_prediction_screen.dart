/// AI Blood Demand Prediction Screen
/// Shows forecasted demand with charts, seasonal factors, and trends
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/demand_prediction_service.dart';
import '../../core/widgets/glass_card.dart';

class DemandPredictionScreen extends StatefulWidget {
  const DemandPredictionScreen({super.key});

  @override
  State<DemandPredictionScreen> createState() => _DemandPredictionScreenState();
}

class _DemandPredictionScreenState extends State<DemandPredictionScreen> {
  List<DemandPrediction> _predictions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() => _isLoading = true);
    final predictions = await DemandPredictionService.getPredictions();
    if (mounted) {
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Demand Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Blood group forecasting', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPredictions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.info))
          : RefreshIndicator(
              onRefresh: _loadPredictions,
              color: AppColors.info,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    _buildHeaderCard()
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 20),

                    // Season info
                    _buildSeasonCard()
                        .animate()
                        .fade(delay: 100.ms, duration: 400.ms)
                        .slideX(begin: 0.05, end: 0),
                    const SizedBox(height: 20),

                    // Demand bars chart
                    const Text(
                      '📊 Predicted Demand by Blood Group',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ).animate().fade(delay: 200.ms).slideX(),
                    const SizedBox(height: 12),

                    ..._predictions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final prediction = entry.value;
                      return _buildDemandBar(prediction, index)
                          .animate()
                          .fade(delay: (300 + index * 80).ms, duration: 400.ms)
                          .slideX(begin: 0.1, end: 0);
                    }),

                    const SizedBox(height: 24),

                    // Detailed cards
                    const Text(
                      '🔍 Detailed Analysis',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ).animate().fade(delay: 800.ms).slideX(),
                    const SizedBox(height: 12),

                    ..._predictions.asMap().entries.map((entry) {
                      return _buildDetailCard(entry.value, entry.key)
                          .animate()
                          .fade(delay: (900 + entry.key * 60).ms, duration: 400.ms)
                          .slideY(begin: 0.05, end: 0);
                    }),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final totalDemand = _predictions.fold<int>(0, (sum, p) => sum + p.predictedDemand);
    final risingCount = _predictions.where((p) => p.trend == 'rising').length;

    return GlassCard(
      isHighlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded, color: AppColors.info, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Forecast Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next month prediction',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  '$totalDemand',
                  'Total Units',
                  Icons.water_drop_rounded,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryItem(
                  '$risingCount',
                  'Rising Trends',
                  Icons.trending_up_rounded,
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryItem(
                  '${_predictions.length}',
                  'Blood Groups',
                  Icons.bloodtype_rounded,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSeasonCard() {
    final season = _predictions.isNotEmpty ? _predictions.first.seasonalFactor : 'Unknown';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seasonal Factor',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  season,
                  style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Active',
              style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandBar(DemandPrediction prediction, int index) {
    final maxDemand = _predictions.fold<int>(1, (max, p) => p.predictedDemand > max ? p.predictedDemand : max);
    final percentage = prediction.predictedDemand / maxDemand;

    final trendIcon = switch (prediction.trend) {
      'rising' => Icons.trending_up_rounded,
      'falling' => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };
    final trendColor = switch (prediction.trend) {
      'rising' => AppColors.warning,
      'falling' => AppColors.success,
      _ => AppColors.info,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      prediction.bloodGroup,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${prediction.predictedDemand} units predicted',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${(prediction.confidence * 100).toInt()}% confidence',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(trendIcon, color: trendColor, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: AppColors.bgCardLight,
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(AppColors.success, AppColors.error, percentage) ?? AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(DemandPrediction prediction, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      prediction.bloodGroup,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${prediction.predictedDemand} units needed',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Row(
                        children: [
                          Icon(
                            prediction.trend == 'rising'
                                ? Icons.trending_up_rounded
                                : prediction.trend == 'falling'
                                    ? Icons.trending_down_rounded
                                    : Icons.trending_flat_rounded,
                            size: 14,
                            color: prediction.trend == 'rising' ? AppColors.warning : AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            prediction.trend.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: prediction.trend == 'rising' ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${(prediction.confidence * 100).toInt()}% confidence',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prediction.reasoning,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
