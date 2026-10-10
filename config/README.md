# Environment configuration

Values here are injected at build time with `--dart-define-from-file`. They are
read by `lib/core/config/app_config.dart`, which throws if a required key is
missing rather than falling back to a default. A misconfigured build therefore
fails at launch instead of silently talking to the wrong backend.

## Why the Supabase URL differs per file

Networking differs by execution environment:

| File | Used by | Supabase URL | Why |
|---|---|---|---|
| `dev.json` | The app on an Android emulator | `http://10.0.2.2:54321` | `10.0.2.2` is the emulator's alias for the host machine's loopback. `127.0.0.1` inside the emulator resolves to the emulator itself. |
| `local.json` | The app on web or desktop | `http://127.0.0.1:54321` | Runs on the host, where Supabase is genuinely on loopback. |
| `test.json` | Integration tests on the host Dart VM | `http://127.0.0.1:54321` | Same reason. |

## Local stack

Start the stack with Mailpit included; it captures the verification emails
that Supabase Auth sends with `enable_confirmations = true`:

```powershell
npx supabase start -x studio,realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor
```

Then provision the local church. This applies every migration and runs
`supabase/seed.sql`, and it **wipes local data**:

```powershell
npx supabase db reset
```

> **Slice 8 (ADR-022, ADR-023, ADR-024), Migrations 022 to 027.** The
> church ADMIN role is retired: `admin@discipletrack.local` holds COORDINATOR
> only, and `superadmin@discipletrack.local` is the platform Super Admin.
> Every Discipler, every Leader included, opens all ten lessons, both tiers,
> as their own (Home, Lessons); a Disciple's My Journey opens only their
> reached lessons.

The seed creates one church and its Coordinator, plus a separate platform
Super Admin with no church membership:

| | |
|---|---|
| Church | Liberty Bible Baptist Church - Gensan |
| Coordinator email | `admin@discipletrack.local` (Dev Admin; the name is kept, the role is COORDINATOR only) |
| Super Admin email | `superadmin@discipletrack.local` (Dev Super Admin; no church) |
| Password (both) | `dev-password-123` |
| Join code | `7QK4MZP2XR` |
| Mailpit (verification emails) | http://127.0.0.1:54324 |

Register a new account in the app, read its 6-digit code from Mailpit, verify,
enter the join code, and approve the request while signed in as the
Coordinator (`admin@`). The Super Admin cannot approve requests.

The seed also builds one D Group, "Young Adults A", through the real
controlled operations. Every account below is ACTIVE with onboarding complete
and uses the password `dev-password-123`:

| Email | Name | Role | What to look at |
|---|---|---|---|
| `superadmin@discipletrack.local` | Dev Super Admin | Platform Super Admin, no church membership (ADR-022) | Opens straight into the Platform area, never Join Church or Welcome; the church listed with its counts, join code and Coordinator (Dev Admin); no members, groups or lessons anywhere |
| `admin@discipletrack.local` | Dev Admin | Coordinator only (ADMIN retired, ADR-022), not in a group; the founder, so no Welcome | Approves membership requests; views and copies the join code on Profile, Church information (cannot change it); closes the initial setup period and appoints Paolo from D Groups; Home figures, including 7 active discipleships; any Disciple's detail by deep link |
| `leader@discipletrack.local` | Lea Santos | Leader of Young Adults A, and its Discipler like every Leader (ADR-020) | Journey with My Disciples (Felix); My D Group roster with Manage members; every Disciple's detail in the group; recording on a Discipler's behalf; Home Lessons with all ten open, See all titled Lessons (ADR-024) |
| `discipler@discipletrack.local` | Dino Reyes | Existing Discipler of Diana, Daniel, Ella and Rosa | My Disciples with four rows; Record a meeting with the choose-Disciple sheet; Home Lessons with all ten open (ADR-024) |
| `disciple1@discipletrack.local` | Diana Cruz | Disciple of Dino | Lesson 1 completed and locked (Lesson 2 already has meetings, so no Undo); Lesson 2 in progress with 3 recorded absences in a row |
| `disciple2@discipletrack.local` | Daniel Bautista | Disciple of Dino | Lesson 1 in progress with 7 counted meetings, ready for Dino to mark completed; one duplicate meeting voided |
| `disciple3@discipletrack.local` | Ella Navarro | Disciple of Dino | Paired, no counted meeting; removed from one of Daniel's meetings where she was listed by mistake |
| `discipler2@discipletrack.local` | Grace Lim | Existing Discipler of Hana and Paolo | My Disciples with two rows; cannot see Dino's Disciples |
| `disciple5@discipletrack.local` | Hana Torres | Disciple of Grace | Present, Excused, then Late (recorded by Lea), with notes; Lesson 1 just marked completed by Grace, so Undo is available |
| `disciple4@discipletrack.local` | Felix Ramos | Disciple of Lea, no meeting yet | A Disciple whose Discipler is the Leader |
| `member@discipletrack.local` | Mara Villanueva | Approved, in no D Group | Listed by Add Members; no Journey in the dock; out of scope for everyone's progress |
| `newcomer@discipletrack.local` | Nina Aquino | Added to Young Adults A, Needs setup | Home says her Leader will set up her role; Lea sees "Set up" on her row |
| `disciple6@discipletrack.local` | Paolo Mendoza | Disciple of Grace, Lessons 1 to 5 completed | Eligible to disciple, not appointed: the Coordinator sees him under Eligible to disciple |
| `disciple7@discipletrack.local` | Rosa Domingo | Disciple of Dino and appointed Discipler | Both My Journey and My Disciples (none paired yet); Lessons 1 to 5 locked against undo; on Home her journey (Lesson 6 now, 7 to 10 locked) and, apart from it, Lessons with all ten open (ADR-024) |
| `leader2@discipletrack.local` | Ramon Garcia | Leader (and Discipler) of Men of Faith | Cannot see or act on Young Adults A |
| `disciple8@discipletrack.local` | Tomas Villa | Disciple in Men of Faith, not paired | "Not paired yet" on My Journey; out of scope for Lea and her Disciplers |

Meetings are dated over the last 60 days relative to the reset, so dates move
with each `db reset`. Every meeting is recorded through
`record_discipleship_meeting()`, completions through `complete_lesson()` and
voids through `void_discipleship_meeting()` and `void_meeting_participant()`,
with each account impersonated, so every seeded state is one the app could
have produced. The seed is for looking at the app by hand; integration tests
never read it.

### Lesson content (Slice 7)

`db reset` then runs `supabase/seed_curriculum.sql`, which publishes the
Journey curriculum at the METADATA level through `publish_curriculum()`:
titles, themes, topics, section headings, scripture references and the
Training Module titles. No lesson wording or answers exist in the repository
(ADR-019). The SQL is generated from `supabase/curriculum/journey-metadata.json`;
after editing the JSON, regenerate it:

```powershell
dart run tool/generate_curriculum_seed.dart
```

A unit test fails if the two drift. To publish to a real project, use
`tool/publish_curriculum.ps1`; a FULL publication requires `-LicenceReference`.

**Full lessons.** The church publishes Journey (ADR-019 decisions 11 and 15),
so the converted lessons and covers are in the repository under
`supabase/curriculum/full/`, and `db reset` publishes them after the metadata
seed (`publish_local.sql`, then `publish_covers.sql`). To rebuild them, the
source PDFs (and any supplied covers, `covers/lesson-01.png` and so on) go in
`docs/curriculum/source/`, which stays git-ignored:

```powershell
dart run tool/curriculum/build_definition.dart "<licence reference>"
dart run tool/curriculum/build_covers.dart
```

What to look at, by account (ADR-019 decision 6, ADR-023): Diana reads
Lessons 1 and 2, and Lessons 3 to 10 show locked; Paolo reads Lessons 1 to 6.
Disciplers read by relationship. In their own view Dino, Grace, Lea and Ramon
have no journey, so nothing opens. From a paired Disciple's detail every
lesson opens in both tiers, with answers: Dino for Diana, Daniel, Ella and
Rosa; Grace for Hana and Paolo; Lea for Felix. From another Disciple of her
group (Diana, say), Lea opens only that Disciple's reached lessons, without
answers. Rosa reads her own Lessons 1 to 6 without answers, fillable, and has
no paired Disciple yet. The Coordinator (Dev Admin) opens every lesson from D
Groups, Curriculum. Mara and Nina have no journey, so every lesson is locked.
The Super Admin reads no lesson.

Use a separate browser profile per account to walk through the roles side by
side.

The join code is local-development-only. Real deployments let bootstrap
generate one cryptographically; see `tool/bootstrap_church.ps1`.

### Super Admin on a hosted project (Slice 8)

No platform role exists until one is granted. After the migrations, grant
the operator's already registered account with `tool/grant_super_admin.ps1`
(psql in the service-role context, like the bootstrap tool). It calls
`private.grant_platform_role()`, which no app user can execute; the same tool
ends the role. From then on that account creates churches, with their
Coordinator, in the app's Platform area.

## The service-role key is deliberately not committed

Integration tests need it for setup and teardown, because it bypasses RLS in
order to seed and clean up rows that a normal user could never touch. That is
exactly why it does not live in this directory.

The local value is one of Supabase's published development defaults, identical
on every machine running `supabase start`, and it only reaches a Docker
container on localhost. So it is not a secret in substance. It is still kept
out of the repository for two practical reasons:

- GitHub's secret scanning cannot distinguish a published default from a live
  key, and blocks any push containing the pattern.
- A committed field named `SUPABASE_SERVICE_ROLE_KEY` is an invitation to paste
  a real one into it later. Service-role bypasses every policy, so it is the
  one key worth never getting into the habit of committing.

Set it from the running stack instead:

```powershell
# PowerShell
$env:SUPABASE_SERVICE_ROLE_KEY = (npx supabase status -o json | ConvertFrom-Json).SERVICE_ROLE_KEY
```

```bash
# bash
export SUPABASE_SERVICE_ROLE_KEY=$(npx supabase status -o json | jq -r .SERVICE_ROLE_KEY)
```

The tests read it from the environment at runtime and fail with that command
in the error message if it is absent.

## Are the other keys secrets?

No. The publishable key (formerly the anon key) is designed to ship inside
client applications. It maps to the `anon` Postgres role, so RLS governs
everything it can reach. Committing it is intentional so a fresh clone runs
without setup.

`config/prod.json` is gitignored and does not exist yet. Real project keys
never belong in this directory under version control.

## Usage

```
flutter run  -d chrome     --dart-define-from-file=config/local.json
flutter run  -d <emulator> --dart-define-from-file=config/dev.json
flutter test                                                  # unit + widget
flutter test --dart-define-from-file=config/test.json test/integration
```

The integration suite needs the stack running, `db reset` applied at least
once, Mailpit up, and the service-role key in the environment. Each test
creates and removes its own users and churches; only `bootstrap_test.dart`
reads the seeded church. `MAILPIT_URL` may be passed as a define if Mailpit is
not on port 54324.
