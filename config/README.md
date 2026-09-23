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

The test reads it from the environment at runtime and fails with that command
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
flutter test --dart-define-from-file=config/test.json test/integration
```
