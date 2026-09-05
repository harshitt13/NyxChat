# Changelog

## 3.2.0 (unreleased)

### Fixed
- Every screen except the conversation list rendered blank in 3.0/3.1
  release builds: the chat, peer and connection services were provided
  below the Navigator, so pushed routes could not find them. The providers
  now wrap the MaterialApp, and a widget test opens every screen on the
  real service graph to keep it that way.
- File transfers: chunks that overtook their descriptor were dropped until
  a 45-second re-request; concurrent chunk writes collided on the open
  file; mesh forward timers fired into disposed routers. All three were
  found by the new media integration tests.
- Session recovery deduplicated only the most recently accepted
  initiation, so a replayed copy of an older initiation could rebuild a
  session the peer no longer held (found by machine-checking the
  collision model). Every accepted initiation ephemeral is now remembered
  and the abandoned-init announcement survives a recovery.

### Verification
- The Tamarin models are machine-checked (Tamarin 1.12.0 / Maude 3.5.1);
  outcomes and timings are in formal/RESULTS.md and a GitHub Actions
  workflow re-proves them on every change to formal/.
- Widget tests boot the real services and drive the main flows (send a
  text, toggle every setting, create a group, join an emergency channel),
  plus theme and right-to-left locale checks; loopback integration tests
  now cover voice notes, images with thumbnails, prekey exchange and
  Wi-Fi Aware wiring.

- Voice notes: hold the microphone in the composer to record (release
  to send, slide left or tap the X to cancel) with elapsed time and a
  level meter; mono AAC-LC at 16 kHz / 32 kbps in an .m4a container,
  capped at five minutes. Notes travel as ordinary encrypted file
  transfers (direct link, mesh, relay) with the duration in the
  descriptor, and play inline with seek, remaining time and one-at-a-time
  playback that continues while you scroll. New `voice` message type;
  the chat list shows a microphone and the length, notifications say
  "Voice message". RECORD_AUDIO permission added.
- Image previews: photos carry a 256 px JPEG thumbnail (under 10 KiB,
  EXIF orientation applied, all other EXIF stripped) inside the
  end-to-end encrypted file descriptor, so the recipient sees the
  picture with a progress overlay before the chunks finish; the full
  image fades in when complete and opens in a full-screen viewer with
  pinch zoom. Received images without a preview are thumbnailed locally.
  The cap keeps every image descriptor inside the 16 KiB padding bucket.
- Hostile media hints (non-JPEG or oversized previews, bad durations)
  are dropped without rejecting the file.

### Appearance and languages
- Light theme and a theme-mode setting (dark, light or system; dark stays
  the default). Colours are a `ThemeExtension` (`NyxColors`) resolved per
  theme; the light palette keeps every text colour at WCAG AA contrast, QR
  codes stay dark-on-white, and the status/navigation bar icons follow the
  active theme.
- Localisation of the whole UI (Flutter `gen_l10n`, `lib/l10n/*.arb`):
  English, Hindi, Spanish, French, German, Portuguese, Arabic, Chinese,
  Russian and Indonesian, with ICU plurals and locale-aware dates. Arabic
  mirrors the layout (directional paddings, bubble corners, quote bars).
  A language picker in Settings (native names) or follow the device
  language. Notification and foreground-service texts are translated too;
  the English system messages stored in chat history are rendered in the
  UI language at display time, so storage and protocol are unchanged.
- Theme mode and language are kept in the platform secure storage so the
  lock and onboarding screens honour them before the database is opened;
  a panic wipe resets them.

### Post-quantum
- Asynchronous (mesh and relay) sessions gain post-quantum forward
  secrecy from the first message: right after every direct handshake each
  side hands the other a pool of eight one-time ML-KEM-768 prekeys as a
  signed, time-stamped bundle (new link frame `prekeys`, new encrypted box
  `prekeys`); an initiation encapsulates to one of them (init block field
  `pk`, distinct KDF label) and the recipient wipes the private half once
  the first message decrypts. Without a prekey the initiation falls back
  to the long-term KEM key and the contact screen says so; a recipient
  that lost its prekeys answers with a signed notice (new envelope kind
  `ct`) and the initiator restarts with the long-term key. The Tamarin
  model of asynchronous initiation covers prekeys
  (`async_pq_forward_secrecy`).

### Transports
- Wi-Fi Aware (NAN) on Android 8+: the same rotating discovery beacon as
  over BLE is published as the `nyxchat` Aware service and subscribed for;
  a data path is built only to beacons that match a contact (or a public
  handle), and the regular authenticated TCP handshake then runs over the
  link-local IPv6 link. Settings switch "Use Wi-Fi Aware" (on where
  supported), off in stealth mode; state shown in Settings and in mesh
  diagnostics. The TCP server now listens dual-stack so link-local IPv6
  peers can connect.

## 3.1.0 (2026-09) - protocol v4

Not compatible with 3.0.x peers (mesh packet format, beacon format and
KEM changed). Re-pair once after upgrading.

### Post-quantum
- Kyber replaced by ML-KEM-768 (FIPS 203) from PQClean, compiled from C
  and bound through dart:ffi on Android and on the host for tests. The
  pure-Dart round-3 Kyber dependency is gone.
- The handshake encapsulates to a fresh per-handshake KEM key
  (post-quantum forward secrecy); the responder's signature now also covers
  the hash of the initiator's hello (no identity misbinding) and the
  responder refuses replayed initiator nonces. Hello version is 4.
- Simultaneous asynchronous initiation: the loser announces its abandoned
  ephemeral (`ab` on envelopes) and the winner blacklists ignored inits, so
  a delayed copy of the abandoned initiation can no longer replace the
  surviving session.

### Privacy
- Private discovery: mDNS and BLE beacons carry a Bloom filter of
  per-contact presence tokens for the current 15-minute slot instead of
  the handle and name. Only pinned contacts can recognise you; a
  "visible to everyone" switch keeps the old behaviour for meeting new
  people. Service names are random per launch.
- Sealed sender on the mesh: binary packet format with rotating recipient
  and reply tokens derived per contact pair and epoch, per-launch random
  relay ids, and the envelope wrapped under a pair key. Relays see only
  opaque bytes and short-lived tokens.
- Length hiding: every plaintext is padded to a power-of-two bucket
  (256 B minimum) before end-to-end encryption.
- Mesh acknowledgements: destinations answer with an ack; every relay
  that sees it purges the packet from its store.

### Delivery
- Files travel over the mesh (up to 4 MiB) with per-chunk requests for
  anything that went missing; larger files still need a direct link.
- Internet path with no servers of our own: sealed envelopes can be posted
  to public Nostr relays (kind 1059, rotating daily tokens), optionally
  through Tor via Orbot. Off by default.
- Wi-Fi Direct (Nearby Connections) endpoints now forward mesh packets.
- Emergency broadcast: a one-tap, location-scoped (geohash cell) anonymous
  channel over the mesh, with optional name and position.

### Identity
- Signed key-transition statements: rotate all keys and let contacts merge
  the new identity without a key-change alarm.
- Encrypted backup and restore (Argon2id + AES-256-GCM) of keys,
  contacts, sessions and messages.
- QR code scanning of contact cards with the camera.

### Robustness
- End-to-end integration tests: two and three complete stacks over
  loopback TCP and a simulated mesh (handshake, session open, receipts,
  reconnect, session reset, sealed mesh delivery with ack, groups with
  removal).
- Seeded fuzz tests for every wire parser; parsers now fail only with
  FormatException; BLE reassembly capped at 64 KiB.
- Tamarin models of the handshake and asynchronous initiation (formal/).
- Release workflow publishes SHA-256 checksums of the APK and AAB.

### App
- Conversation and message search, image thumbnails, relay settings,
  visibility toggle, emergency screen, backup screen.
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