import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/cage_model.dart';

class CageCard extends StatelessWidget {
  final CageModel cage;
  final VoidCallback onTap;
  final List<String> alerts;
  final List<String> reservations;

  const CageCard({
    Key? key,
    required this.cage,
    required this.onTap,
    this.alerts = const [],
    this.reservations = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors/style based on status
    Color borderColor;

    // Status text & icon for empty/maintenance
    IconData? emptyIcon;
    String emptyText = '';
    Color emptyColor = Colors.transparent;

    bool isAlert = alerts.isNotEmpty;
    bool isOccupied = cage.occupants.isNotEmpty;
    bool isMaintenance = cage.status == 'maintenance';

    if (isMaintenance) {
      borderColor = const Color(0xFFE2E8F0); // slate-200
      emptyIcon = Icons.build_circle;
      emptyText = 'Đang bảo trì';
      emptyColor = const Color(0xFF94A3B8); // slate-400
    } else if (isOccupied && isAlert) {
      borderColor = const Color(0xFFFDE68A); // yellow-200
    } else if (isOccupied) {
      borderColor = const Color(0xFFBFDBFE); // blue-200
    } else {
      borderColor = const Color(0xFFBBF7D0); // green-200
      emptyIcon = Icons.check_circle;
      emptyText = 'Trống';
      emptyColor = const Color(0xFF4ADE80); // green-500
    }

    // Border container for the entire card
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name & Type Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                cage.type == 'cat' ? '🐈' : '🐕',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cage.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B), // slate-800
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(cage.price)}/ngày',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cage.type == 'cat'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cage.type == 'cat'
                            ? 'Mèo'
                            : (cage.name.contains('Lớn')
                                  ? 'Chó lớn'
                                  : (cage.name.contains('TB')
                                        ? 'Chó TB'
                                        : 'Chó nhỏ')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cage.type == 'cat'
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Content Area
                if (isOccupied) ...[
                  _buildOccupantInfo(isAlert),

                  // Badges/Pills for alerts
                  if (alerts.isNotEmpty)
                    ...alerts.map((msg) {
                      bool isVital = msg.toLowerCase().contains('sinh hiệu');
                      return Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVital
                                  ? Icons.monitor_heart
                                  : Icons.access_time_filled,
                              size: 14,
                              color: const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                msg,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ] else ...[
                  // Empty or Maintenance State
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: emptyColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(emptyIcon, color: emptyColor, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            emptyText,
                            style: TextStyle(
                              color: emptyColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (reservations.isNotEmpty && !isOccupied && !isMaintenance)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event,
                              size: 16,
                              color: Color(0xFF7C3AED),
                            ), // purple-600
                            const SizedBox(width: 6),
                            Text(
                              reservations.first,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOccupantInfo(bool isAlert) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cage.occupants.map((occupant) {
        final days =
            DateTime.now().difference(occupant.admissionDate).inDays + 1;
        String statusText = isAlert ? 'Theo dõi' : 'Ổn định';
        Color statusColor = isAlert
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pets,
                          size: 18,
                          color: Color(0xFF1E40AF),
                        ), // blue-800
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            occupant.petName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'N$days',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ), // slate-400
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),
              // Diagnosis and Staff info
              Text(
                '${occupant.diagnosis ?? 'Chưa rỗ'} • BS. ${occupant.staffName ?? 'Không xác định'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                ), // slate-600
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Treatment Pills
              if (occupant.activeTreatments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: occupant.activeTreatments.take(3).map((t) {
                      bool isFluid =
                          t.toLowerCase().contains('truyền') ||
                          t.toLowerCase().contains('nacl');
                      return Container(
                        constraints: const BoxConstraints(maxWidth: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFluid
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isFluid
                                ? const Color(0xFFBFDBFE)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFluid ? Icons.water_drop : Icons.medication,
                              size: 12,
                              color: isFluid
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isFluid
                                      ? const Color(0xFF1E40AF)
                                      : const Color(0xFF166534),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
