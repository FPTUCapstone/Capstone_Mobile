# TM-83 / UC-37 Mobile handoff

Scope: existing Operator shell > My tour packages > owned tour editor > Preview & save > Submit for review. No new Administrator routes or features. No commit, push, production email, or backend mutation performed by this mobile task.

## Implementation

- Existing presentation/use-case/repository/data-source flow sends the optional trimmed note. Whitespace-only notes use the legacy no-body request. Explicit Dart String.length checks enforce the 4,000 UTF-16-unit boundary in the dialog and use case.
- Additive detail note/submission UTC timestamp and submission acknowledgement are parsed. Legacy responses without metadata remain valid; no client timestamp is invented.
- Confirmation identifies the tour and explains Staff review, Pending/read-only, and publication requirements. Dialog content scrolls, actions wrap, and cancellation/back/Escape/barrier dismissal does not save or submit.
- A shared mutation guard excludes overlapping save, submit and photo work. Cubit lifecycle guards prevent late emissions and a picker result from uploading after disposal.
- Confirmed submission locks Pending immediately; follow-up refresh failure cannot turn it into failure. Ambiguous submit failures reload authoritative detail; when this cannot be confirmed, the editor locks until explicit reload. Known Pending results reconcile as submitted.
- Required-fields and per-day itinerary blockers have human copy; unknown blocker/warning codes and arbitrary backend validation strings are not displayed.

## Existing local tools

- SDK physical root: `E:\A FPT\ChuyenNganh8\PRM393\flutter\flutter` (Flutter 3.47.5, Dart 3.13.4).
- `T:` is a temporary subst mapping of that root, used to avoid native-hook failures from spaces in the physical SDK path. No SDK was installed.
- Flutter: `T:\bin\flutter.bat`; Dart: `T:\bin\cache\dart-sdk\bin\dart.exe`.
- Android SDK is also at that root; adb: `T:\platform-tools\adb.exe`; emulator: `T:\emulator\emulator.exe`.
- Java: `E:\A FPT\ChuyenNganh8\PRM393\Android\jbr`.
- AVD: `C:\Users\ASUS\.android\avd\Pixel_8.ini`, pointing to `E:\A FPT\ChuyenNganh8\PRM393\Android_Virtual\Pixel_8.avd`.

## Parent runtime verification

The parent owns the real emulator, isolated database and API. Use `--dart-define=API_BASE_URL=http://10.0.2.2:5003` and the user-provided local-only approved Operator fixture (`tm83.operator@tripmate.test`). Credentials are intentionally not stored here.

Fixtures needed: owned ready Draft and Rejected tours; owned Pending/Approved/Published tours for read-only checks; Drafts with each missing prerequisite; a foreign-owned tour; and unapproved/inactive Operator sessions. A ready fixture needs required tour data, destination, an itinerary activity on each day, active cover image, cancellation-policy snapshot, and a valid priced future departure. Isolate mutation fixtures so a completed submission does not invalidate another scenario.

Verify actual keyboard/text scaling/small screen, cancel/back/barrier dismissal, trimmed note and emoji boundaries, exactly one PUT then POST after confirmation, Pending status after reload, and no second submit. Exercise offline/lost response and an unavailable refresh after an accepted POST. Gradle/APK build is deferred until parent confirms Backend/Web builds are finished, per resource coordination.

## Verification results

Results will be completed after the active checks finish. Initial focused baseline was blocked by the SDK-space native-hook issue. Regression red phase confirmed missing metadata and unsafe HTTP 400 validation text. The first green focused run passed 42 tests. Whole-repository format verification passed (913 Dart files, zero changes). Full test and final analysis results are pending.
