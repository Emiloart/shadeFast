# ShadeFast Incident Runbook

Date: 2026-02-25
Owner: Safety/Operations

## Severity Levels

- `SEV-1`: Active harm/legal-critical event (CSAM, credible violence threat, major data/security breach).
- `SEV-2`: High-impact abuse or moderation failure affecting multiple communities.
- `SEV-3`: Localized issue with limited blast radius.

## Global Response Targets

- `SEV-1` acknowledge within 5 minutes.
- `SEV-2` acknowledge within 15 minutes.
- `SEV-3` acknowledge within 60 minutes.

## Core Contacts

- On-call engineering: primary responder for infrastructure and function controls.
- Safety reviewer: moderation triage decision owner.
- Product owner: user-facing decision and communications.

## Standard Incident Flow

1. Open an incident thread with timestamp, reporter, and scope.
2. Classify severity (`SEV-1` to `SEV-3`).
3. Contain blast radius first (pause risky endpoints, apply bans, disable links if needed).
4. Preserve forensic evidence (logs, report IDs, affected row IDs).
5. Mitigate root cause.
6. Confirm recovery and monitor for regression.
7. Publish post-incident summary and remediation tasks.

## Playbook: Abuse Spike

Trigger:
- Sudden jump in reports/hour or repeated spam content patterns.

Actions:
1. Use `list-reports` with `status=open` and prioritize `critical`/`high`.
2. Apply `enforce-user` temporary/permanent bans for repeat offenders.
3. Tighten rate-limit thresholds in edge functions if needed.
4. Track impacted communities and top abuse reasons.

Exit:
- Report inflow stabilizes and abuse recurrence drops for 60 minutes.

## Playbook: Harmful/Illegal Content

Trigger:
- CSAM, terror content, or explicit credible violence threats.

Actions:
1. Escalate to `SEV-1` immediately.
2. Remove/expire offending content and block actor session (`enforce-user`).
3. Preserve identifiers: report IDs, post/reply IDs, timestamps.
4. Follow legal/regulatory reporting obligations for jurisdiction.

Exit:
- Content removed, actor restricted, legal reporting steps completed.

## Playbook: Retention/Cleanup Failure

Trigger:
- `expired_media_queue` backlog growing or `expire-content` failures.

Actions:
1. Run `make expire-content-dry-run` and inspect queue size.
2. Execute `make expire-content` with reduced batch size if needed.
3. Check scheduled workflow `.github/workflows/media-retention.yml` logs.
4. Record failed object paths and error reasons.

Exit:
- Queue drain trend restored and failures resolved.

## Playbook: Link Abuse (Private Chats)

Trigger:
- Burst of malicious private links or spam propagation.

Actions:
1. Apply bans via `enforce-user` for abusive sessions.
2. Increase `create-private-chat-link` rate limit strictness.
3. Review read-once chat misuse via reports and enforcement logs.

Exit:
- Link abuse returns to baseline and no active spread signal.

## Post-Incident Checklist

- Root cause documented.
- Customer/safety impact assessed.
- Backlog tickets created with owners and dates.
- Policy, detection, and enforcement gaps updated.
- Retrospective complete within 72 hours.
