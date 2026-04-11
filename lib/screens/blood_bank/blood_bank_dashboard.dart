/// Blood Bank Dashboard - manage blood inventory & AI insights
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/blood_group_selector.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/demand_prediction_service.dart';
import '../../models/blood_inventory_model.dart';
import '../../providers/auth_provider.dart';

class BloodBankDashboard extends StatefulWidget {
  const BloodBankDashboard({super.key});

  @override
  State<BloodBankDashboard> createState() => _BloodBankDashboardState();
}

class _BloodBankDashboardState extends State<BloodBankDashboard> {
  final FirestoreService _fs = FirestoreService();
  List<DemandPrediction>? _aiPredictions;
  bool _isTrainingAi = false;

  @override
  void initState() {
    super.initState();
    _loadAiPredictions();
  }

  Future<void> _loadAiPredictions() async {
    setState(() => _isTrainingAi = true);
    // Simulate AI model training / fetching predictions overhead for effect
    await Future.delayed(const Duration(milliseconds: 1500));
    final predictions = await DemandPredictionService.getPredictions();
    if (mounted) {
      setState(() {
        _aiPredictions = predictions;
        _isTrainingAi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _isTrainingAi ? null : _loadAiPredictions,
                icon: const Icon(Icons.psychology_rounded, color: AppColors.primary),
                tooltip: 'Train AI Model',
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))
                      ]
                    ),
                    child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                     child: Text(user?.name ?? 'Blood Bank Hub', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.bgDark,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildAiInsightsSection(),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<BloodInventoryModel>>(
              stream: _fs.streamBloodBankInventory(auth.firebaseUser?.uid ?? ''),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                   return const Padding(
                     padding: EdgeInsets.only(top: 100),
                     child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                   );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) return _emptyState();
                return _buildInventoryContent(items);
              },
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInventory(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ).animate().slideY(begin: 2, end: 0, curve: Curves.easeOutQuart, duration: 600.ms),
    );
  }

  Widget _buildAiInsightsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(2))),
               const SizedBox(width: 8),
               const Text('AI Demand Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
               const Spacer(),
               if (_isTrainingAi)
                 const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary))
               else
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                   child: const Row(
                     children: [
                       Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                       SizedBox(width: 4),
                       Text('ACTIVE', style: TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.w800)),
                     ],
                   )
                 )
            ],
          ).animate().fade().slideX(),
          const SizedBox(height: 16),
          if (_aiPredictions == null || _isTrainingAi)
            _buildAiLoadingState()
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _aiPredictions!.length,
                itemBuilder: (context, index) {
                  final pred = _aiPredictions![index];
                  final isRising = pred.trend == 'rising';
                  final isFalling = pred.trend == 'falling';
                  final glowColor = isRising ? AppColors.error : (isFalling ? AppColors.success : AppColors.info);
                  
                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 16, bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: glowColor.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: glowColor.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: glowColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(pred.bloodGroup, style: TextStyle(color: glowColor, fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                            Icon(isRising ? Icons.trending_up_rounded : (isFalling ? Icons.trending_down_rounded : Icons.trending_flat_rounded), 
                                 color: glowColor)
                          ],
                        ),
                        const Spacer(),
                        Text('${pred.predictedDemand} units needed', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(pred.reasoning, 
                             maxLines: 2, overflow: TextOverflow.ellipsis,
                             style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.2)),
                      ]
                    ),
                  ).animate().fade(duration: 400.ms).scaleXY(begin: 0.9, end: 1.0, delay: (index * 100).ms);
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _buildAiLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCardLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Icon(Icons.psychology_rounded, size: 32, color: AppColors.secondary)
             .animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scaleXY(begin: 1.0, end: 1.2)
             .shimmer(color: AppColors.secondary.withValues(alpha: 0.5), duration: 1.seconds),
           const SizedBox(height: 16),
           const Text('Training AI Model on localized Data...', 
                 style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
           const SizedBox(height: 8),
           const Text('Evaluating seasonal trends and historical demands.', 
                 style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
         ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_rounded, color: AppColors.primary.withValues(alpha: 0.8), size: 64),
            ).animate().scaleXY(begin: 0.5, end: 1.0, curve: Curves.elasticOut, duration: 1.seconds),
            const SizedBox(height: 24),
            const Text('Inventory Empty', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Add blood stock to keep your inventory updated and help hospitals find blood faster.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryContent(List<BloodInventoryModel> items) {
    // Group by blood type
    final Map<String, int> totals = {};
    for (final item in items) {
      if (!item.isExpired) {
        totals[item.bloodGroup] = (totals[item.bloodGroup] ?? 0) + item.units;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.info, borderRadius: BorderRadius.circular(2))),
               const SizedBox(width: 8),
               const Text('Current Stock Levels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ).animate().fade().slideX(),
          const SizedBox(height: 16),
          // Blood type overview grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: AppConstants.bloodGroups.length,
            itemBuilder: (context, index) {
              final bg = AppConstants.bloodGroups[index];
              final count = totals[bg] ?? 0;
              final isLow = count < 5 && count > 0;
              final isEmpty = count == 0;
              
              Color statusColor = isEmpty ? AppColors.textMuted : isLow ? AppColors.warning : AppColors.success;
              
              return InkWell(
                onTap: () => _showBloodGroupDetails(context, bg, items, count),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.15),
                        statusColor.withValues(alpha: 0.02)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      if (!isEmpty) BoxShadow(color: statusColor.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(bg, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: statusColor)),
                    const SizedBox(height: 8),
                    Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                    Text('units', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ).animate().fade(duration: 400.ms).scaleXY(begin: 0.8, end: 1.0, delay: (index * 30).ms);
            },
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
               Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
               const SizedBox(width: 8),
               const Text('Recent Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ).animate().fade(delay: 200.ms).slideX(),
          const SizedBox(height: 16),
          
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _inventoryCard(entry.value).animate().fade().slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart, delay: (200 + entry.key * 80).ms),
              )),
        ],
      ),
    );
  }

  Widget _inventoryCard(BloodInventoryModel item) {
    final expiry = item.expiryDate;
    final isExpired = item.isExpired;
    final daysLeft = item.daysUntilExpiry;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: isExpired ? AppColors.error.withValues(alpha: 0.4) : null,
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
               colors: isExpired 
                 ? [AppColors.error.withValues(alpha: 0.8), AppColors.error]
                 : [AppColors.primary.withValues(alpha: 0.8), AppColors.primary]
             ),
             borderRadius: BorderRadius.circular(16),
             boxShadow: [
               BoxShadow(color: (isExpired ? AppColors.error : AppColors.primary).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
             ],
          ),
          child: Center(child: Text(item.bloodGroup, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text('${item.units} Units', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              if (item.units == 0)
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                   decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                   child: const Text('EMPTY', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w900))
                )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: isExpired ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 6),
              if (expiry != null) Text(
                isExpired ? 'Expired' : 'Expires in $daysLeft days',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isExpired ? AppColors.error : daysLeft != null && daysLeft < 7 ? AppColors.warning : AppColors.textSecondary)),
            ],
          ),
        ])),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _showEditInventory(context, item)),
      ]),
    );
  }

  void _showAddInventory(BuildContext context) {
    String bg = 'O+';
    int units = 10;
    DateTime? expiry = DateTime.now().add(const Duration(days: 35));
    final auth = context.read<AuthProvider>();

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Container(
        decoration: BoxDecoration(
           color: AppColors.bgCard, 
           borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 10)]
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 22)),
                const SizedBox(width: 16),
                const Text('Add New Stock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Blood Group', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            BloodGroupSelector(selectedGroup: bg, onSelected: (g) => ss(() => bg = g)),
            const SizedBox(height: 24),
            const Text('Quantity (Units)', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () { if (units > 1) ss(() => units--); }, 
                  style: IconButton.styleFrom(backgroundColor: AppColors.bgCardLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.remove_rounded), color: AppColors.textSecondary),
                const SizedBox(width: 24),
                SizedBox(
                  width: 50,
                  child: Text('$units', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 24),
                IconButton(onPressed: () => ss(() => units++), 
                   style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                   icon: const Icon(Icons.add_rounded), color: AppColors.primary),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Expiry Date', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx, firstDate: DateTime.now(), initialDate: expiry!, lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.bgCard, onSurface: AppColors.textPrimary)), child: child!),
                );
                if (picked != null) ss(() => expiry = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(expiry!), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.primary,
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(vertical: 18),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 elevation: 8,
                 shadowColor: AppColors.primary.withValues(alpha: 0.5)
               ),
               onPressed: () async {
                  Navigator.pop(ctx);
                  await _fs.updateInventory(BloodInventoryModel(id: '', bloodBankId: auth.firebaseUser!.uid, bloodBankName: auth.userModel!.name, bloodGroup: bg, units: units, expiryDate: expiry));
               }, 
               child: const Text('Add to Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
        ),
      )),
    );
  }

  void _showEditInventory(BuildContext context, BloodInventoryModel item) {
    int units = item.units;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.05)]),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5))
              ),
              child: Center(child: Text(item.bloodGroup, style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(height: 16),
            const Text('Update Stock', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () { if (units > 0) ss(() => units--); }, 
               icon: const Icon(Icons.remove_circle_outline_rounded), color: AppColors.textSecondary, iconSize: 32),
            const SizedBox(width: 16),
            SizedBox(
              width: 50,
              child: Text('$units', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 16),
            IconButton(onPressed: () => ss(() => units++), 
               icon: const Icon(Icons.add_circle_outline_rounded), color: AppColors.primary, iconSize: 32),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), 
             child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            onPressed: () { Navigator.pop(ctx); _fs.updateInventory(item.copyWith(units: units)); }, 
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    ));
  }

  void _showBloodGroupDetails(BuildContext context, String bloodGroup, List<BloodInventoryModel> allItems, int totalCount) {
    // Filter batches for this specific blood group
    final groupBatches = allItems.where((item) => item.bloodGroup == bloodGroup).toList()
      ..sort((a, b) => (a.expiryDate ?? DateTime.now()).compareTo(b.expiryDate ?? DateTime.now()));

    final matchingEngineData = {
      'O+': {'gives': 'O+, A+, B+, AB+', 'receives': 'O+, O-'},
      'O-': {'gives': 'Everyone', 'receives': 'O-'},
      'A+': {'gives': 'A+, AB+', 'receives': 'A+, A-, O+, O-'},
      'A-': {'gives': 'A+, A-, AB+, AB-', 'receives': 'A-, O-'},
      'B+': {'gives': 'B+, AB+', 'receives': 'B+, B-, O+, O-'},
      'B-': {'gives': 'B+, B-, AB+, AB-', 'receives': 'B-, O-'},
      'AB+': {'gives': 'AB+', 'receives': 'Everyone'},
      'AB-': {'gives': 'AB+, AB-', 'receives': 'AB-, A-, B-, O-'}
    };

    final isLow = totalCount < 5;
    final statusColor = totalCount == 0 ? AppColors.error : isLow ? AppColors.warning : AppColors.success;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
           color: AppColors.bgCard, 
           borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 10)]
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.8), statusColor]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  ),
                  child: Center(child: Text(bloodGroup, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Inventory', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('$totalCount Units', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                      if (totalCount == 0)
                        const Text('Out of Stock - Urgent Need', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700))
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Can Donate To:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(matchingEngineData[bloodGroup]?['gives'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ))
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: AppColors.info, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Can Receive From:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(matchingEngineData[bloodGroup]?['receives'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ))
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Unit Batches', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Expanded(
              child: groupBatches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 16),
                        const Text('No active batches found.', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: groupBatches.length,
                    itemBuilder: (context, index) {
                      final item = groupBatches[index];
                      final isExpired = item.isExpired;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isExpired ? AppColors.error.withValues(alpha: 0.3) : AppColors.border)
                        ),
                        child: Row(
                          children: [
                            Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: (isExpired ? AppColors.error : AppColors.primary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                               child: Icon(Icons.water_drop_rounded, color: isExpired ? AppColors.error : AppColors.primary, size: 20)
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.units} Units', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(isExpired ? 'Expired' : 'Expires: ${DateFormat('MMM dd, yyyy').format(item.expiryDate ?? DateTime.now())}', 
                                   style: TextStyle(color: isExpired ? AppColors.error : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            )),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                              style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditInventory(context, item);
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }
}
