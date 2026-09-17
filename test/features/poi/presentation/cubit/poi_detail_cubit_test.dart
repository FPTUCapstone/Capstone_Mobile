import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_state.dart';

void main() {
  blocTest<PoiDetailCubit, PoiDetailState>(
    'rejects a non-numeric deep-link id without calling the API',
    build: () => PoiDetailCubit(GetPoiDetailUseCase(_DetailRepository())),
    act: (cubit) => cubit.load('abc'),
    verify: (cubit) => expect(cubit.state.status, PoiDetailStatus.invalid),
  );

  blocTest<PoiDetailCubit, PoiDetailState>(
    'renders a dedicated not-found state',
    build: () => PoiDetailCubit(GetPoiDetailUseCase(_DetailRepository())),
    act: (cubit) => cubit.load('999'),
    verify: (cubit) => expect(cubit.state.status, PoiDetailStatus.notFound),
  );
}

class _DetailRepository implements PoiRepository {
  @override
  Future<PoiDetail> getPoiDetail(int id) async {
    throw const NotFoundFailure();
  }

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) => throw UnimplementedError();
}
