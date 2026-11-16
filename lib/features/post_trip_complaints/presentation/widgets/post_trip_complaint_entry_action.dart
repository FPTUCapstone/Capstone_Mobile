import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_state.dart';

/// Shows the complaint entry point only after the server authoritatively
/// confirms that this booking is eligible or already has a complaint to view.
final class PostTripComplaintEntryAction extends StatelessWidget {
  const PostTripComplaintEntryAction({
    required this.bookingId,
    this.cubit,
    super.key,
  });

  final int bookingId;
  final PostTripComplaintCubit? cubit;

  @override
  Widget build(BuildContext context) {
    if (cubit == null &&
        !serviceLocator.isRegistered<PostTripComplaintCubit>()) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (_) =>
          cubit ??
          (serviceLocator<PostTripComplaintCubit>(param1: bookingId)..load()),
      child: BlocBuilder<PostTripComplaintCubit, PostTripComplaintState>(
        builder: (context, state) {
          final complaintContext = state.context;
          if (complaintContext == null ||
              (!complaintContext.canSubmit &&
                  complaintContext.complaint == null)) {
            return const SizedBox.shrink();
          }
          final isExisting = complaintContext.complaint != null;
          return FilledButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.go(AppRoutes.postTripComplaint(bookingId));
            },
            icon: const Icon(Icons.report_outlined),
            label: Text(isExisting ? 'View complaint' : 'Submit complaint'),
          );
        },
      ),
    );
  }
}
