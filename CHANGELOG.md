# Changelog

## 3.0.0 (2026-09)

Protocol v3. Not backward compatible with 2.x peers.

### Security
- Replaced the previous ratchet with a correct Signal Double Ratchet
  (root/chain KDFs, skipped keys, out-of-order delivery, commit-on-success,
  persisted sessions). The 2.x implementation desynchronised after the first
  DH step and silently displayed ciphertext when decryption failed.
- New mutually authenticated handshake: Ed25519-signed hellos, X3DH-style
  key agreement (four DH values) plus Kyber-768, nonce echo against replay,
  NyxChat ID bound to keys. 2.x hellos were unsigned.
- Fixed Kyber-768: the KEM library expects the module rank (3), not 768;
  every 2.x encapsulation threw and fell back to classical-only silently.
- Link-layer encryption (AES-256-GCM, counter nonces) on every direct
  connection; 2.x sent all metadata in cleartext.
- Key pinning (trust-on-first-use) with refused key changes, safety
  numbers and QR/text contact cards.
- Group messaging moved to Sender Keys with signatures and rotation;
  2.x used static ECDH per pair with no forward secrecy.
- Files: per-chunk authenticated encryption with resume and hash check.
- App lock: Argon2id (with transparent migration from PBKDF2), duress
  password with an independent decoy profile, persistent attempt counter.
- Input validation and size limits on every wire format; frame limits and
  strict in-order processing on sockets.
- DHT announcements are signed and id-bound.

### Networking
- Native Android BLE peripheral (GATT server + advertising). 2.x could only
  scan, so two NyxChat devices never discovered each other over Bluetooth.
- Bidirectional BLE links in either GATT role, MTU negotiation, chunking.
- Messages actually travel over the mesh: envelopes are carried in mesh
  packets, delivered to the router callback, and decrypted like any other.
- Persistent outbox with exponential backoff; delivery and read receipts;
  session-reset recovery; deterministic handling of simultaneous links.
- Stealth mode (no advertising or scanning) and cover traffic.

### App
- Contact verification screen, group info screen, security screen,
  mesh diagnostics, disappearing messages per conversation, reply quotes,
  mute, screenshot-blocking toggle, notifications.
- Composition root with proper lifecycle (lock, unlock, decoy, panic wipe).

### Tooling
- 40+ unit tests for the cryptographic core and session logic.
- CI: analyze, test, debug APK.
- `benchmark/`: crypto micro-benchmarks and a delivery-ratio simulator built on the real router.
- `paper/`: research paper (Markdown source, generated DOCX and LaTeX).