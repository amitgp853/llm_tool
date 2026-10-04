# firebase_live_check

Not published. A small Flutter web app that checks
`llm_tool_firebase_ai` against **real Gemini**, using tools made by
the published generator (including nested classes, lists and enums).

It runs four checks per backend:

| Check | Passes when |
|---|---|
| automatic: simple tool | Gemini calls `getWeather` and the Dart function runs |
| automatic: nested classes, lists, enum (approved) | `bookFlight` runs with the right passengers, ages, bags and cabin, after confirmation |
| automatic: declined confirmation does not run | Gemini calls `deleteFile`, the user declines, and the function does **not** run |
| manual: respondTo | `getWeather` runs through `toFunctionDeclarations()` + `respondTo()` |

## Run it

1. **Firebase project.** In the [Firebase console](https://console.firebase.google.com),
   create a project (or use one), open **AI Logic**, click **Get started** and
   enable the **Gemini Developer API** (it has a free tier).
   The optional Vertex AI run (`agentPlatform` in firebase_ai) needs the
   pay-as-you-go **Blaze** plan.
2. **Tools**, once per machine:
   ```sh
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. **Connect this app** to your project. This replaces
   `lib/firebase_options.dart`, which is a placeholder in the repo:
   ```sh
   cd firebase_live_check
   flutterfire configure --platforms=web
   ```
4. **Run it** and click **Run (Gemini Developer API)**:
   ```sh
   flutter run -d chrome
   ```
   Results appear in the app and in the terminal (`OK` / `FAIL` per check).

Each run sends about 8 small requests.

## Troubleshooting

- **`Firebase App Check token is invalid`**: App Check is enforced for
  Firebase AI Logic in your project (the setup wizard can turn it on).
  firebase_ai sends an App Check token automatically, and this test app has
  no App Check provider, so the token is rejected. For a test project, open
  **App Check → APIs → Firebase AI Logic** and switch it from *Enforced* to
  *Unenforced* (monitoring). Changes take a few minutes to apply.
- **`This model ... is no longer available to new users`**: Google retires
  model versions for new projects. Use the model the error suggests in
  `modelName` (`lib/checks.dart`).

## After running

- If a check is **inconclusive** (e.g. Gemini answered without calling the
  tool), run it again: model behavior varies slightly between runs.
- `flutterfire configure` writes your project's settings into
  `lib/firebase_options.dart`. Firebase web settings aren't secret, but to
  keep them out of the repo, don't commit that change:
  `git restore lib/firebase_options.dart`.
- Change the model in `lib/checks.dart` (`modelName`) to test another one.
