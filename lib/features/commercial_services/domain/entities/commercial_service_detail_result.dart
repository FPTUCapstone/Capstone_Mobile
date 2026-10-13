import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';

sealed class CommercialServiceDetailResult {
  const CommercialServiceDetailResult();
}

final class CommercialServiceDetailLoaded
    extends CommercialServiceDetailResult {
  const CommercialServiceDetailLoaded({
    required this.composite,
    this.noticeMessage,
  });

  final CommercialServiceDetailComposite composite;
  final String? noticeMessage;
}

final class CommercialServiceDetailInactiveOrNotFound
    extends CommercialServiceDetailResult {
  const CommercialServiceDetailInactiveOrNotFound({this.message});

  final String? message;
}

final class CommercialServiceDetailFailure
    extends CommercialServiceDetailResult {
  const CommercialServiceDetailFailure({this.message});

  final String? message;
}
