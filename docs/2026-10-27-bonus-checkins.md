# Optional bonus check-ins — 2026-10-27

The weekly/monthly quota is a minimum, not an input limit. The first required check-ins satisfy it; later UTC days are explicitly stored as `check_ins.is_bonus`. One check-in per quest and UTC day remains enforced by the existing unique constraint. Applies to Free for all, Co-op, Team battle and Last Standing, including endless quests.

Bonus days give no Aura or permanent XP, consume no reward multipliers and do not change Team battle scores. Home keeps the quota fulfilled and offers an optional Bonus action; the timeline uses a star and a Bonus label. Each anchored period resets the quota. Existing active-weekday restrictions remain in place. Progress quests continue accepting amounts beyond their target and now mark extra activity days as Bonus. Avoid quests retain their existing slip/settlement behavior and never offer positive bonus ticks.

Fixed-length weekly/monthly quests now remain active through their scheduled end, allowing optional days in their last period. Already completed or eliminated participants are not reopened.

Validation: full Flutter tests, exact theme goldens and bonus fixtures across all modes; narrow-screen/large-text Home and timeline checks; ten PostgreSQL regression suites on an isolated, network-disabled restore of the NAS backup. Migration deployment verifies unchanged participants, quests, account count, check-in count and XP. Docker runs only on NAS-BRA.

Deployment evidence: `build/audit/bonus-isolated-tests.txt`, `build/audit/bonus-deployment.txt`, `build/audit/bonus-ui-tests.txt`. Internal store build: 1.0.3 (24).
