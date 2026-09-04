# Security Policy and Threat Model

NyxChat is a serverless, end-to-end encrypted messenger for Android. This
document states precisely what protocol v4 protects, what it does not, and
how to report problems. Claims are limited to what the code in
`lib/core/crypto`, `lib/core/network`, `lib/core/mesh` and `lib/core/relay`
implements and what the automated tests exercise. Tamarin models of the
handshake and asynchronous initiation are in `formal/`.

## Reporting a vulnerability

Open a private security advisory on GitHub or email the maintainer listed in
`pubspec.yaml`. Include the protocol version (`v4`), a reproduction and the
impact. We aim to acknowledge within 7 days.

## Cryptographic design (protocol v4)

| Layer | Mechanism | Purpose |
|---|---|---|
| Identity | X25519 identity key, Ed25519 signing key, ML-KEM-768 key. Handle = `NC-` + 64 bits of SHA-256 over both classical public keys. Rotation via a statement signed by both the old and the new signing key. | Long-term identity bound to the handle; rotation without a key-change alarm. |
| Post-quantum KEM | ML-KEM-768 as specified in FIPS 203 (final, Aug 2024), PQClean "clean" C99 reference implementation, constant-time by construction, verified against NIST ACVP vectors. RNG: `getrandom(2)` on Android/Linux, `CryptGenRandom` on Windows. Not a FIPS 140-3 validated module. Public keys failing the FIPS 203 modulus check and secret keys failing the hash check are rejected. | Confidentiality against future quantum adversaries, always combined with X25519. |
| Direct-link handshake | X3DH-style: dh1 = X25519(IK, IK'), dh2/dh3 = ephemeral x identity, dh4 = ephemeral x ephemeral, plus an ML-KEM-768 encapsulation to a *per-handshake* KEM key of the initiator; master = HKDF over nonces and all five secrets. Both hellos are Ed25519-signed over a length-prefixed transcript; the responder also signs the initiator's nonce and the SHA-256 of the initiator's entire hello; the responder refuses initiator nonces it has seen recently. Pinned keys are checked before the responder reveals its hello. | Mutual authentication with no identity misbinding, forward secrecy including post-quantum forward secrecy, replay resistance on both sides, no downgrade path. |
| Link encryption | AES-256-GCM per direction, keys from HKDF(master), 64-bit counter nonce bound as AAD, strict ordering. | Hides every frame (ids, timestamps, receipts, reactions, chunks) from LAN observers; rejects replay and reordering. |
| Pairwise messages | Signal Double Ratchet (HKDF root chain, HMAC symmetric chains, per-message AES-256-GCM keys from HKDF, header + sender + recipient handles as AAD; 256 skipped keys per chain, 1024 stored; commit-on-success; persisted). Plaintext padded to a power-of-two bucket (256 B min). | Per-message forward secrecy and post-compromise security over any carrier; length hiding. |
| Asynchronous sessions | X3DH-lite against pinned keys: dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B), kem = ML-KEM-768 to a *one-time prekey* of the recipient (8-byte id in the init block; distinct HKDF label and the id as salt). Pools of 8 prekeys per contact travel as Ed25519-signed, time-stamped bundles inside the link encryption after every direct handshake (recipient-bound transcript, anything not newer than the bundle on file is refused); private halves live in an encrypted box, are wiped after the first successful decrypt and expire after 30 days. Last resort when no prekey is held: kem = ML-KEM(KPK_B), flagged on the session and in the contact screen; a recipient that no longer holds the named prekey answers with a signed notice bound to that initiation and the initiator restarts with the long-term key. Recipient's identity key is its first ratchet key; concurrent initiation resolved by handle order. | Messaging contacts that are not connected, without servers, with post-quantum forward secrecy from the first message whenever a prekey is available. |
| Pair keys | HKDF over the static X25519 agreement of two contacts' identity keys, with distinct labels for presence tokens (15-min slots, 8 B), mesh addresses (1-h epochs, 16 B), relay tokens (1-day epochs, 32 B) and the sealed-sender wrapper (AES-256-GCM, random nonce). Tokens include the recipient's handle. | Everything a contact must recognise and a stranger must not. |
| Private discovery | Beacons carry a Bloom filter (128 bits BLE / 512 bits mDNS, 3 positions) of per-contact presence tokens for the current slot; random mDNS service name per launch. Public mode (handle + name) is a user switch, on by default. | Strangers cannot learn that you run NyxChat, who you are, or track you across slots; contacts still find you. |
| Wi-Fi Aware links | NAN publish/subscribe carries the same beacon as BLE; a data path is requested only after the beacon matched a contact (or a public handle) on both sides; the NAN link is encrypted by the Wi-Fi stack under a random per-link passphrase exchanged in a NAN follow-up message (in the clear over the air); the ordinary authenticated handshake and AES-256-GCM link encryption run on top. | Same discovery privacy as BLE; the NAN cipher only adds defence in depth against passive listeners, all security rests on the handshake. |
| Mesh (sealed sender) | Binary packet: random id, recipient token, reply token, TTL 7, 24 h expiry, per-launch random relay ids, payload sealed for the pair. Dedup by id; routes learned from reply tokens and expiring with the epoch; Spray-and-Wait L = 3; acks purge relay stores; channel packets delivered and relayed. | Delivery through untrusted relays that cannot read, alter, re-address, or link endpoints across epochs. |
| Internet relays | Optional. Sealed envelope published as a Nostr kind-1059 event tagged with the recipient's daily token, signed with a throwaway key; recipient subscribes to its tokens; optional Tor (Orbot) proxy. | Worldwide store-and-forward with no infrastructure of our own; relays see tokens and timing only. |
| Groups | Sender Keys: per-member chain + Ed25519 signing key distributed through pairwise ratchets; padded, AES-256-GCM sealed and signed messages; 512 skipped keys; rotation on membership shrink. | O(1) group encryption, sender authenticity, forward secrecy, exclusion of removed members. |
| Files | Random 256-bit key and 64-bit nonce prefix inside the ratchet; each 32 KiB chunk AES-256-GCM sealed with nonce = prefix ‖ index and AAD = (file id, index, total); chunks over links or mesh (≤ 4 MiB), re-requested when missing; SHA-256 verified. | Resumable, integrity-checked transfers on any carrier. |
| Emergency channel | Channel key = HKDF over the geohash cell; rotating channel token per hour as the mesh address; payload AES-256-GCM under the channel key; anonymous unless the user adds a name or position. | Local broadcast without contacts; relays outside the cell cannot read it. |
| Trust | TOFU pinning; refused key changes until accepted; 60-digit safety numbers (5120 SHA-256 iterations); QR/text contact cards (display and camera scan); signed key transitions. | MITM/impersonation detection; in-person verification; smooth rotation. |
| Storage | AES-256 Hive boxes under a keystore-held master key; optional Argon2id-wrapped (32 MiB, 2 passes, 2 lanes) password with PBKDF2 migration; duress password opening a decoy profile with independent keys, optionally destroying the real one; wipe after 5 failures; encrypted backups (Argon2id + AES-256-GCM). | Data at rest, coercion resistance, recovery. |
## What an attacker can and cannot do

**Passive observer (Wi-Fi or Bluetooth):**
- Cannot read message contents, in-conversation metadata or file contents.
- In private discovery mode cannot tell that a device runs NyxChat, cannot learn its handle or name, and cannot track it across 15-minute slots. In public mode the handle and name are visible.
- Can see that two devices exchange traffic, packet size buckets and timing. Cover traffic reduces, but does not eliminate, timing analysis.

**Active network attacker (MITM on first contact):**
- Cannot complete a handshake as a known contact (pinned keys, signed transcript, nonce echo).
- On true first contact without a contact card, TOFU applies: one substitution window, closed by safety-number comparison or scanning a card.

**Mesh relay (untrusted intermediate device):**
- Cannot read, forge or re-address envelopes (sealed for the pair, AAD-bound) and cannot see identities or ratchet headers.
- Can link a recipient token to a reply token within one hour and count packets; cannot link across epochs. Can drop, delay or replay packets (replays are rejected end to end). Learns which packet ids were acknowledged.

**Public Nostr relay:**
- Sees daily tokens, event sizes and timing, and a throwaway key per event; cannot read content or learn identities. Can drop or delay.

**Device seizure (locked, password enabled):**
- Must brute-force the password through Argon2id from a disk image; the in-app attempt counter does not bound an offline attacker. Without a password, protection rests on the Android keystore and lock screen.
- Under coercion the duress password opens a decoy profile with its own keys and empty history; if configured, the real profile is destroyed first.

**Compromise of long-term keys:**
- Past direct-link sessions stay confidential (ephemeral X25519 keys and an ephemeral ML-KEM key in every handshake, so neither a classical nor a quantum adversary gains from a later key compromise). Asynchronous sessions started with a one-time prekey are protected from the first message (the recipient deleted the prekey's private half on use); a session that had to fall back to the long-term KEM key is protected from the first reply onward. Pair-derived keys (presence, mesh, relay tokens, sealed-sender wrapper) are static-DH based and are therefore exposed: an attacker with a victim's identity key can recognise the victim's beacons and unseal the *outer* wrapper of past mesh/relay traffic, but the inner envelope remains ratchet-protected. The victim should rotate keys (signed transition) and contacts re-verify.

## Known limitations

1. **No physical-device field measurements yet** for BLE, Wi-Fi Direct and Wi-Fi Aware; behaviour across Android vendors, throughput and battery are untested by the maintainers.
2. **Not a FIPS 140-3 module.** ML-KEM-768 is the PQClean reference code verified against ACVP vectors, compiled with the NDK; side-channel behaviour of the surrounding pure-Dart X25519/Ed25519/AES code has not been evaluated.
3. **Pair keys are static-DH derived** (see above): compromise of an identity key exposes token unlinkability and the outer wrapper retroactively.
4. **Bloom beacons have false positives** (about 2% per stranger at 10 contacts on BLE); a false positive only causes a handshake attempt that fails harmlessly, but leaks that the scanner has *some* contact whose token collided.
5. **Group membership** is authenticated only to current members; any member can add anyone.
6. **Legacy v2 handles** (32 bits of key material) are still accepted; trust rests on pinned keys.
7. **Nostr relays** have size limits (48 KiB payload) and may require authentication (NIP-42, unsupported); the client falls back to other carriers.
8. **Formal models are not yet machine-checked** in this repository (Tamarin is not installed on the development machine); they are provided for review. Writing them already surfaced three protocol refinements that are now implemented: binding the responder's signature to the initiator's hello, a responder-side nonce cache, and rejecting stale initiation blocks from a lost collision (the loser announces the ephemeral it abandoned and the winner blacklists every init it ignored).
9. **No external audit.**
10. **Asynchronous sessions without a prekey are the weaker case.** A one-time prekey exists only for contacts met on a direct link since 3.2, and each initiation consumes one of eight; when none is left the session starts against the long-term KEM key and gains post-quantum forward secrecy only at the first reply. The contact screen shows this state. Unused prekeys are part of encrypted backups, so restoring a backup can bring back a private half the live device had already deleted: a session that used it is then only as confidential as that backup.

## Reproducing the security tests

```
bash tool/build_native.sh        # or pwsh tool/build_native.ps1 on Windows
flutter test test/crypto         # ratchet, handshake, ML-KEM KATs, sender keys, sessions, one-time prekeys, pair keys, beacons, mesh, key transition, trust, outbox
flutter test test/fuzz           # seeded fuzzing of every wire parser and the BLE reassembler
flutter test test/integration    # two/three full stacks: handshake, receipts, reconnect, reset, sealed mesh, groups, prekey bundles and mesh sessions with one-time prekeys
flutter test test/relay          # Nostr transport against an in-process mock relay
```