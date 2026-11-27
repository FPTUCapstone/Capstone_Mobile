import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_profile_repository.dart';

/// In-memory demo repository used exclusively when the Operator shell runs in demo mode.
final class DemoOperatorProfileRepository implements OperatorProfileRepository {
  DemoOperatorProfileRepository({OperatorProfile? initial})
    : _current = initial ?? defaultProfile;

  static const defaultProfile = OperatorProfile(
    userId: 1048,
    businessName: 'Han River Travel Co., Ltd',
    businessDescription:
        'Licensed inbound operator running day tours around Da Nang, Hoi An and Ba Na Hills since 2015.',
    businessAddress: '02 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
    contactPhone: '0905388123',
    contactEmail: 'contact@hanrivertravel.vn',
    website: 'https://hanrivertravel.vn',
    businessLicenceNumber: '48-0123/2020/TCDL-GP LHQT',
    taxCode: '0401998877',
    approvalStatus: 'Approved',
    accountEmail: 'operator.hanriver@tripmate.vn',
    isDemo: true,
  );

  OperatorProfile _current;

  @override
  Future<OperatorProfile> getProfile() async => _current;

  @override
  Future<OperatorProfile> updateProfile(
    UpdateOperatorProfileInput input,
  ) async {
    final normalized = input.normalized();
    final nextLogoUrl = normalized.logo != null
        ? null
        : (normalized.removeLogo ? null : _current.logoUrl);
    final nextLocalLogoBytes = normalized.logo != null
        ? normalized.logo!.bytes
        : (normalized.removeLogo ? null : _current.localLogoBytes);

    _current = OperatorProfile(
      userId: _current.userId,
      businessName: normalized.businessName,
      businessDescription: normalized.businessDescription,
      businessAddress: normalized.businessAddress,
      contactPhone: normalized.contactPhone,
      contactEmail: normalized.contactEmail,
      website: normalized.website.isEmpty ? null : normalized.website,
      logoUrl: nextLogoUrl,
      localLogoBytes: nextLocalLogoBytes,
      businessLicenceNumber: _current.businessLicenceNumber,
      taxCode: _current.taxCode,
      approvalStatus: _current.approvalStatus,
      accountEmail: _current.accountEmail,
      isDemo: true,
    );
    return _current;
  }
}
