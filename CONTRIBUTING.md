# Contributing to NyxChat

Thank you for your interest in contributing to NyxChat! Every contribution helps make decentralized, private communication more accessible.

## Getting Started

### Prerequisites

- **Flutter SDK** >= 3.32.0
- **Dart SDK** >= 3.11.0
- **Android Studio** or **VS Code** with Flutter extension
- An Android device or emulator (API 21+)

### Setup

```bash
git clone https://github.com/harshitt13/NyxChat.git
cd NyxChat
flutter pub get
flutter run
```

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/harshitt13/NyxChat/issues) to avoid duplicates.
2. Open a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Device info (model, Android version)
   - Logs if available (`flutter run` output or `adb logcat`)

### Suggesting Features

Open an issue with the **feature request** label. Include:
- What problem does it solve?
- How should it work from a user perspective?
- Any relevant technical considerations (crypto, networking, privacy)

### Submitting Code

1. **Fork** the repository.
2. Create a **feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following the guidelines below.
4. **Test** on a real Android device (BLE and Wi-Fi Direct features cannot be tested on emulators).
5. Commit with clear, descriptive messages:
   ```
   fix: correct AES-GCM MAC extraction in AppLockService
   feat: add post-quantum key encapsulation (ML-KEM)
   ```
6. Push and open a **Pull Request** against `main`.

## Code Guidelines

### Architecture

NyxChat follows a layered architecture:

- **`lib/core/`** — Low-level primitives (crypto, networking, mesh, privacy, storage)
- **`lib/models/`** — Data models (immutable where possible)
- **`lib/services/`** — Business logic layer (ChangeNotifier-based)
- **`lib/screens/`** — UI layer (stateful widgets consuming Providers)
- **`lib/theme/`** — Visual styling

### Conventions

- Use `ChangeNotifier` + `Provider` for state management.
- Run crypto-heavy operations on **Dart Isolates** — never block the UI thread.
- All network data must be **encrypted end-to-end** before leaving the device.
- Never log sensitive data (private keys, plaintext messages, passwords).
- Use `debugPrint()` instead of `print()` for debug output.
- Prefer `final` and `const` wherever possible.

### Security Rules

NyxChat is a security-critical application. All contributions must follow these rules:

1. **No plaintext secrets on the wire.** All messages must be encrypted with AES-256-GCM before transmission.
2. **No certificate pinning bypasses.** The `badCertificateCallback` must only accept self-signed certs for `.onion` domains.
3. **No weakening of key derivation.** PBKDF2 iterations must remain >= 100,000.
4. **Forward secrecy is mandatory.** DM sessions must use the Double Ratchet (`SessionKeyManager`).
5. **Panic wipe must be irreversible.** The wipe path must delete Hive files, secure storage keys, and identity data.
6. **No analytics, telemetry, or tracking.** NyxChat collects zero data.
7. **Database operations must be self-healing.** Hive box access must handle decryption failures gracefully (delete corrupted files, recreate fresh boxes) and guard against null boxes.
8. **Identity must be recoverable.** Crypto keys and display name are backed up to `FlutterSecureStorage` so identity can be reconstructed if local databases are reset.

### Dart Style

- Follow the [Effective Dart](https://dart.dev/effective-dart) guidelines.
- Run `flutter analyze` before submitting — zero warnings expected.
- Format with `dart format`.

## Pull Request Checklist

- [ ] Code compiles with `flutter build apk --debug`
- [ ] `flutter analyze` reports no issues
- [ ] `dart format .` produces no changes
- [ ] Tested on a real Android device
- [ ] No sensitive data in logs or comments
- [ ] Commit messages follow conventional format (`feat:`, `fix:`, `docs:`, `refactor:`)
- [ ] README updated if new features are user-facing

## Areas for Contribution

Here are areas where contributions are especially welcome:

| Area | Description |
|------|-------------|
| **Post-Quantum Crypto** | Implementing ML-KEM (Kyber) hybrid key exchange |
| **iOS Support** | Porting and testing on iOS (BLE, permissions) |
| **Group Encryption** | Upgrading group messages from static ECDH to Sender Keys or MLS for forward secrecy |
| **Testing** | Unit tests for crypto, integration tests for mesh routing |
| **Desktop Support** | Porting to Linux/Windows/macOS (TCP & mDNS work, BLE needs adaptation) |
| **Offline Sync** | Improving store-and-forward reliability for delayed mesh delivery |
| **Accessibility** | Screen reader support, high contrast mode |
| **Localization** | Translating the UI to other languages |

## License

By contributing, you agree that your contributions will be licensed under the [GNU General Public License v3.0](LICENSE).

---

Questions? Open a [Discussion](https://github.com/harshitt13/NyxChat/discussions) or reach out via an issue.
