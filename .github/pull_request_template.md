## 1. Related PRs
- Link related PRs or _No related PRs_
## 2. Attention!
**These are things you need to get done before release to production. Please read it carefully!**
- _write here_
## 3. Summary(short description about PRs's goal)
- _write here_
## 4. Link specs
- _write here_
## 5. Output(Image, video, JSON example)
- _write here_

## Definition of Done

**Testing**

- [ ] `flutter pub get`
- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --debug` when relevant and supported

**Checklist**

- [ ] Task scope is respected
- [ ] Clean Architecture boundaries are respected
- [ ] BLoC/Cubit is used appropriately
- [ ] Traveler, Tour Operator, and Group Host boundaries are correct
- [ ] No Administrator Flutter functionality was introduced
- [ ] No secrets or generated build artifacts are committed
- [ ] `dart format` passes
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] UI was checked on reasonable mobile sizes when applicable
- [ ] Loading, empty, error, and permission states were considered when applicable
- [ ] Documentation was updated if required
