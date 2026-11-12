# Versioning

How Volt Core numbers its releases, where the number lives, and how to change it.

## Current decision

The version is **`0.9.0+1`** and stays there until the project backend is set up
(production Supabase project, accounts and roles, backups, release signing).
No bumps are needed while the app is only run on the test tablet. The first bump
happens when a build is first uploaded or shared outside the team.

## The number

`pubspec.yaml` holds one line:

```
version: 0.9.0+1
```

It has two parts:

| Part | Example | Meaning |
|---|---|---|
| **Version name** `MAJOR.MINOR.PATCH` | `0.9.0` | What people see: Settings > About, the Settings list, the debug menu |
| **Build number** `+N` | `+1` | Android's `versionCode`. **Must go up with every build you upload anywhere** (Play, a shared APK, a test group). It never resets. |

Flutter turns these into Android's `versionName` and `versionCode` automatically
(`android/app/build.gradle.kts` reads `flutter.versionName` / `flutter.versionCode`).
The app reads its own version at run time (`lib/core/app_version.dart`), so the
screens can never disagree with the build.

## When to change which part

| Change | Bump | Example |
|---|---|---|
| A fix, a wording change, a small tweak, no new screen | **PATCH** | `0.9.0` to `0.9.1` |
| A new feature or screen, a new SQL migration that adds things | **MINOR** | `0.9.1` to `0.10.0` |
| A change that makes older installs unsafe or incompatible: a migration that removes or renames data the old app needs, a role or permission model change, a forced re-sign-in | **MAJOR** | `0.10.0` to `1.0.0` |
| Uploading the same version again (a rejected store upload, a rebuilt test APK) | **build only** | `1.0.0+6` to `1.0.0+7` |

## The stages

| Stage | Version | Who gets it |
|---|---|---|
| Development | any, builds are never uploaded | you, on the test tablet (debug builds) |
| **Pilot** | `0.9.x` | 2-3 technicians, a couple of weeks (see `phase3_pilot_certification_runbook.md`) |
| **Production** | `1.0.0` and up | everyone |

**Recommendation:** start the next uploaded build at `0.9.0`, not `1.0.0`.
`1.0.0` then means "the pilot passed", and it is a promise you can keep. The
project currently says `1.0.0+1`, which was a placeholder and was never released.
Moving to `0.9.0+1` is a downgrade of the version name only; the build number
keeps counting up, so nothing breaks. If you prefer to keep `1.0.0` as the first
version, that is fine too; just decide once.

## Changing it

Use the tool; it edits `pubspec.yaml` and `CHANGELOG.md` together:

```
python -I tool/bump_version.py show              # print the current version
python -I tool/bump_version.py patch             # 0.9.0+3 -> 0.9.1+4
python -I tool/bump_version.py minor --tag       # 0.9.1+4 -> 0.10.0+5 and tag v0.10.0
python -I tool/bump_version.py set 0.9.0+1       # exact (used once, to choose the starting point)
python -I tool/bump_version.py build             # same version, next build number
```

`--dry-run` shows the change without making it. `--tag` creates the git tag
`v<version>` on the current commit (it does not push).

## A release, step by step

1. Everything for the release is committed; `flutter analyze` and `flutter test` pass; `python -I tool/utf8_scan.py` is clean.
2. Run every pending SQL migration (see `remaining_tasks.md`); a release must never depend on SQL that has not been run.
3. Make sure **Unreleased** in `CHANGELOG.md` describes what changed, in plain words a technician understands.
4. `python -I tool/bump_version.py minor --tag` (or `patch`, `build`).
5. Commit `pubspec.yaml` and `CHANGELOG.md` with the message `Release v<version>`.
6. Build (release build and signing come next; see `remaining_tasks.md`).
7. Push the commit and the tag only when you are ready for others to see them.

## Rules

- The **build number only goes up**. Never reuse or lower it, even for a different version name.
- One version name = one set of code. If you change code after tagging, make a new version (or at least a new build number and note it in the changelog).
- Database changes are versioned by their migration file names, not by the app version. A migration is run once, in order, and the app version that needs it is written in its changelog line.
- Do not type the version into screens or text; read it from `appVersionProvider`.
