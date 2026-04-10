/// Blood Bank Dashboard - manage blood inventory
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
import '../../models/blood_inventory_model.dart';
import '../../providers/auth_provider.dart';

class BloodBankDashboard extends StatefulWidget {
  const BloodBankDashboard({super.key});

  @override
  State<BloodBankDashboard> createState() => _BloodBankDashboardState();
}

class _BloodBankDashboardState extends State<BloodBankDashboard> {
  final FirestoreService _fs = FirestoreService();

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
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                     child: Text(user?.name ?? 'Blood Bank', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.bgDark,
                    ],
                  ),
                ),
              ),
            ),
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
        label: const Text('Add Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            ),
            const SizedBox(height: 24),
            const Text('Inventory Empty', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
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
               const Text('Current Stock Levels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ).animate().fade().slideX(),
          const SizedBox(height: 16),
          // Blood type overview grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: AppConstants.bloodGroups.length,
            itemBuilder: (context, index) {
              final bg = AppConstants.bloodGroups[index];
              final count = totals[bg] ?? 0;
              final isLow = count < 5 && count > 0;
              final isEmpty = count == 0;
              
              Color statusColor = isEmpty ? AppColors.textMuted : isLow ? AppColors.warning : AppColors.success;
              
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.15),
                      statusColor.withValues(alpha: 0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(bg, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: statusColor)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      Text('units', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]
                  ),
                ]),
              ).animate().fade(duration: 400.ms).scaleXY(begin: 0.8, end: 1.0, delay: (index * 40).ms);
            },
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
               Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
               const SizedBox(width: 8),
               const Text('Stock Batches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ).animate().fade(delay: 200.ms).slideX(),
          const SizedBox(height: 16),
          
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _inventoryCard(entry.value).animate().fade().slideY(begin: 0.1, end: 0, delay: (200 + entry.key * 80).ms),
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
          width: 54, height: 54,
          decoration: BoxDecoration(
             gradient: LinearGradient(
               colors: isExpired 
                 ? [AppColors.error.withValues(alpha: 0.8), AppColors.error]
                 : [AppColors.primary.withValues(alpha: 0.8), AppColors.primary]
             ),
             borderRadius: BorderRadius.circular(14),
             boxShadow: [
               BoxShadow(color: (isExpired ? AppColors.error : AppColors.primary).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
             ],
          ),
          child: Center(child: Text(item.bloodGroup, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text('${item.units} Units', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (item.units == 0)
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                   child: const Text('EMPTY', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700))
                )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: isExpired ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 6),
              if (expiry != null) Text(
                isExpired ? 'Expired' : 'Expires in $daysLeft days',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isExpired ? AppColors.error : daysLeft != null && daysLeft < 7 ? AppColors.warning : AppColors.textSecondary)),
            ],
          ),
        ])),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
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
        decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                const Text('Add New Stock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Blood Group', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            BloodGroupSelector(selectedGroup: bg, onSelected: (g) => ss(() => bg = g)),
            const SizedBox(height: 20),
            const Text('Quantity', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () { if (units > 1) ss(() => units--); }, 
                  style: IconButton.styleFrom(backgroundColor: AppColors.bgCardLight),
                  icon: const Icon(Icons.remove_rounded), color: AppColors.textSecondary),
                const SizedBox(width: 20),
                Text('$units', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Text('units', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(width: 20),
                IconButton(onPressed: () => ss(() => units++), 
                   style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
                   icon: const Icon(Icons.add_rounded), color: AppColors.primary),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Expiry Date', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, firstDate: DateTime.now(), initialDate: expiry!, lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) ss(() => expiry = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(expiry!), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
               style: ElevatedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               ),
               onPressed: () async {
                  Navigator.pop(ctx);
                  await _fs.updateInventory(BloodInventoryModel(id: '', bloodBankId: auth.firebaseUser!.uid, bloodBankName: auth.userModel!.name, bloodGroup: bg, units: units, expiryDate: expiry));
               }, 
               child: const Text('Add to Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text(item.bloodGroup, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(height: 12),
            const Text('Update Stock', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () { if (units > 0) ss(() => units--); }, icon: const Icon(Icons.remove_circle_outline_rounded), color: AppColors.textSecondary, iconSize: 28),
            const SizedBox(width: 16),
            Text('$units', style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            IconButton(onPressed: () => ss(() => units++), icon: const Icon(Icons.add_circle_outline_rounded), color: AppColors.primary, iconSize: 28),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(ctx); _fs.updateInventory(item.copyWith(units: units)); }, 
            child: const Text('Update')),
        ],
      ),
    ));
  }
}
