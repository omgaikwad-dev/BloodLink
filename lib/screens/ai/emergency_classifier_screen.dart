/// AI Emergency Priority Detection Screen
/// Analyze request urgency and patient condition to auto-classify priority
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/emergency_classifier_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_card.dart';

class EmergencyClassifierScreen extends StatefulWidget {
  const EmergencyClassifierScreen({super.key});

  @override
  State<EmergencyClassifierScreen> createState() => _EmergencyClassifierScreenState();
}

class _EmergencyClassifierScreenState extends State<EmergencyClassifierScreen> {
  final _conditionController = TextEditingController();
  final _ageController = TextEditingController();
  final _hbController = TextEditingController();
  final _hoursController = TextEditingController();

  String _selectedBloodGroup = 'O+';
  int _units = 1;
  bool _isSurgery = false;
  bool _isAccident = false;
  bool _isPregnant = false;
  bool _isAnalyzing = false;
  EmergencyClassification? _result;

  @override
  void dispose() {
    _conditionController.dispose();
    _ageController.dispose();
    _hbController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _classify() async {
    setState(() => _isAnalyzing = true);

    final result = await EmergencyClassifierService.classify(
      patientAge: int.tryParse(_ageController.text),
      patientCondition: _conditionController.text.isNotEmpty ? _conditionController.text : null,
      unitsNeeded: _units,
      bloodGroup: _selectedBloodGroup,
      isSurgery: _isSurgery,
      isAccident: _isAccident,
      hemoglobinLevel: double.tryParse(_hbController.text),
      isPregnant: _isPregnant,
      timeCriticalHours: double.tryParse(_hoursController.text),
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
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
                gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Priority Detection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Auto-classify emergency level', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input section
            const Text(
              '📋 Patient Information',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ).animate().fade(duration: 300.ms).slideX(),
            const SizedBox(height: 12),

            // Blood group & units
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Blood Group Required', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AppConstants.bloodGroups.map((bg) {
                      final selected = _selectedBloodGroup == bg;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBloodGroup = bg),
                        child: Container(
                          width: 56,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bgDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              bg,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Units Needed:', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        onPressed: () { if (_units > 1) setState(() => _units--); },
                        icon: const Icon(Icons.remove_circle_rounded),
                        color: AppColors.textSecondary,
                      ),
                      Container(
                        width: 45,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$_units',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _units++),
                        icon: const Icon(Icons.add_circle_rounded),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 12),

            // Patient condition
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _conditionController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Patient Condition',
                      hintText: 'e.g., Road accident with hemorrhage...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageController,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Age', hintText: '32'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _hbController,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Hemoglobin (g/dL)', hintText: '8.5'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hoursController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Time Window (hours)', hintText: 'e.g., 2'),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 12),

            // Flags
            GlassCard(
              child: Column(
                children: [
                  _buildSwitch('🚗 Accident Case', _isAccident, (v) => setState(() => _isAccident = v)),
                  const Divider(color: AppColors.border, height: 1),
                  _buildSwitch('🔪 Surgery Required', _isSurgery, (v) => setState(() => _isSurgery = v)),
                  const Divider(color: AppColors.border, height: 1),
                  _buildSwitch('🤰 Pregnant Patient', _isPregnant, (v) => setState(() => _isPregnant = v)),
                ],
              ),
            ).animate().fade(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // Analyze button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _classify,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFEF4444),
                ),
                icon: _isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                label: Text(
                  _isAnalyzing ? 'Analyzing...' : '🧠 AI Analyze Priority',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ).animate().fade(delay: 400.ms, duration: 400.ms),

            // Result
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResult(_result!)
                  .animate()
                  .fade(duration: 500.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(EmergencyClassification result) {
    final priorityColor = switch (result.priority) {
      'SOS' => AppColors.urgencySOS,
      'Critical' => AppColors.urgencyCritical,
      'Urgent' => AppColors.urgencyUrgent,
      _ => AppColors.urgencyNormal,
    };

    final priorityEmoji = switch (result.priority) {
      'SOS' => '🆘',
      'Critical' => '🔴',
      'Urgent' => '🟡',
      _ => '🟢',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🧠 AI Classification Result',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),

        // Priority banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [priorityColor.withValues(alpha: 0.2), priorityColor.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: priorityColor.withValues(alpha: 0.5), width: 2),
          ),
          child: Column(
            children: [
              Text(
                priorityEmoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                result.priority,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: priorityColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Priority Score: ${result.priorityScore.toStringAsFixed(0)}/100',
                style: TextStyle(fontSize: 14, color: priorityColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: result.priorityScore / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.bgDark.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation(priorityColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reasoning
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📋 Analysis Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              ...result.reasoning.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.info, fontSize: 14, fontWeight: FontWeight.w700)),
                    Expanded(child: Text(r, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3))),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Recommended actions
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚡ Recommended Actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              ...result.recommendedActions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
        
        if (result.requiredSurgery != null || result.treatmentPlan.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🩺 Medical Insights',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                if (result.requiredSurgery != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.medical_services_rounded, size: 16, color: Color(0xFFE11D48)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Required Surgery / Procedure', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(result.requiredSurgery!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (result.requiredSurgery != null && result.treatmentPlan.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                if (result.treatmentPlan.isNotEmpty) ...[
                  const Text('Immediate Treatment Plan:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...result.treatmentPlan.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text('• ', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 14, fontWeight: FontWeight.w700)),
                         Expanded(child: Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
        ],
      ],
    );
  }
}
