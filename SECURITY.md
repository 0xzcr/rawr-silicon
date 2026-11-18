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
| Network | Downloads happen only when you press Set up, over HTTPS (TLS 1.2+, no downgrade on redirect): Whisky and its Wine engine from Whisky's GitHub releases, and Steam's installer from Valve's CDN. No telemetry, no analytics, no update pings. |
| Dependencies | Whisky 3.10.2 and Wine engine 4.8.3 are pinned; their SHA-256 hashes are inside the signed app, and a mismatched download is refused. Whisky must also pass `codesign` with an Apple-issued Developer ID certificate of Whisky's developer (team `Z7JS58F8U3`) before it is copied in. |
| Privileges | Runs as you. The only administrator prompt is macOS's own, to install Apple's Rosetta 2 if it's missing; Vaelos never sees the password. Whisky goes to /Applications (or ~/Applications if that isn't writable). Vaelos writes to its own `~/Library/Application Support/Vaelos Silicon`, Whisky's engine folder, and its own Whisky bottle. |
| Microphone | Used only during CS2 voice chat and the mic test you start. Recordings stay on your Mac (`mic-test.wav`, overwritten each test). |

## Verify a download

```sh
shasum -a 256 Vaelos-Silicon.dmg          # must match SHA256SUMS on the release
hdiutil verify Vaelos-Silicon.dmg
codesign --verify --strict --verbose=2 "/Applications/Vaelos Silicon.app"
codesign -d --entitlements - "/Applications/Vaelos Silicon.app"   # only audio-input
```

## Known limits

- Whisky itself is Developer ID signed but not notarized by its developer; Vaelos checks the signature instead.
- The Steam installer is checked to be a Windows executable, but its Authenticode signature isn't verified
  on macOS yet.
- Anti-cheat: VAC on Wine isn't officially supported by Valve. The app never uses `-insecure`.
