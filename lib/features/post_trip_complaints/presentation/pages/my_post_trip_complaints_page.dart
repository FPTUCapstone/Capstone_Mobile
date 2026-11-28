import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/my_post_trip_complaints_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

final class MyPostTripComplaintsPage extends StatelessWidget {
  const MyPostTripComplaintsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(
        title: PostTripComplaintStrings.myComplaints,
      ),
      body: BlocBuilder<MyPostTripComplaintsCubit, MyPostTripComplaintsState>(
        builder: (context, state) => switch (state.phase) {
          MyPostTripComplaintsPhase.loading => Center(
            child: CircularProgressIndicator(color: c.brandTeal),
          ),
          MyPostTripComplaintsPhase.failure => ErrorView(
            message: state.message ?? PostTripComplaintStrings.systemError,
            retryLabel: PostTripComplaintStrings.retry,
            onRetry: context.read<MyPostTripComplaintsCubit>().load,
          ),
          MyPostTripComplaintsPhase.ready when state.items.isEmpty =>
            const AppEmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Chưa có khiếu nại nào.',
            ),
          MyPostTripComplaintsPhase.ready => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return AppCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(TripMateRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.tealSoftContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.report_gmailerrorred_outlined,
                        size: 20,
                        color: c.brandTeal,
                      ),
                    ),
                    title: Text(
                      item.tourTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${item.bookingCode} · ${PostTripComplaintStrings.statusLabel(item.status)}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                    trailing: Icon(Icons.chevron_right, color: c.textMuted),
                    onTap: () =>
                        context.go(AppRoutes.postTripComplaint(item.bookingId)),
                  ),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
