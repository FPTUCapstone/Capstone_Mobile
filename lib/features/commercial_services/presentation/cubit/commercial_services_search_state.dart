import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_list_item.dart';

enum CommercialServicesSearchStatus {
  initial,
  loading,
  success,
  empty,
  failure,
}

final class CommercialServicesSearchState extends Equatable {
  const CommercialServicesSearchState({
    this.status = CommercialServicesSearchStatus.initial,
    this.isDemoMode = false,
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedDateIso = '',
    this.maxPriceVnd,
    this.items = const [],
    this.errorMessage,
    this.totalCount = 0,
    this.page = 1,
    this.totalPages = 1,
  });

  final CommercialServicesSearchStatus status;
  final bool isDemoMode;
  final String searchQuery;
  final CommercialServiceCategory? selectedCategory;
  final String selectedDateIso;
  final int? maxPriceVnd;
  final List<CommercialServiceListItem> items;
  final String? errorMessage;
  final int totalCount;
  final int page;
  final int totalPages;

  CommercialServicesSearchState copyWith({
    CommercialServicesSearchStatus? status,
    bool? isDemoMode,
    String? searchQuery,
    CommercialServiceCategory? selectedCategory,
    bool clearCategory = false,
    String? selectedDateIso,
    int? maxPriceVnd,
    bool clearMaxPrice = false,
    List<CommercialServiceListItem>? items,
    String? errorMessage,
    bool clearError = false,
    int? totalCount,
    int? page,
    int? totalPages,
  }) {
    return CommercialServicesSearchState(
      status: status ?? this.status,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedDateIso: selectedDateIso ?? this.selectedDateIso,
      maxPriceVnd: clearMaxPrice ? null : (maxPriceVnd ?? this.maxPriceVnd),
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isDemoMode,
    searchQuery,
    selectedCategory,
    selectedDateIso,
    maxPriceVnd,
    items,
    errorMessage,
    totalCount,
    page,
    totalPages,
  ];
}
