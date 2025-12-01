import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../core/api/vehicle_service.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 140,
          child: Row(
            children: [
              // Left side: Vehicle info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              vehicle.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (vehicle.model != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                vehicle.model!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (vehicle.description != null &&
                                vehicle.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                vehicle.description!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Action buttons (only show if user has edit/delete permissions)
                      if (onEdit != null || onDelete != null)
                        Row(
                          children: [
                            // Edit button
                            if (onEdit != null)
                              Material(
                                color: AppColors.accentSecondary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: onEdit,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: AppColors.accentSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            if (onEdit != null && onDelete != null)
                              const SizedBox(width: 8),
                            // Delete button
                            if (onDelete != null)
                              Material(
                                color: AppColors.accentPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: onDelete,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Right side: Vehicle image
              Container(
                width: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFF9386AA),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      'assets/images/car_list_placeholder.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
