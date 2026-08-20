# motomap_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

cd "C:\Adrian\Flutter\MotoMap_Mobile_v1.0\MotoMap_Mobile_v1.0"
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

http://192.168.100.53:8080

## Android and ELM327 development

Bluetooth Classic is not available from the web build. Run MotoMap on a
physical Android phone to use the Kingbolen ELM327:

```powershell
flutter devices
flutter run -d <android-device-id>
```

Before opening MotoMap, plug the ELM327 into the motorcycle's diagnostic
adapter cable, turn the ignition on, and pair the adapter in Android Bluetooth
settings. Common clone-adapter PINs are `1234` and `0000`.

In MotoMap, open **Rides > Garage**, add or select the primary motorcycle, then
choose **Connect ELM327**. MotoMap stores the selected adapter with that
motorcycle in Supabase. It reconnects when the app starts/resumes, retries while
the process is alive, and monitors every five seconds during Ride Mode. Android
can suspend or terminate background apps; a future Companion Device foreground
service is required for guaranteed reconnect attempts while the UI process is
not running. Force-stopping an Android app always disables background work until
the user opens it again.

Setup now has three truthful stages: device selection, real ELM327/ECU
verification, and the result. Android GATT error 133 is retried automatically.
If Bluetooth connects but the ECU does not answer, MotoMap keeps those states
separate and offers **Retry ECU connection** or another-adapter selection.

The current diagnostic layer initializes the adapter, auto-detects the ECU
protocol, discovers supported Mode 01 PIDs, reads live values, reads and clears
generic Mode 03/04 trouble codes, stores diagnostic history in Supabase, and
calculates a transparent rule-based pre-ride health score. Available readings
depend on the motorcycle ECU and adapter cable. Clearing codes does not repair a
fault and can reset emissions/readiness information.

### iOS adapter compatibility

The Kingbolen Bluetooth Classic ELM327 is expected to work on Android only.
Apple permits generic iOS apps to communicate with Bluetooth Classic serial
accessories only when they are MFi-compatible. MotoMap's transport layer can be
extended with BLE or Wi-Fi for an iPhone-compatible ELM327 adapter.

## Supabase schema

The readable migration
`20260731184502_create_motorcycles_and_diagnostic_history.sql` creates the
user-owned motorcycle, diagnostic-session, sampled-reading, and trouble-code
tables. All four tables have row-level security enabled and restrict access to
the authenticated owner.

The follow-up migration
`20260731193254_add_profile_and_motorcycle_image_storage.sql` adds profile and
motorcycle image paths plus the public `profile-images` and
`motorcycle-images` buckets. Images are limited to JPEG, PNG, or WebP files up
to 5 MB. Public URLs can be displayed in the app, while storage policies allow
only the authenticated owner to upload, replace, or delete files inside their
user-ID folder.

Apply pending migrations from the project root with:

```powershell
npx supabase migration list --linked
npx supabase db push --linked
```

Do not paste and rerun an already-applied migration in the Supabase SQL Editor.
Doing so attempts to create the same tables again and causes errors such as
`relation "motorcycles" already exists`. Use `migration list` to verify the
local and remote migration versions instead.

`20260803192619_create_route_plans_and_gps_rides.sql` adds user-owned route
plans, GPS rides, ordered ride points, pause intervals, real/estimated fuel
labels, route and health scores, and an updated motorcycle usage summary. The
migration is applied to the linked Moto Map project. All four new tables have
RLS enabled with owner-scoped select, insert, update, and delete policies.

`20260820144002_fix_diagnostic_session_timestamps_and_route_removal.sql` uses
server time when a diagnostic is completed, preventing phone clock drift from
violating the diagnostic date constraint. The follow-up
`20260820151454_use_server_time_for_elm_connections.sql` makes the latest ELM
connection ordering server-authoritative. Both migrations are already applied
to the linked project.

## Motorcycle catalog and real ride history

The add-motorcycle form can search the official NHTSA vPIC JSON API for
motorcycle makes and year-specific models. Manual entry remains available for
models outside the catalog. MotoMap stores only the chosen catalog identifiers
and the rider's motorcycle record in Supabase.

Completed rides save compact ELM327 summaries alongside the raw diagnostic
samples. Distance is calculated from real ECU speed samples. Fuel consumed is
calculated only when the ECU supports OBD Mode 01 PID `5E` (engine fuel rate);
unsupported and missing values display as `N/A`. The motorcycle detail screen
shows lifetime recorded-ride totals and tappable ride/diagnostic history.

## Real maps, navigation, and ride recording

MotoMap now uses MapLibre with the OpenFreeMap Liberty vector style, user-
submitted Nominatim destination searches, and Valhalla motorcycle routing.
These components use OpenStreetMap road data and are open source/self-hostable.
The default public endpoints require no API key, but do not provide a commercial
SLA. Override them without changing source code by supplying these build-time
values:

```powershell
flutter run `
  --dart-define=MOTOMAP_MAP_STYLE_URL=https://your-map-style `
  --dart-define=MOTOMAP_GEOCODER_URL=https://your-nominatim `
  --dart-define=MOTOMAP_ROUTER_URL=https://your-valhalla
```

The smart prompt planner is deterministic and free: it extracts destination,
loop distance, duration, and road style, then asks Valhalla for a real route. It
does not claim to be a generative AI model and requires no paid AI key.

Saved plans can be swiped right to archive or left to permanently delete after
confirmation. The Archived view supports swipe-right restore. Deleting a saved
plan does not delete a completed ride that previously used it.

## Phase 3 pre-ride planning

Plan begins with four distinct choices: AI Ride Planner, Destination, Loop, and
Surprise. Each opens a focused question screen. Ride Now starts its clock only
when **Start ride** is pressed; Ride Later stores a real departure date/time.
The preview follows the Map, Details, Motorcycle, and optional Group tab flow:

- Map shows up to three real preference-based routes when meaningfully
  different routes are available and explains when no alternative exists.
- Details changes road character, avoids highways/tolls, searches ordered
  stops, and accepts a pinned map endpoint before rebuilding the real route.
- Motorcycle selects the bike, keeps ELM327 optional, distinguishes adapter
  and ECU state, and can run a saved pre-ride fault/danger check.
- Group creates or joins a private six-character uppercase code and reveals
  only joined rider/motorcycle preview data. Live group controls remain a
  separate in-ride phase.

Shared preview tables use RLS, explicit Data API grants, member-safe profile
snapshots, and a code-only join RPC. The migrations beginning with
`20260820154257_create_private_shared_ride_previews.sql` are already applied to
the linked Supabase project.

Ride recording starts only after the rider presses **Start ride**. It records
precise GPS points, elapsed time, moving time, manual pause intervals, route
progress, available ELM327 readings, and turn-by-turn voice guidance. Reaching
the routed endpoint after sufficient route progress ends and saves the ride
automatically; the rider can also pause, continue, or end manually. GPS points
are batched, and failed uploads are kept locally for retry when connectivity
returns. Force-quitting an app stops operating-system background execution.

Android MapLibre builds require Java 21 and NDK `28.1.13356709`. This workspace
uses the portable JDK at `C:\Adrian\Tools\temurin-jdk21\jdk-21.0.12+8`; Gradle
installed the required side-by-side NDK automatically. Android riders can start
with **While using the app** location permission; MotoMap's active-ride location
notification keeps the foreground recording service running. Android exposes
**Allow all the time** only through App Settings on many devices, so MotoMap no
longer blocks Start when that option is absent. iOS background availability
still depends on the granted system mode.

## Install the latest Android APK

The two source icons are organized under `assets/branding/`. MotoMap selects
the light or dark in-app icon from the phone appearance. Android launcher icon
resources also include normal and night-mode versions; a launcher may cache
its icon until it refreshes.

For the first installation, enable **Developer options** and **USB debugging**
on the Android phone, connect it by USB, and accept the phone's RSA prompt.
After any code change, build and install the latest update with one command:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\install_updated_apk.ps1
```

If more than one Android device is connected, add its Flutter device ID:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\install_updated_apk.ps1 -DeviceId YOUR_DEVICE_ID
```

The update preserves login and local app data because it installs over the
existing app. Do not uninstall first unless Android reports an incompatible
signature, because uninstalling removes the app's local data.
