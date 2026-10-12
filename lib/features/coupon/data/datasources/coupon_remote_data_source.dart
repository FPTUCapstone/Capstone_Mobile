import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/coupon_draft.dart';
import 'package:trip_mate_mobile/features/coupon/domain/entities/eligible_coupon_tour.dart';

abstract interface class CouponRemoteDataSource {
  Future<List<EligibleCouponTour>> getEligibleTours();
  Future<String> createCoupon(CouponDraft draft);
}

final class DioCouponRemoteDataSource implements CouponRemoteDataSource {
  DioCouponRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;
  static const _basePath = '/api/v1/operator/coupons';

  @override
  Future<List<EligibleCouponTour>> getEligibleTours() async {
    final response = await _dio.get<Object?>('$_basePath/eligible-tours');
    final payload = response.data;
    if (payload is! List) {
      throw const FormatException('Eligible tours response must be a list.');
    }
    return payload
        .map((value) {
          if (value is! Map) {
            throw const FormatException('Tour item is invalid.');
          }
          final item = Map<String, Object?>.from(value);
          final id = item['tourId'];
          final title = item['title'];
          final basePrice = item['basePrice'];
          if (id is! num || title is! String || basePrice is! num) {
            throw const FormatException(
              'Tour item is missing a required value.',
            );
          }
          final destination = item['destination'];
          return EligibleCouponTour(
            id: id.toInt(),
            title: title,
            destination: destination is String ? destination : null,
            basePrice: basePrice,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<String> createCoupon(CouponDraft draft) async {
    final response = await _dio.post<Object?>(_basePath, data: draft.toJson());
    final payload = response.data;
    if (payload is! Map) {
      throw const FormatException('Coupon response is invalid.');
    }
    final code = payload['code'];
    if (code is! String || code.trim().isEmpty) {
      throw const FormatException('Coupon code is missing.');
    }
    return code;
  }
}
