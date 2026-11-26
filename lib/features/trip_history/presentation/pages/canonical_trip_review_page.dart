import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/canonical_trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class CanonicalTripReviewPage extends StatefulWidget {
  const CanonicalTripReviewPage({super.key, required this.cubit});
  final CanonicalTripReviewCubit cubit;
  @override
  State<CanonicalTripReviewPage> createState() =>
      _CanonicalTripReviewPageState();
}

final class _CanonicalTripReviewPageState
    extends State<CanonicalTripReviewPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  CanonicalReviewContext? _context;
  List<ReviewPhotoUpload> _photos = [];
  int _rating = 0;
  bool _publishName = true;
  bool _busy = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.cubit.load();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    widget.cubit.close();
    super.dispose();
  }

  String _ratingLabel(int rating) => switch (rating) {
    1 => '1/5 · Không hài lòng',
    2 => '2/5 · Cần cải thiện',
    3 => '3/5 · Tạm ổn',
    4 => '4/5 · Rất hài lòng',
    5 => '5/5 · Tuyệt vời',
    _ => 'Chạm để chọn số sao',
  };

  Future<void> _pickPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    if (result.files.length > 5) {
      setState(() => _message = TripHistoryStringsEn.validationPhotoMaxCount);
      return;
    }
    final photos = <ReviewPhotoUpload>[];
    for (final file in result.files) {
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 5000000) {
        setState(
          () => _message = TripHistoryStringsEn.validationPhotoExceedsLimit,
        );
        return;
      }
      final ext = file.extension?.toLowerCase();
      final type = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (type == null) {
        setState(
          () => _message = TripHistoryStringsEn.validationPhotoInvalidType,
        );
        return;
      }
      photos.add(
        ReviewPhotoUpload(name: file.name, contentType: type, bytes: bytes),
      );
    }
    setState(() {
      _photos = photos;
      _message = null;
    });
  }

  Future<void> _submit() async {
    final context = _context;
    if (context == null ||
        _rating < 1 ||
        _title.text.trim().isEmpty ||
        _content.text.trim().isEmpty) {
      setState(
        () => _message =
            'Vui lòng chọn số sao, nhập tiêu đề và nội dung đánh giá.',
      );
      return;
    }
    await widget.cubit.submit(
      rating: _rating,
      title: _title.text.trim(),
      content: _content.text.trim(),
      publishDisplayName: _publishName,
      photos: _photos,
    );
  }

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.tripHistory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CoastalPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? p.border : const Color(0xFFEDEAE1);

    return BlocProvider.value(
      value: widget.cubit,
      child: BlocConsumer<CanonicalTripReviewCubit, CanonicalTripReviewState>(
        listener: (context, state) {
          final data = state.context;
          final review = data?.review;
          setState(() {
            _context = data;
            _busy = state.busy;
            _message = state.message;
            if (review != null) {
              _rating = review.rating;
              _title.text = review.title;
              _content.text = review.content;
              _publishName = review.publishDisplayName;
            }
          });
          if (state.outcome == CanonicalReviewOutcome.created) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(TripHistoryStringsEn.reviewSubmitSuccess),
              ),
            );
            if (context.canPop()) {
              context.pop(true);
            } else {
              context.go(AppRoutes.tripHistory);
            }
          }
        },
        builder: (context, state) {
          final data = _context;
          final review = data?.review;
          final readOnly = review != null && !(data?.isEditable ?? false);
          final canShowForm =
              data != null &&
              data.existingReviewKind != 'legacy' &&
              (review != null || data.canSubmit);

          return Scaffold(
            backgroundColor: p.canvas,
            appBar: AppBar(
              backgroundColor: p.surface,
              surfaceTintColor: Colors.transparent,
              foregroundColor: p.ink,
              elevation: 0,
              title: Text(
                review != null
                    ? TripHistoryStringsEn.viewReviewTitle
                    : TripHistoryStringsEn.tripReviewTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: hairline),
              ),
            ),
            body: _busy && data == null
                ? Center(child: CircularProgressIndicator(color: p.primary))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_message != null)
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.warningBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.warningBorder),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: p.warningText,
                              ),
                            ),
                          ),
                        ),
                      if (data != null) ...[
                        // Tour Context Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tour đã hoàn thành',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? p.accent
                                          : const Color(0xFF995436),
                                    ),
                                  ),
                                  Text(
                                    formatCalendarDateTime(
                                      data.departureAtUtc.toLocal(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data.name,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mã đơn ${data.bookingReference}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (data.existingReviewKind == 'legacy')
                          _NoticeCard(
                            text: 'Đánh giá cũ này hiện chỉ có thể xem.',
                            palette: p,
                          )
                        else if (review == null && !data.canSubmit)
                          _NoticeCard(
                            text:
                                'Chưa thể đánh giá: ${data.submitUnavailableReason ?? ''}',
                            palette: p,
                          )
                        else ...[
                          if (readOnly)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NoticeCard(
                                text: TripHistoryStringsEn.reviewReadOnlyNotice,
                                palette: p,
                              ),
                            ),
                          IgnorePointer(
                            ignoring: readOnly || _busy,
                            child: Column(
                              children: [
                                // Rating Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mức độ hài lòng của bạn',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: p.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Semantics(
                                        label: 'Rating',
                                        child: Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 4,
                                          runSpacing: 6,
                                          children: [
                                            for (var i = 1; i <= 5; i++)
                                              IconButton(
                                                tooltip: '$i sao',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 38,
                                                      minHeight: 38,
                                                    ),
                                                onPressed: () =>
                                                    setState(() => _rating = i),
                                                icon: Icon(
                                                  i <= _rating
                                                      ? Icons.star_rounded
                                                      : Icons
                                                            .star_outline_rounded,
                                                  size: 34,
                                                  color: i <= _rating
                                                      ? const Color(0xFFD97706)
                                                      : p.border,
                                                ),
                                              ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _ratingLabel(_rating),
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: _rating > 0
                                                    ? p.ink
                                                    : p.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Form Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        TripHistoryStringsEn.reviewTitleLabel,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _title,
                                        maxLength: 200,
                                        decoration: InputDecoration(
                                          hintText: TripHistoryStringsEn
                                              .reviewTitleHint,
                                          filled: true,
                                          fillColor: p.canvas.withValues(
                                            alpha: 0.6,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.primary,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        TripHistoryStringsEn.reviewContentLabel,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _content,
                                        maxLength: 1000,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          hintText: TripHistoryStringsEn
                                              .reviewContentHint,
                                          filled: true,
                                          fillColor: p.canvas.withValues(
                                            alpha: 0.6,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: p.primary,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (review == null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              TripHistoryStringsEn
                                                  .photoSectionTitle,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: p.ink,
                                              ),
                                            ),
                                            Text(
                                              '${_photos.length}/5 ảnh',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: p.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _pickPhotos,
                                            icon: Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 18,
                                              color: p.secondary,
                                            ),
                                            label: Text(
                                              _photos.isEmpty
                                                  ? 'Thêm ảnh từ thư viện (JPG, PNG, tối đa 5 MB)'
                                                  : 'Đã chọn ${_photos.length} ảnh · Chạm để chọn lại',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: p.secondary,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: p.canvas
                                                  .withValues(alpha: 0.6),
                                              side: BorderSide(color: p.border),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: hairline,
                                      ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        activeTrackColor: p.primary,
                                        title: Text(
                                          'Hiển thị tên của bạn',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: p.ink,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Tắt nếu muốn đăng ẩn danh',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: p.secondary,
                                          ),
                                        ),
                                        value: _publishName,
                                        onChanged: (value) => setState(
                                          () => _publishName = value,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
            bottomNavigationBar: canShowForm
                ? SafeArea(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border(top: BorderSide(color: hairline)),
                      ),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _navigateBack(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.ink,
                              side: BorderSide(color: p.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              TripHistoryStringsEn.actionCancel,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (!readOnly) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.primary,
                                  foregroundColor: p.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  review == null
                                      ? TripHistoryStringsEn.actionSubmitReview
                                      : TripHistoryStringsEn.actionSaveReview,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, required this.palette});

  final String text;
  final CoastalPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.warningBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: palette.warningText,
        ),
      ),
    );
  }
}
