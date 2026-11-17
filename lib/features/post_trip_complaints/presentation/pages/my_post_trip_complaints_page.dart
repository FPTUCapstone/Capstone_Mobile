import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/my_post_trip_complaints_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/resources/post_trip_complaint_strings.dart';

final class MyPostTripComplaintsPage extends StatelessWidget {
  const MyPostTripComplaintsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(PostTripComplaintStrings.myComplaints)),
    body: BlocBuilder<MyPostTripComplaintsCubit, MyPostTripComplaintsState>(
      builder: (context, state) => switch (state.phase) {
        MyPostTripComplaintsPhase.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        MyPostTripComplaintsPhase.failure => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.message ?? PostTripComplaintStrings.systemError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: context.read<MyPostTripComplaintsCubit>().load,
                  child: const Text(PostTripComplaintStrings.retry),
                ),
              ],
            ),
          ),
        ),
        MyPostTripComplaintsPhase.ready when state.items.isEmpty =>
          const Center(child: Text('No complaints found.')),
        MyPostTripComplaintsPhase.ready => ListView(
          children: state.items
              .map(
                (item) => ListTile(
                  title: Text(item.tourTitle),
                  subtitle: Text('${item.bookingCode} · ${item.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.go(AppRoutes.postTripComplaint(item.bookingId)),
                ),
              )
              .toList(),
        ),
      },
    ),
  );
}
