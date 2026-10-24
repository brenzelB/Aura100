# Quest start after local midnight

## Confirmed cause

The NAS clock read at `2026-10-24 22:13 UTC` was correct. In Berlin this was
already October 25. Two newly created, active solo quests had `starts_on` set to
October 25, so the existing UTC schedule correctly rejected their check-ins as
not started. No account data or quest titles were included in the inspection.

Quest creation had combined the device's local calendar fields with a UTC
midnight value. The backend, Home agenda, progress periods, and check-in history
all use shared UTC quest days. The creation form was the inconsistent component.

## Fix

- Convert the current instant to UTC before initializing the start date.
- Use the same day for the start picker's selected date, first selectable date,
  and today marker, and for the end picker's today marker.
- Display the upcoming daily reset in the device's local time.
- Repair legacy drafts whose start represented local today, preserving their
  duration. Mark new UTC drafts so intentionally scheduled future dates remain
  unchanged.
- Rebase a past start if the creation sheet remains open across UTC midnight.
- Derive the default end from the selected start so midnight cannot change the
  default seven-day duration between field initializations.

## Validation

Four widget regression cases cover devices ahead of and behind the UTC calendar
day, legacy draft repair with duration preservation, and an intentional future
start. The focused quest creation, draft, and balance suites passed 18 tests.
`flutter analyze --no-pub` completed with no issues.

Existing server quest dates were not changed by this code fix. A specific
affected quest must be identified before a targeted data correction.
