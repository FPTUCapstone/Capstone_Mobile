# Real messaging implementation

1. Inspect existing auth, DI, router, SignalR client and chat prototype. Use the established feature-first Clean Architecture and flutter_bloc.
2. Add strict domain contracts and tested API/realtime implementations; no raw networking in UI/Cubit.
3. Implement tested route-scoped Cubit lifecycle, paging, drafts, reliable sends, read state and group interactions.
4. Replace seeded group prototype with the real Messages list/thread UI; wire route, authenticated identity, DI and visible entry points.
5. Review security and business behavior; run format/analyze/tests/APK, then emulator workflows with two real accounts. Fix findings and repeat affected checks.
