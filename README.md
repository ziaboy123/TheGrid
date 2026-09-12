# The Grid

A personal life dashboard for iPhone: freeform notes that replace rigid to-do
apps, plus a Today view that pulls together your calendar and unread mail.

Built because to-do apps force everything into tasks/due-dates/priorities,
and that's not how most days actually work. The Grid keeps the flexibility of
a plain notes app — collapsible boards, dividers, checklists, rich text — with
none of the structure you didn't ask for.

## Features

- **Boards** — freeform sections with collapsible headers, dividers,
  checklists, and rich text. No forced fields, no subscriptions.
- **Today** — a single view of today's calendar agenda and unread mail counts
  across your accounts.
- **Lock screen** — Face ID/passcode gate in front of everything.
- **iCloud Drive backup** — one-tap export/restore to a `The Grid` folder in
  your own iCloud Drive.
- **Search** — find a board by title or by anything written inside it.
- **Pinning** — keep the boards you use daily at the top.
- **Attachments** — attach a photo or file to any line; shown as a filename
  tile, never an inline thumbnail, with tap-to-preview via QuickLook.
- **Daily reminder** — a local notification with its own time per weekday.
- **Home Screen widget** — board names only, tap one to jump straight into
  it via a deep link.

## Stack

SwiftUI + SwiftData (iOS 17+), WidgetKit, EventKit (calendar), local IMAP for
mail unread counts, `LocalAuthentication` for the lock screen, and iCloud
Drive (not CloudKit sync) for backup. The Xcode project is generated from
[`project.yml`](project.yml) via [XcodeGen](https://github.com/yonaskolb/XcodeGen)
— it isn't committed, so run this first:

```bash
brew install xcodegen   # if you don't have it
xcodegen generate
open LifeDashboard.xcodeproj
```

## Status

Personal project, actively used day to day. Weather (needs a paid Apple
Developer account for WeatherKit) and real CloudKit sync are the two
deliberately deferred pieces — everything else on the roadmap is built.
