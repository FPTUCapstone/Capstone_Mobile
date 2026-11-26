import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Canonical UC-34 messages shared across Mobile validation, error mapping, and UI.
/// Intentionally omits MSG121 on success due to SRS message-code conflict.
abstract final class OperatorProfileMessages {
  static const requiredField = 'Trường thông tin này là bắt buộc (MSG01).';
  static const businessNameTooLong =
      'Tên doanh nghiệp không được vượt quá 200 ký tự.';
  static const descriptionTooLong =
      'Mô tả doanh nghiệp không được vượt quá 2000 ký tự.';
  static const addressTooLong = 'Địa chỉ trụ sở không được vượt quá 300 ký tự.';
  static const emailTooLong = 'Email liên hệ không được vượt quá 200 ký tự.';
  static const invalidPhone =
      'Số điện thoại không hợp lệ. Vui lòng nhập 10 chữ số bắt đầu bằng 0 (MSG04).';
  static const invalidEmail =
      'Định dạng email không hợp lệ. Vui lòng nhập địa chỉ email hợp lệ (MSG02).';
  static const invalidWebsite =
      'Website phải là đường dẫn hợp lệ bắt đầu bằng http:// hoặc https:// (tối đa 300 ký tự).';
  static const invalidLogo =
      'Tệp logo phải là ảnh JPG, PNG hoặc WebP và dung lượng không vượt quá 5MB (BR-16, MSG19).';
  static const invalidRemoveLogo = 'Yêu cầu xóa logo không hợp lệ.';
  static const notApprovedOperator =
      'Bạn không có quyền truy cập vào chức năng này (MSG126).';
  static const sessionExpired =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const updateSuccess = 'Cập nhật thông tin hồ sơ đối tác thành công.';
  static const systemFailure =
      'TripMate tạm thời không thể xử lý yêu cầu. Vui lòng kiểm tra kết nối và thử lại (MSG127).';
}

final class OperatorProfile extends Equatable {
  const OperatorProfile({
    required this.userId,
    required this.businessName,
    required this.businessDescription,
    required this.businessAddress,
    required this.contactPhone,
    required this.contactEmail,
    required this.businessLicenceNumber,
    required this.taxCode,
    required this.approvalStatus,
    required this.accountEmail,
    this.website,
    this.logoUrl,
    this.localLogoBytes,
    this.isDemo = false,
  });

  final int userId;
  final String businessName;
  final String businessDescription;
  final String businessAddress;
  final String contactPhone;
  final String contactEmail;
  final String? website;
  final String? logoUrl;

  /// Only used in demo mode so locally selected logo previews persist in-memory.
  final Uint8List? localLogoBytes;
  final String businessLicenceNumber;
  final String taxCode;
  final String approvalStatus;
  final String accountEmail;
  final bool isDemo;

  @override
  List<Object?> get props => [
    userId,
    businessName,
    businessDescription,
    businessAddress,
    contactPhone,
    contactEmail,
    website,
    logoUrl,
    localLogoBytes,
    businessLicenceNumber,
    taxCode,
    approvalStatus,
    accountEmail,
    isDemo,
  ];
}

final class OperatorLogoUploadData extends Equatable {
  const OperatorLogoUploadData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  @override
  List<Object?> get props => [bytes, fileName, mimeType];
}

final class UpdateOperatorProfileInput extends Equatable {
  const UpdateOperatorProfileInput({
    required this.businessName,
    required this.businessDescription,
    required this.businessAddress,
    required this.contactPhone,
    required this.contactEmail,
    required this.website,
    this.logo,
    this.removeLogo = false,
  });

  final String businessName;
  final String businessDescription;
  final String businessAddress;
  final String contactPhone;
  final String contactEmail;
  final String website;
  final OperatorLogoUploadData? logo;
  final bool removeLogo;

  /// Returns a normalized copy with trimmed text fields and mutually exclusive logo flags.
  UpdateOperatorProfileInput normalized() => UpdateOperatorProfileInput(
    businessName: businessName.trim(),
    businessDescription: businessDescription.trim(),
    businessAddress: businessAddress.trim(),
    contactPhone: contactPhone.trim(),
    contactEmail: contactEmail.trim(),
    website: website.trim(),
    logo: logo,
    removeLogo: logo != null ? false : removeLogo,
  );

  @override
  List<Object?> get props => [
    businessName,
    businessDescription,
    businessAddress,
    contactPhone,
    contactEmail,
    website,
    logo,
    removeLogo,
  ];
}

final class OperatorProfileValidationErrors extends Equatable {
  const OperatorProfileValidationErrors({
    this.businessName,
    this.businessDescription,
    this.businessAddress,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.logo,
    this.removeLogo,
  });

  final String? businessName;
  final String? businessDescription;
  final String? businessAddress;
  final String? contactPhone;
  final String? contactEmail;
  final String? website;
  final String? logo;
  final String? removeLogo;

  bool get isEmpty =>
      businessName == null &&
      businessDescription == null &&
      businessAddress == null &&
      contactPhone == null &&
      contactEmail == null &&
      website == null &&
      logo == null &&
      removeLogo == null;

  bool get isNotEmpty => !isEmpty;

  String? get logoAreaError => logo ?? removeLogo;

  OperatorProfileValidationErrors copyWith({
    String? businessName,
    bool clearBusinessName = false,
    String? businessDescription,
    bool clearBusinessDescription = false,
    String? businessAddress,
    bool clearBusinessAddress = false,
    String? contactPhone,
    bool clearContactPhone = false,
    String? contactEmail,
    bool clearContactEmail = false,
    String? website,
    bool clearWebsite = false,
    String? logo,
    bool clearLogo = false,
    String? removeLogo,
    bool clearRemoveLogo = false,
  }) => OperatorProfileValidationErrors(
    businessName: clearBusinessName
        ? null
        : (businessName ?? this.businessName),
    businessDescription: clearBusinessDescription
        ? null
        : (businessDescription ?? this.businessDescription),
    businessAddress: clearBusinessAddress
        ? null
        : (businessAddress ?? this.businessAddress),
    contactPhone: clearContactPhone
        ? null
        : (contactPhone ?? this.contactPhone),
    contactEmail: clearContactEmail
        ? null
        : (contactEmail ?? this.contactEmail),
    website: clearWebsite ? null : (website ?? this.website),
    logo: clearLogo ? null : (logo ?? this.logo),
    removeLogo: clearRemoveLogo ? null : (removeLogo ?? this.removeLogo),
  );

  @override
  List<Object?> get props => [
    businessName,
    businessDescription,
    businessAddress,
    contactPhone,
    contactEmail,
    website,
    logo,
    removeLogo,
  ];
}

abstract final class OperatorProfileValidator {
  static const maxBusinessNameLength = 200;
  static const maxDescriptionLength = 2000;
  static const maxAddressLength = 300;
  static const maxEmailLength = 200;
  static const maxWebsiteLength = 300;
  static const maxLogoBytes = 5 * 1024 * 1024; // 5 MB (BR-16)

  static const allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  static final _phoneRegex = RegExp(r'^0\d{9}$');
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? mimeTypeFromExtension(String? extension) {
    return switch (extension?.toLowerCase().trim()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  static bool hasMatchingSignature(Uint8List bytes, String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized == 'image/jpeg') {
      return bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF;
    }
    if (normalized == 'image/png') {
      const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < pngHeader.length) return false;
      for (var i = 0; i < pngHeader.length; i++) {
        if (bytes[i] != pngHeader[i]) return false;
      }
      return true;
    }
    if (normalized == 'image/webp') {
      return bytes.length >= 12 &&
          bytes[0] == 0x52 && // R
          bytes[1] == 0x49 && // I
          bytes[2] == 0x46 && // F
          bytes[3] == 0x46 && // F
          bytes[8] == 0x57 && // W
          bytes[9] == 0x45 && // E
          bytes[10] == 0x42 && // B
          bytes[11] == 0x50; // P
    }
    return false;
  }

  static bool isValidLogo(OperatorLogoUploadData logo) {
    if (logo.bytes.isEmpty || logo.bytes.length > maxLogoBytes) return false;
    final mime = logo.mimeType.toLowerCase();
    if (!allowedMimeTypes.contains(mime)) return false;
    return hasMatchingSignature(logo.bytes, mime);
  }

  static bool isValidWebsite(String value) {
    if (value.length > maxWebsiteLength) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  static OperatorProfileValidationErrors validate(
    UpdateOperatorProfileInput input,
  ) {
    final normalized = input.normalized();

    String? businessNameError;
    if (normalized.businessName.isEmpty) {
      businessNameError = OperatorProfileMessages.requiredField;
    } else if (normalized.businessName.length > maxBusinessNameLength) {
      businessNameError = OperatorProfileMessages.businessNameTooLong;
    }

    String? descriptionError;
    if (normalized.businessDescription.length > maxDescriptionLength) {
      descriptionError = OperatorProfileMessages.descriptionTooLong;
    }

    String? addressError;
    if (normalized.businessAddress.length > maxAddressLength) {
      addressError = OperatorProfileMessages.addressTooLong;
    }

    String? phoneError;
    if (normalized.contactPhone.isNotEmpty &&
        !_phoneRegex.hasMatch(normalized.contactPhone)) {
      phoneError = OperatorProfileMessages.invalidPhone;
    }

    String? emailError;
    if (normalized.contactEmail.isNotEmpty) {
      if (normalized.contactEmail.length > maxEmailLength) {
        emailError = OperatorProfileMessages.emailTooLong;
      } else if (!_emailRegex.hasMatch(normalized.contactEmail)) {
        emailError = OperatorProfileMessages.invalidEmail;
      }
    }

    String? websiteError;
    if (normalized.website.isNotEmpty && !isValidWebsite(normalized.website)) {
      websiteError = OperatorProfileMessages.invalidWebsite;
    }

    String? logoError;
    if (normalized.logo != null && !isValidLogo(normalized.logo!)) {
      logoError = OperatorProfileMessages.invalidLogo;
    }

    return OperatorProfileValidationErrors(
      businessName: businessNameError,
      businessDescription: descriptionError,
      businessAddress: addressError,
      contactPhone: phoneError,
      contactEmail: emailError,
      website: websiteError,
      logo: logoError,
    );
  }
}
