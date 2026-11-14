import 'package:equatable/equatable.dart';

enum PoiFavoriteStatus { idle, saving, saveFailed }

final class PoiFavoriteState extends Equatable {
  const PoiFavoriteState({
    this.isFavorite = false,
    this.status = PoiFavoriteStatus.idle,
  });

  /// What the heart shows: the saved mark, or the tapped one while saving.
  final bool isFavorite;
  final PoiFavoriteStatus status;

  @override
  List<Object?> get props => [isFavorite, status];
}
