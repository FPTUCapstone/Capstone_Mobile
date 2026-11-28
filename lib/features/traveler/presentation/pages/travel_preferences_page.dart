import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';

/// UC-09: loads real options and saved preferences from the Backend on
/// entry (triggered by the router when the Cubit is created) and saves the
/// full five-field state. Interests and food are multi-select; Preferred
/// Transport, Travel Pace, and Risk Tolerance are single-choice with an
/// explicit "No preference" option that clears the field to `null`
/// (spec §5/§7).
class TravelPreferencesPage extends StatelessWidget {
  const TravelPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return BlocConsumer<TravelPreferencesCubit, TravelPreferencesState>(
      listener: (context, state) {
        if (state.status == TravelPreferencesStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu sở thích du lịch.')),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TravelPreferencesCubit>();

        if (state.isLoading) {
          return AppPageScaffold(
            title: 'Sở thích du lịch',
            content: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: CircularProgressIndicator(color: c.brandTeal),
                ),
              ),
            ],
          );
        }

        if (state.status == TravelPreferencesStatus.error &&
            state.options.preferredTransportModes.isEmpty) {
          return AppPageScaffold(
            title: 'Sở thích du lịch',
            content: [
              AppAlert(
                message: state.errorMessage ?? 'Đã có lỗi xảy ra.',
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Thử lại', onPressed: cubit.load),
            ],
          );
        }

        return AppPageScaffold(
          title: 'Sở thích du lịch',
          content: [
            const AppAlert(
              message:
                  'Sở thích là gợi ý ưu tiên. Hệ thống sẽ áp dụng khi có thể, tuy nhiên lịch trình thực tế có thể điều chỉnh linh hoạt.',
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              icon: Icons.directions_transit_outlined,
              title: 'Phương tiện ưu tiên',
              error: state.fieldErrors['preferredTransportMode']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Không ưu tiên'),
                    selected: state.preferences.preferredTransportMode == null,
                    onSelected: (_) => cubit.setPreferredTransportMode(null),
                  ),
                  ...state.options.preferredTransportModes.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected:
                          state.preferences.preferredTransportMode == value,
                      onSelected: (_) => cubit.setPreferredTransportMode(value),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              icon: Icons.speed_outlined,
              title: 'Nhịp độ du lịch',
              error: state.fieldErrors['travelPace']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Không ưu tiên'),
                    selected: state.preferences.travelPace == null,
                    onSelected: (_) => cubit.setTravelPace(null),
                  ),
                  ...state.options.travelPaces.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected: state.preferences.travelPace == value,
                      onSelected: (_) => cubit.setTravelPace(value),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              icon: Icons.interests_outlined,
              title: 'Sở thích',
              error: state.fieldErrors['interests']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: state.options.interests
                    .map(
                      (option) => FilterChip(
                        label: Text(_label(option.key)),
                        selected: state.preferences.interests.contains(
                          option.key,
                        ),
                        onSelected: (_) => cubit.toggleInterest(option.key),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              icon: Icons.restaurant_outlined,
              title: 'Ẩm thực ưu tiên',
              error: state.fieldErrors['foodPreferences']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: state.options.foodPreferences
                    .map(
                      (value) => FilterChip(
                        label: Text(_label(value)),
                        selected: state.preferences.foodPreferences.contains(
                          value,
                        ),
                        onSelected: (_) => cubit.toggleFoodPreference(value),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _Section(
              icon: Icons.shield_outlined,
              title: 'Mức độ chấp nhận rủi ro',
              error: state.fieldErrors['riskTolerance']?.firstOrNull,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Không ưu tiên'),
                    selected: state.preferences.riskTolerance == null,
                    onSelected: (_) => cubit.setRiskTolerance(null),
                  ),
                  ...state.options.riskTolerances.map(
                    (value) => ChoiceChip(
                      label: Text(_label(value)),
                      selected: state.preferences.riskTolerance == value,
                      onSelected: (_) => cubit.setRiskTolerance(value),
                    ),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(message: state.errorMessage!, type: AppAlertType.error),
            ],
          ],
          footer: AppButton(
            label: 'Lưu sở thích',
            isLoading: state.isSaving,
            onPressed: state.isSaving ? null : cubit.save,
          ),
        );
      },
    );
  }

  static const _optionLabels = <String, String>{
    'walking': 'Đi bộ',
    'motorbike': 'Xe máy',
    'car': 'Ô tô',
    'publictransit': 'Phương tiện công cộng',
    'bicycle': 'Xe đạp',
    'taxi': 'Taxi',
    'bus': 'Xe buýt',
    'relaxed': 'Thư thái',
    'moderate': 'Vừa phải',
    'balanced': 'Cân bằng',
    'fast': 'Nhanh',
    'active': 'Năng động',
    'intense': 'Dày đặc',
    'slow': 'Chậm rãi',
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
    'conservative': 'An toàn',
    'adventurous': 'Mạo hiểm',
    'norestriction': 'Không kiêng cữ',
    'vegetarian': 'Ăn chay',
    'vegan': 'Thuần chay',
    'halal': 'Halal',
    'seafood': 'Hải sản',
    'localcuisine': 'Ẩm thực địa phương',
    'streetfood': 'Ẩm thực đường phố',
    'glutenfree': 'Không gluten',
    'dairyfree': 'Không sữa',
    'nutfree': 'Không hạt',
    'finedining': 'Ẩm thực cao cấp',
    'spicy': 'Đồ cay',
    'nopork': 'Không thịt heo',
    'nobeef': 'Không thịt bò',
    'pescatarian': 'Ăn chay có hải sản',
    'kosher': 'Kosher',
    'beach': 'Biển',
    'heritage': 'Di sản',
    'culture': 'Văn hóa',
    'history': 'Lịch sử',
    'nature': 'Thiên nhiên',
    'food': 'Ẩm thực',
    'cuisine': 'Ẩm thực',
    'adventure': 'Mạo hiểm',
    'shopping': 'Mua sắm',
    'nightlife': 'Về đêm',
    'spiritual': 'Tâm linh',
    'architecture': 'Kiến trúc',
    'art': 'Nghệ thuật',
    'photography': 'Nhiếp ảnh',
    'wellness': 'Nghỉ dưỡng',
    'entertainment': 'Giải trí',
    'family': 'Gia đình',
    'localexperience': 'Trải nghiệm địa phương',
    'mountain': 'Núi non',
    'island': 'Đảo',
    'temple': 'Chùa & Đền',
    'museum': 'Bảo tàng',
    'park': 'Công viên',
    'landmark': 'Địa danh nổi bật',
    'market': 'Chợ địa phương',
    'cafe': 'Cà phê',
    'sightseeing': 'Tham quan',
    'relaxation': 'Thư giãn',
    'watersports': 'Thể thao dưới nước',
    'hiking': 'Leo núi',
    'ecotourism': 'Du lịch sinh thái',
  };

  static String _label(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s_-]+'), '').toLowerCase();
    final mapped = _optionLabels[normalized];
    if (mapped != null) return mapped;
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (i > 0 && char == char.toUpperCase() && char != char.toLowerCase()) {
        buffer.write(' ');
      }
      buffer.write(i == 0 ? char.toUpperCase() : char);
    }
    return buffer.toString();
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.child,
    required this.title,
    this.error,
  });

  final IconData icon;
  final Widget child;
  final String title;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: c.brandTeal),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
            if (error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
