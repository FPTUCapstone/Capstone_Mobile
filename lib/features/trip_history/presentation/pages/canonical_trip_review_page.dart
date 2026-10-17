import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/canonical_trip_review_cubit.dart';

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

  Future<void> _pickPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    if (result.files.length > 5) {
      setState(() => _message = 'Select no more than five photos.');
      return;
    }
    final photos = <ReviewPhotoUpload>[];
    for (final file in result.files) {
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 5000000) {
        setState(
          () => _message = 'Each photo must be no larger than 5,000,000 bytes.',
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
          () => _message = 'Only JPEG, PNG, and WebP photos are supported.',
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
      setState(() => _message = 'Provide a rating, title, and review.');
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

  @override
  Widget build(BuildContext context) {
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Review published.')));
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
          return Scaffold(
            appBar: AppBar(title: const Text('Trip review')),
            body: _busy && data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_message != null)
                        Semantics(
                          liveRegion: true,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_message!),
                            ),
                          ),
                        ),
                      if (data != null) ...[
                        Card(
                          child: ListTile(
                            title: Text(data.name),
                            subtitle: Text(
                              '${data.bookingReference}\n${data.departureAtUtc.toLocal()}',
                            ),
                          ),
                        ),
                        if (data.existingReviewKind == 'legacy')
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('This legacy review is read-only.'),
                            ),
                          )
                        else if (review == null && !data.canSubmit)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Review unavailable: ${data.submitUnavailableReason}',
                              ),
                            ),
                          )
                        else ...[
                          if (readOnly)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'The seven-day edit window has expired. This review is read-only.',
                                ),
                              ),
                            ),
                          IgnorePointer(
                            ignoring: readOnly || _busy,
                            child: Column(
                              children: [
                                Semantics(
                                  label: 'Rating',
                                  child: Row(
                                    children: [
                                      for (var i = 1; i <= 5; i++)
                                        IconButton(
                                          tooltip:
                                              '$i ${i == 1 ? 'star' : 'stars'}',
                                          onPressed: () =>
                                              setState(() => _rating = i),
                                          icon: Icon(
                                            i <= _rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: i <= _rating
                                                ? Colors.amber
                                                : null,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _title,
                                  maxLength: 200,
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _content,
                                  maxLength: 1000,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Review',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                if (review == null)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _photos.isEmpty
                                          ? 'Add photos (optional)'
                                          : '${_photos.length} photo(s) selected',
                                    ),
                                    trailing: const Icon(Icons.add_a_photo),
                                    onTap: _pickPhotos,
                                  ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Publish my display name'),
                                  value: _publishName,
                                  onChanged: (value) =>
                                      setState(() => _publishName = value),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => context.canPop()
                                          ? context.pop()
                                          : context.go(AppRoutes.tripHistory),
                                      child: const Text('Cancel'),
                                    ),
                                    if (!readOnly)
                                      FilledButton(
                                        onPressed: _busy ? null : _submit,
                                        child: Text(
                                          review == null
                                              ? 'Publish review'
                                              : 'Update review',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}
