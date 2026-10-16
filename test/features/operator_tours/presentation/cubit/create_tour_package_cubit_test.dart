import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/services/tour_image_picker.dart';

import '../../operator_tours_fakes.dart';

CreateTourPackageCubit _cubit(
  FakeOperatorTourRepository repository, {
  TourImagePicker? picker,
}) => CreateTourPackageCubit(
  createTour: CreateTourPackageUseCase(repository),
  loadOptions: LoadTourPackageOptionsUseCase(repository),
  getTour: GetTourPackageUseCase(repository),
  updateTour: UpdateTourPackageUseCase(repository),
  submitForReview: SubmitTourForReviewUseCase(repository),
  media: ManageTourMediaUseCase(repository),
  imagePicker: picker,
);

final _image = TourImageUpload(
  fileName: 'cover.jpg',
  contentType: 'image/jpeg',
  bytes: [1, 2, 3],
);

void main() {
  group('create', () {
    test(
      'draft JSON carries destinations, policy and terms the backend needs',
      () {
        final json = sampleDraft().toJson();

        expect(json['destinationIds'], [1, 2]);
        expect(json['cancellationPolicyTemplateId'], 7);
        expect(json['inclusions'], isNull);
      },
    );

    test('a successful create reports the created draft ID', () async {
      final cubit = _cubit(FakeOperatorTourRepository());
      addTearDown(cubit.close);

      await cubit.submit(sampleDraft());

      expect(cubit.state.status, CreateTourPackageStatus.success);
      expect(cubit.state.tourId, 42);
    });

    test(
      'retrying the same payload after a failure reuses the idempotency key; an edit rotates it',
      () async {
        final repository = FakeOperatorTourRepository(failCreates: 2);
        final cubit = _cubit(repository);
        addTearDown(cubit.close);

        await cubit.submit(sampleDraft());
        expect(cubit.state.status, CreateTourPackageStatus.failure);
        await cubit.submit(sampleDraft());
        expect(repository.createKeys[1], repository.createKeys[0]);

        await cubit.submit(sampleDraft(title: 'Edited title'));
        expect(cubit.state.status, CreateTourPackageStatus.success);
        expect(repository.createKeys[2], isNot(repository.createKeys[0]));

        await cubit.submit(sampleDraft(title: 'Edited title'));
        expect(repository.createKeys[3], isNot(repository.createKeys[2]));
      },
    );

    test('a failed save is never reported as success', () async {
      final cubit = _cubit(FakeOperatorTourRepository(failCreates: 1));
      addTearDown(cubit.close);

      await cubit.submit(sampleDraft());

      expect(cubit.state.status, CreateTourPackageStatus.failure);
      expect(cubit.state.failure, const NetworkFailure());
      expect(cubit.state.tourId, isNull);
    });

    test('loads the catalogues and surfaces a retryable failure', () async {
      final cubit = _cubit(FakeOperatorTourRepository(failOptionLoads: 1));
      addTearDown(cubit.close);

      await cubit.loadOptions();
      expect(cubit.state.optionsStatus, TourPackageOptionsStatus.failure);
      await cubit.loadOptions();

      expect(cubit.state.optionsStatus, TourPackageOptionsStatus.ready);
      expect(cubit.state.options!.destinations.map((d) => d.name), [
        'Da Nang',
        'Hoi An',
      ]);
      expect(cubit.state.optionsFailure, isNull);
    });
  });

  group('editing an existing package', () {
    test('loads the package with its photos and readiness', () async {
      final repository = FakeOperatorTourRepository()
        ..media = [const TourMediaItem(id: 1, url: 'u', isPrimary: true)];
      final cubit = _cubit(repository);
      addTearDown(cubit.close);

      await cubit.loadDetail(42);

      expect(cubit.state.detailStatus, TourPackageDetailStatus.ready);
      expect(cubit.state.detail!.reviewBlockers, ['primary_image_missing']);
      expect(cubit.state.detail!.warnings.single.code, 'duplicate_poi');
      expect(cubit.state.media.single.isPrimary, isTrue);
    });

    test(
      'saving updates the loaded package instead of creating another',
      () async {
        final repository = FakeOperatorTourRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await cubit.loadDetail(42);

        await cubit.submit(sampleDraft(title: 'Renamed'));

        expect(cubit.state.status, CreateTourPackageStatus.success);
        expect(repository.updates.single.$1, 42);
        expect(repository.updates.single.$2.title, 'Renamed');
        expect(repository.createKeys, isEmpty);
      },
    );

    test('submitting for review saves first, then asks the server', () async {
      final repository = FakeOperatorTourRepository(
        detail: sampleDetail(blockers: const []),
      );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.loadDetail(42);

      await cubit.saveAndSubmitForReview(sampleDraft());

      expect(repository.updates, hasLength(1));
      expect(repository.submitted, [42]);
      expect(cubit.state.reviewStatus, TourReviewStatus.submitted);
      expect(cubit.state.detail!.status, TourPackageStatus.pending);
    });

    test(
      'a refused review stays a Draft and shows the server message',
      () async {
        final repository = FakeOperatorTourRepository(
          failSubmitWith: const ConstraintFailure('Not ready'),
        );
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await cubit.loadDetail(42);

        await cubit.saveAndSubmitForReview(sampleDraft());

        expect(cubit.state.reviewStatus, TourReviewStatus.failure);
        expect(cubit.state.reviewFailure, const ConstraintFailure('Not ready'));
        expect(cubit.state.detail!.status, TourPackageStatus.draft);
      },
    );
  });

  group('photos', () {
    test('the first photo becomes the cover and the list refreshes', () async {
      final repository = FakeOperatorTourRepository();
      final cubit = _cubit(
        repository,
        picker: FakeTourImagePicker(image: _image),
      );
      addTearDown(cubit.close);
      await cubit.loadDetail(42);

      await cubit.addImage();

      expect(repository.uploads.single.makePrimary, isTrue);
      expect(cubit.state.media.single.isPrimary, isTrue);
      expect(cubit.state.detail!.reviewBlockers, isEmpty);
      expect(cubit.state.mediaBusy, isFalse);
    });

    test(
      'retrying the same file after a failure reuses the upload key',
      () async {
        final repository = FakeOperatorTourRepository(failUploads: 1);
        final cubit = _cubit(
          repository,
          picker: FakeTourImagePicker(image: _image),
        );
        addTearDown(cubit.close);
        await cubit.loadDetail(42);

        await cubit.addImage();
        expect(cubit.state.mediaFailure, const NetworkFailure());
        await cubit.addImage();

        expect(repository.uploads, hasLength(2));
        expect(repository.uploads[1].key, repository.uploads[0].key);
        expect(cubit.state.mediaFailure, isNull);
      },
    );

    test(
      'an unreadable or oversized file is a validation message, not an upload',
      () async {
        final repository = FakeOperatorTourRepository();
        final cubit = _cubit(
          repository,
          picker: FakeTourImagePicker(failure: const TourImageReadFailure()),
        );
        addTearDown(cubit.close);
        await cubit.loadDetail(42);

        await cubit.addImage();

        expect(repository.uploads, isEmpty);
        expect(cubit.state.mediaFailure, isA<ValidationFailure>());
        expect(cubit.state.mediaBusy, isFalse);
      },
    );

    test('cancelling the picker does nothing', () async {
      final repository = FakeOperatorTourRepository();
      final cubit = _cubit(repository, picker: FakeTourImagePicker());
      addTearDown(cubit.close);
      await cubit.loadDetail(42);

      await cubit.addImage();

      expect(repository.uploads, isEmpty);
      expect(cubit.state.mediaBusy, isFalse);
    });

    test('changes the cover photo and removes a photo', () async {
      final repository = FakeOperatorTourRepository()
        ..media = [
          const TourMediaItem(id: 1, url: 'a', isPrimary: true),
          const TourMediaItem(id: 2, url: 'b', isPrimary: false),
        ];
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.loadDetail(42);

      await cubit.setPrimaryImage(2);
      expect(cubit.state.media.firstWhere((item) => item.isPrimary).id, 2);
      await cubit.deleteImage(1);

      expect(repository.deleteCalls, [1]);
      expect(cubit.state.media.map((item) => item.id), [2]);
    });
  });
}
