import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/address_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/address_search_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';

const _candidate = AddressCandidate(
  id: 'poi.fpt-da-nang',
  name: 'Đại học FPT Đà Nẵng',
  fullAddress: 'Đào Tấn, Đà Nẵng, 50500, Việt Nam',
);

const _place = AddressSuggestion(
  name: 'Đại học FPT Đà Nẵng',
  fullAddress: 'Đào Tấn, Đà Nẵng, 50500, Việt Nam',
  latitude: 15.96862121,
  longitude: 108.26072704,
);

final class _Repository implements AddressSearchRepository {
  _Repository({this.isAvailable = true});

  @override
  final bool isAvailable;
  final calls = <String>[];
  final pending = <String, Completer<List<AddressCandidate>>>{};
  Object? suggestFailure;
  Object? resolveFailure;

  @override
  Future<List<AddressCandidate>> suggest(
    String query, {
    DeviceLocation? near,
  }) async {
    calls.add(query);
    if (suggestFailure != null) throw suggestFailure!;
    final gate = pending[query];
    if (gate != null) return gate.future;
    return const [_candidate];
  }

  @override
  Future<AddressSuggestion> resolve(AddressCandidate candidate) async {
    if (resolveFailure != null) throw resolveFailure!;
    return _place;
  }
}

void main() {
  test('search shows the matching suggestions', () async {
    final cubit = AddressSearchCubit(repository: _Repository());
    addTearDown(cubit.close);

    await cubit.search('dai hoc fpt');

    expect(cubit.state.status, AddressSearchStatus.ready);
    expect(cubit.state.candidates, [_candidate]);
  });

  test('a blank query or missing Mapbox stays idle without a call', () async {
    final repository = _Repository();
    final cubit = AddressSearchCubit(repository: repository);
    addTearDown(cubit.close);
    final unavailable = AddressSearchCubit(
      repository: _Repository(isAvailable: false),
    );
    addTearDown(unavailable.close);

    await cubit.search('   ');
    await unavailable.search('Hội An');

    expect(repository.calls, isEmpty);
    expect(cubit.state.status, AddressSearchStatus.idle);
    expect(unavailable.state.status, AddressSearchStatus.idle);
  });

  test('a failed search keeps its safe message', () async {
    final repository = _Repository()..suggestFailure = const NetworkFailure();
    final cubit = AddressSearchCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.search('Hội An');

    expect(cubit.state.status, AddressSearchStatus.failure);
    expect(cubit.state.message, 'Please check your connection.');
  });

  test('a slower earlier search cannot replace a newer one', () async {
    final repository = _Repository();
    final slow = repository.pending['old'] = Completer();
    final cubit = AddressSearchCubit(repository: repository);
    addTearDown(cubit.close);

    final first = cubit.search('old');
    await cubit.search('new');
    slow.complete(const []);
    await first;

    expect(cubit.state.candidates, [_candidate]);
  });

  test('resolving the picked suggestion returns its location', () async {
    final cubit = AddressSearchCubit(repository: _Repository());
    addTearDown(cubit.close);
    await cubit.search('dai hoc fpt');

    final place = await cubit.resolve(_candidate);

    expect(place, _place);
    expect(cubit.state.resolvingId, isNull);
  });

  test('a failed resolve keeps the suggestions for another pick', () async {
    final repository = _Repository()
      ..resolveFailure = const ServerFailure(
        'Address search is unavailable right now.',
      );
    final cubit = AddressSearchCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.search('dai hoc fpt');

    final place = await cubit.resolve(_candidate);

    expect(place, isNull);
    expect(cubit.state.candidates, [_candidate]);
    expect(cubit.state.message, 'Address search is unavailable right now.');
  });
}
