import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/create_tour_package_page.dart';

/// Loads one existing package (and the catalogues), then hands it to the shared editor.
final class EditTourPackagePage extends StatefulWidget {
  const EditTourPackagePage({required this.tourId, super.key});
  final int? tourId;

  @override
  State<EditTourPackagePage> createState() => _EditTourPackagePageState();
}

final class _EditTourPackagePageState extends State<EditTourPackagePage> {
  @override
  void initState() {
    super.initState();
    final tourId = widget.tourId;
    if (tourId != null) {
      final cubit = context.read<CreateTourPackageCubit>();
      cubit
        ..loadOptions()
        ..loadDetail(tourId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tourId = widget.tourId;
    if (tourId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour package')),
        body: const Center(child: Text('This tour package link is invalid.')),
      );
    }
    return BlocBuilder<CreateTourPackageCubit, CreateTourPackageState>(
      buildWhen: (previous, current) =>
          previous.detailStatus != current.detailStatus ||
          previous.optionsStatus != current.optionsStatus,
      builder: (context, state) {
        final loadingDetail =
            state.detailStatus == TourPackageDetailStatus.loading ||
            state.detailStatus == TourPackageDetailStatus.idle;
        if (state.detailStatus == TourPackageDetailStatus.failure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tour package')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.detailFailure?.message ??
                          'Could not load this tour package.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => context
                          .read<CreateTourPackageCubit>()
                          .loadDetail(tourId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (loadingDetail || state.detail == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tour package')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return CreateTourPackagePage(
          // The form is initialised once from the loaded package.
          key: ValueKey('tour-${state.detail!.id}'),
          initial: state.detail,
        );
      },
    );
  }
}
