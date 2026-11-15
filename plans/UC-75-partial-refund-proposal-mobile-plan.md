# UC-75 Partial Refund Proposal — Mobile Plan

1. Data source test → `DioPartialRefundProposalRemoteDataSource` (GET/POST paths, body, parsing,
   invalid id, unknown status).
2. Repository test → `PartialRefundProposalRepositoryImpl` (409 response_closed → MSG165 conflict,
   403 → permission, 5xx → server failure).
3. Cubit test → `PartialRefundProposalCubit` (load, accept, decline, closed + reload, MSG127 keeps
   status, no double submit).
4. Page test → `PartialRefundProposalPage` (amount + deadline, confirm dialog, MSG164 SnackBar,
   closed state with MSG165).
5. Route + DI test → `/traveler/complaints/:complaintId/partial-refund-proposal`.
6. `dart format`, `flutter analyze`, `flutter test`.
