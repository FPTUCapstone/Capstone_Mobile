# UC-02 Mobile verified-first implementation plan

This plan implements `../specs/UC-02-verified-first-amendment.md` on the
existing UC-02 feature branches. Preserve all unrelated working-tree changes.

1. **Use-case transition:** change the Operator use case to create/recover the
   Firebase identity and send mail without a BE POST. Test that unverified
   email never posts, and that a verified token triggers one multipart POST.
   Retain an uncertain POST for explicit same-identity retry; do not delete a
   verified account after a definite BE rejection.
2. **Mobile state and UI:** change the wizard CTA to start verification, show
   the verification step before `PendingApproval`, and submit only after the
   verified-token check. Add the visible unfinished-registration choice to
   the Account step and remove the old Sign In shortcut. Keep the legacy
   submitted-account recovery reachable from UC-02. Update Cubit and widget
   tests for pending, verified, rejected, uncertain and resend states.
3. **Web verification handoff:** use the UC-02-only `operator-mobile` flow.
   The verification page applies a supplied Firebase action code but makes no
   BE call while the Mobile application is not yet submitted. For a Firebase-
   hosted redirect without a code, it directs the user back to Mobile without
   claiming success. Keep existing Traveler and Web Operator paths unchanged.
4. **Verification:** run Mobile format, analyze, tests and Android debug build;
   run FE typecheck, lint, tests and build. Inspect both diffs for unrelated
   changes. Record any skipped live provider flow explicitly.

No commit, push or merge is part of this plan unless requested separately.
