# Security

## Reporting

Report vulnerabilities privately through GitHub: **Security → Report a vulnerability** on this repository.
Please don't open a public issue for anything exploitable.

## What you're installing

| Item | Status |
|---|---|
| Code signature | Ad-hoc, with the **hardened runtime** (no JIT, no unsigned memory, no DYLD or library-validation exceptions). The only entitlement is microphone input. |
| Notarization | **Not yet**: it needs a paid Apple Developer ID. macOS will warn on first launch; allow it in System Settings → Privacy & Security → Open Anyway. The build supports Developer ID signing and notarization (`SIGN_IDENTITY`, `NOTARY_PROFILE`). |
| Integrity | Every release publishes `SHA256SUMS`. The DMG is read-only and compressed (UDZO), so it can't be changed in place. |
| Code sealing | The scripts and the Windows mic recorder are inside the signed bundle; editing any of them breaks `codesign --verify`. |
| Network | The app makes one download, during Setup: Steam's installer from Valve's CDN over HTTPS (TLS 1.2+, no downgrade on redirect). No telemetry, no analytics, no update pings. |
| Privileges | Runs as you; never asks for an administrator password. Writes only to `~/Library/Application Support/Vaelos Silicon` and its own Whisky bottle. |
| Microphone | Used only during CS2 voice chat and the mic test you start. Recordings stay on your Mac (`mic-test.wav`, overwritten each test). |

## Verify a download

```sh
shasum -a 256 Vaelos-Silicon.dmg          # must match SHA256SUMS on the release
hdiutil verify Vaelos-Silicon.dmg
codesign --verify --strict --verbose=2 "/Applications/Vaelos Silicon.app"
codesign -d --entitlements - "/Applications/Vaelos Silicon.app"   # only audio-input
```

## Known limits

- The Steam installer is checked to be a Windows executable, but its Authenticode signature isn't verified
  on macOS yet.
- Anti-cheat: VAC on Wine isn't officially supported by Valve. The app never uses `-insecure`.
