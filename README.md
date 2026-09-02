# Study Planner (SSC & HSC)

Personal study app: timer, per-subject chapter tracker (Chapter Complete + Revision
Complete checkboxes), and an analytics dashboard. All data is stored locally on-device
(SQLite via sqflite) — no login, no backend, works fully offline.

## What's included (Draft 1 + Routine + Dark redesign)

- **Timer tab** — pick a subject, run a stopwatch, stop & save logs a session tied to
  that subject and timestamp. The timer now tracks real timestamps (not tick counts)
  and keeps the screen awake while running, so it stays accurate even if the screen
  locks or the app is briefly backgrounded.
- **Routine tab** — daily task list. Add tasks that repeat every day, or one-off tasks
  for a specific date. Tap the check to mark done, the cross to mark missed; tap again
  to reset to pending. Navigate between days with the arrows or the date picker.
- **Subjects tab** — all 13 HSC Science subjects with their real chapter lists in
  Bangla/English, each showing chapter/revision progress %. Tap into a subject to see
  every chapter with its two checkboxes.
- **Analytics tab** — total study time, sessions logged, overall chapter/revision
  completion %, a 7-day study-time trend chart, time-by-subject breakdown, and a
  per-subject progress list.

**Design:** dark mode throughout — near-black canvas, dark slate cards, a violet/teal
accent pair. The Timer and Chapters screens use a neon cyberpunk treatment (grid
background, glowing rings/borders/text). App icon is a glowing neon book.

**Update (language, timer redesign, exam countdown, alerts, progress tabs, period analytics):**
- **Bilingual (Bangla/English)**: every subject and chapter now has an English title
  alongside Bangla, plus core UI labels (nav, timer, progress, analytics, chapter legend).
  Tap the small language pill (🌐 বাং/EN) in any app bar to switch instantly, app-wide.
  Not translated: Routine screen's finer copy (date navigator wording, add-task sheet
  microcopy) and a few Analytics section headers -- left in English for now since they're
  secondary text, easy to extend later in `lib/l10n/app_strings.dart`.
- **Timer redesign**: Study/Revision toggle, Subject + Chapter pickers side by side, goal
  presets (None/30m/60m/Custom) with a liquid-fill progress ring toward your goal, and a
  bell icon opening Alert Settings (Sound/Vibration toggles, persisted).
- **Exam countdown card**: shown at the top of the Timer tab -- days/hrs/min/sec to your
  exam, tap the pencil to set/edit it.
- **Progress tab redesigned**: Syllabus vs Revision toggle with an overall % ring, and
  each subject card now shows explicit completed/remaining counts.
- **Analytics**: Daily/Weekly/Monthly toggle scopes the trend chart and time-by-subject
  breakdown to that period; streak/average/most-studied/top-chapters/routine-completion
  stay as an all-time overview below.
- Database schema bumped to v4 (adds English chapter titles + session type). Existing
  chapters/sessions are preserved and auto-populated with English titles on upgrade.

**Known limitation:** I could not compile this in the sandbox -- Flutter's own SDK
binaries are hosted on a Google Cloud domain outside what I have network access to, even
after cloning the Flutter source successfully. I did a full manual pass (brace/paren
balance, import resolution, no stale API references across all files) but this is not a
substitute for an actual build. Please run it and send me any errors.

Syllabus data lives in `lib/data/seed_data.dart` — edit that file directly if a chapter
name needs fixing or the syllabus changes; it's just a plain Dart list, no rebuild logic
needed beyond a fresh install (since it seeds the database only on first run).

## Running it

You'll need the Flutter SDK installed (this sandbox doesn't have it, so I couldn't
compile an APK here — you'll build it on your machine or hand this folder to Claude
Code with Flutter available).

```bash
cd hsc_study_app
flutter pub get
flutter run          # runs on a connected device/emulator
```

## Building a release APK

```bash
flutter build apk --release
# APK will be at build/app/outputs/flutter-apk/app-release.apk
```

## Project structure

```
lib/
  models/            # Subject, Chapter, StudySession, RoutineTask, TaskCompletion
  data/seed_data.dart # Your confirmed HSC syllabus (edit here to correct chapters)
  db/database_helper.dart  # SQLite schema + queries
  providers/         # AppDataProvider, TimerProvider, RoutineProvider
  screens/           # TimerScreen, RoutineScreen, SubjectsScreen, SubjectDetailScreen, AnalyticsScreen
  main.dart           # App entry, theme, bottom nav shell
```

## Notes / what's NOT in this draft (per our plan — later versions)

- No auto-generated study schedule yet (manual timer only)
- No notifications/reminders yet
- No exam countdown yet
- No app icon/splash screen customization yet (using Flutter defaults)
- Routine tab doesn't yet feed into Analytics (task completion streaks aren't charted yet)

These were intentionally left out to keep this testable fast — happy to add them once
you've tried this version.

**Update (SSC + all HSC groups, class/group selector, bug fixes, icon):**
- Subject catalog expanded from HSC-Science-only (13 subjects) to the full SSC and HSC
  curricula across all three groups -- Science, Business Studies, Humanities -- 42
  subjects / 465 chapters total. HSC Science chapters remain exactly what you confirmed
  earlier; the rest are compiled from standard NCTB chapter lists you provided, so check
  them against your own textbook if anything looks off (`lib/data/seed_data.dart`).
- First launch now asks "which class (SSC/HSC) and which group?" and every screen
  (Timer, Progress, Analytics) filters to just those subjects, plus each level's
  compulsory subjects (Bangla/English/ICT for HSC, General Math/Bangla Grammar/ICT for
  SSC).
- App renamed to **Study Planner**, with the new icon you provided (cropped to just the
  glyph -- the full graphic's text wasn't legible at launcher-icon sizes).
- **Fixed:** timer not updating -- `wakelock_plus` was added but the Android
  `WAKE_LOCK` permission was never declared, which could throw and disrupt state.
  Added the permission and wrapped the wakelock calls so a plugin hiccup can never
  break the timer itself. Also removed a cosmetic bug where the goal-progress ring
  showed a sliver of fill even before pressing Start.
- Routine tasks can now have an optional time-of-day (shown as a badge, tasks sort by
  time within a day).
- Database schema bumped to v5 -- this is a clean re-seed of subjects/chapters/sessions
  (chapter tick progress and study history reset with this update); routine tasks are
  preserved.

**Update (SSC redo, exit confirmation, timer auto-stop, My Details page):**
- Full SSC dataset replaced per your list: 20 SSC subjects (7 compulsory including
  Islam & Moral Education, 5 Science, 4 Business Studies, 4 Humanities) -- 51 subjects /
  637 chapters total across SSC+HSC. HSC data untouched.
- **Fixed:** pressing back no longer exits (and resets the timer) on a single accidental
  tap -- now shows "Press back again to exit" and only exits on a second press within 2
  seconds.
- **Fixed:** the timer now actually stops at your goal instead of silently counting past
  it forever. When the goal is hit, it pauses, alerts (sound/vibration per your Alert
  Settings), and asks: End session, +5 min, or +10 min.
- New **My Details** tab (5th bottom nav item): a student ID card (name, school/college,
  year -- edit via the pencil icon) plus Alert, Language, and Class/Group settings
  consolidated in one place. All stored locally for now -- no sign-up yet, but this is
  the natural spot a future account/backup system will attach to.

**Update (adjustable alarm volume + looping alert):**
- The goal-reached alarm now loops (sound + a repeating vibration pulse every ~1.2s)
  until you actually respond -- End session, +5 min, or +10 min -- instead of a single
  easy-to-miss blip.
- Added a volume slider (under Sound Alert, in both the timer's bell-icon shortcut and
  the My Details > Alerts section). Uses a small synthesized chime bundled with the app
  (`assets/sounds/alarm.wav`) via the `audioplayers` package, so it's fully adjustable
  rather than relying on the OS's fixed system-sound volume.

**Update (contextual quotes):**
- Setting a very short goal (under 10 min) or a very long one (over 2.5 hrs) now
  triggers a playful reaction quote (bilingual, randomized from a small pool) instead of
  silently accepting it.
- A dismissible banner appears on the Timer tab when your study streak has broken (you
  have session history, but 0 current streak) -- a light nudge to restart today, not
  guilt-tripping. Dismissible per app session.
- Quotes live in `lib/data/quotes.dart` -- easy to add more or adjust tone.

**Update (more quotes, task reminder notifications, live timer notification):**
- Expanded quotes with a general motivational pool (12 quotes) shown as a "quote of the
  day" card on the Timer tab (changes daily) -- separate from the playful situational
  ones (short/long goal, broken streak) added last time.
- **Task reminders**: routine tasks with a time set now schedule an actual Android
  notification at that time, repeating weekly on whichever days their group covers.
  Toggle in My Details > Notifications ("Task reminders"). Needs notification + exact
  alarm permissions (Android will prompt on first launch after this update).
- **Live timer notification**: while the timer runs, an ongoing notification shows the
  elapsed time (using Android's native chronometer, so it ticks without draining
  battery on per-second updates), switches to a static "Paused" state when paused, and
  disappears when you stop & save. Toggle in My Details > Notifications ("Show timer in
  notification bar").
- Added the required Android permissions (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM,
  RECEIVE_BOOT_COMPLETED so reminders survive a restart) and Gradle desugaring config
  the notifications plugin needs to build.

**Known limitation:** turning "Task reminders" off doesn't retroactively cancel
already-scheduled reminders for existing tasks -- it takes effect the next time each
task is added or edited. A cleaner full cancel-all-on-toggle can be added later if this
matters in practice.

**Update (quote contrast + real vibration):**
- **Fixed:** quote cards (Quote of the Day, streak-broken banner) and goal-change
  snackbars now use bright white text instead of dim gray -- much more readable
  against the dark background.
- **Fixed:** vibration was using Flutter's `HapticFeedback`, which is a very light tap
  on most phones, not a real alarm buzz. Switched to the `vibration` package for actual
  device vibration -- the goal-reached alarm now vibrates in a strong repeating
  buzz-pause-buzz pattern until you respond, and the save-confirmation vibration is a
  proper 250ms buzz. Falls back to the old haptic tap only on devices without a real
  vibration motor.

