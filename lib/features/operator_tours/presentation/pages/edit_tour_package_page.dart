import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/create_tour_package_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

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
    final c = context.tmColors;
    final tourId = widget.tourId;
    if (tourId == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Gói tour'),
        body: const AppEmptyState(
          icon: Icons.link_off_rounded,
          title: 'Liên kết gói tour không hợp lệ.',
        ),
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
            backgroundColor: c.canvas,
            appBar: const AppCoastalAppBar(title: 'Gói tour'),
            body: ErrorView(
              message:
                  state.detailFailure?.message ??
                  'Không thể tải thông tin gói tour này.',
              retryLabel: 'Thử lại',
              onRetry: () =>
                  context.read<CreateTourPackageCubit>().loadDetail(tourId),
            ),
          );
        }
        if (loadingDetail || state.detail == null) {
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: const AppCoastalAppBar(title: 'Gói tour'),
            body: Center(child: CircularProgressIndicator(color: c.brandTeal)),
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
