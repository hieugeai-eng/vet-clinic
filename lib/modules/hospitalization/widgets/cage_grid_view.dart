import 'package:flutter/material.dart';
import '../../../data/models/cage_model.dart';
import 'cage_card.dart';

class CageGridView extends StatelessWidget {
  final List<CageModel> cages;
  final Function(CageModel) onCageTap;
  final Map<String, List<String>> alerts;
  final Map<String, List<String>> reservations;

  final bool useGrid;
  final int crossAxisCount;

  const CageGridView({
    Key? key,
    required this.cages,
    required this.onCageTap,
    this.alerts = const {},
    this.reservations = const {},
    this.useGrid = true,
    this.crossAxisCount = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.crop_free, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Chưa có chuồng nào',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (!useGrid) {
      // Mobile: Split View (Mini Grid Summary + Detailed List for Occupied Cages)
      final occupiedCages = cages.where((c) => c.occupants.isNotEmpty).toList();

      return CustomScrollView(
        key: const ValueKey('cage_mobile_split_view'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Section 1: Mini Grid Overview
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMiniCageBox(context, cages[index]),
                childCount: cages.length,
              ),
            ),
          ),

          // Section Title
          if (occupiedCages.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Text(
                  '🐾 ĐANG NỘI TRÚ (${occupiedCages.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),

          // Section 2: Detailed Cards (Only Occupied ones)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final cage = occupiedCages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: CageCard(
                    cage: cage,
                    onTap: () => onCageTap(cage),
                    alerts: alerts[cage.id] ?? [],
                    reservations: reservations[cage.id] ?? [],
                  ),
                );
              }, childCount: occupiedCages.length),
            ),
          ),

          // Spacing at bottom
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      );
    }

    // Desktop: Grid
    return GridView.builder(
      key: const ValueKey('cage_grid'),
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: cages.length,
      itemBuilder: (context, index) => _buildCageItem(context, index),
    );
  }

  Widget _buildCageItem(BuildContext context, int index) {
    final cage = cages[index];
    return CageCard(
      cage: cage,
      onTap: () => onCageTap(cage),
      alerts: alerts[cage.id] ?? [],
      reservations: reservations[cage.id] ?? [],
    );
  }

  Widget _buildMiniCageBox(BuildContext context, CageModel cage) {
    bool isAlert = (alerts[cage.id] ?? []).isNotEmpty;
    bool isOccupied = cage.occupants.isNotEmpty;
    bool isMaintenance = cage.status == 'maintenance';

    Color bgColor = const Color(0xFFF0FDF4);
    Color borderColor = const Color(0xFFBBF7D0);

    if (isMaintenance) {
      bgColor = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFCBD5E1);
    } else if (isOccupied && isAlert) {
      bgColor = const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFFDE68A);
    } else if (isOccupied) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
    }

    return InkWell(
      onTap: () => onCageTap(cage),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cage.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            if (isOccupied) ...[
              Expanded(
                child: Text(
                  cage.occupants.first.petName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Text(
                    'N${DateTime.now().difference(cage.occupants.first.admissionDate).inDays + 1} · ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    isAlert ? '⚠' : 'OK',
                    style: TextStyle(
                      fontSize: 10,
                      color: isAlert
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ] else if (isMaintenance) ...[
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('🔧', style: TextStyle(fontSize: 14)),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Trống',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              if ((reservations[cage.id] ?? []).isNotEmpty)
                const Text(
                  '📅 Có khách hẹn',
                  style: TextStyle(fontSize: 10, color: Color(0xFF7C3AED)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
