# Security Policy and Threat Model

NyxChat is a serverless, end-to-end encrypted messenger for Android. This
document states precisely what the protocol protects, what it does not,
and how to report problems. Claims here are limited to what the code in
`lib/core/crypto` and `lib/core/network` implements and what the test suite
exercises.

## Reporting a vulnerability

Open a private security advisory on GitHub or email the maintainer listed in
`pubspec.yaml`. Please include the protocol version (`v3`), a reproduction
and the impact. We aim to acknowledge within 7 days.

## Cryptographic design (protocol v3)

| Layer | Mechanism | Purpose |
|---|---|---|
| Identity | X25519 identity key, Ed25519 signing key, Kyber-768 KEM key. NyxChat ID = `NC-` + 64 bits of SHA-256 over both classical public keys. | Long-term identity; handle is bound to keys and checked by every peer. |
| Direct-link handshake | X3DH-style: dh1 = X25519(IK, IK'), dh2/dh3 = ephemeral x identity, dh4 = ephemeral x ephemeral, plus a Kyber-768 encapsulation. Both hellos are Ed25519-signed over a length-prefixed transcript; the responder signs the initiator's nonce. | Mutual authentication, forward secrecy, post-quantum confidentiality, replay resistance. |
| Link encryption | AES-256-GCM per direction, keys from HKDF(master), 64-bit counter nonce bound as AAD. | Hides all metadata (message ids, timestamps, receipts, file chunks) from LAN observers; rejects replay and reordering. |
| Pairwise messages | Signal Double Ratchet: HKDF root chain, HMAC symmetric chains, per-message AES-256-GCM keys derived by HKDF, header bound as AAD together with sender and recipient ids. Up to 256 skipped keys per chain, 1024 stored. State changes commit only after authentication succeeds. Sessions are persisted in the encrypted database. | Per-message forward secrecy and post-compromise security across any transport, including multi-hop mesh relays. |
| Asynchronous sessions | X3DH-lite against pinned identity + Kyber keys: dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B), kem = Kyber(KPK_B). The recipient's identity key acts as its first ratchet key. Simultaneous initiation is resolved deterministically by id order. | Sending to a contact who is not directly connected (store-and-forward over the mesh). |
| Groups | Sender Keys: per-member symmetric chain + Ed25519 signing key, distributed through pairwise ratchet sessions; each message is AES-256-GCM encrypted and signed. Chains rotate on membership change. | O(1) encryption per group message, sender authenticity, forward secrecy, exclusion of removed members. |
| Files | Random 256-bit key and 64-bit nonce prefix delivered inside the ratchet; each 32 KiB chunk is AES-256-GCM sealed with nonce = prefix || index and AAD = file id, index, total; SHA-256 of the plaintext verified on completion. | Resumable, integrity-checked transfers without ratcheting per chunk. |
| Key pinning | Trust-on-first-use with explicit key-change refusal until the user accepts; 60-digit safety numbers (5120 SHA-256 iterations over both fingerprints); QR/text contact cards pin and verify out of band. | Detects man-in-the-middle and impersonation; enables in-person verification. |
| Storage | Hive boxes encrypted with AES-256-CBC under a random master key held in Android keystore-backed secure storage. Optional password: master key wrapped with AES-256-GCM under Argon2id (32 MiB, 2 iterations, 2 lanes). Legacy PBKDF2 wraps are migrated on next unlock. Duress password opens a separate decoy profile with its own keys and can destroy the real profile. Wipe after 5 failed attempts. | Data at rest; coercion resistance; loss-limiting. |
| Mesh | Packets addressed by SHA-256(id); payload is a full envelope; TTL, 24 h expiry, dedup by id; routes learned from recorded paths; Spray-and-Wait with L = 3; random forwarding jitter. | Delay-tolerant delivery through untrusted relays that cannot read, alter or re-address traffic. |

## What an attacker can and cannot do

**Passive network observer (Wi-Fi or Bluetooth):**
- Cannot read message contents, metadata inside the link (ids, timestamps, receipts, reactions) or file contents.
- Can see that two devices exchange traffic, packet sizes and timing, and the mDNS/BLE advertisement containing the NyxChat ID and display name unless stealth mode is enabled. Cover traffic reduces, but does not eliminate, timing analysis.

**Active network attacker (MITM on first contact):**
- Cannot complete a handshake as a known contact: the pinned keys do not match and the link is refused until the user accepts a key change after comparing safety numbers.
- On true first contact without an out-of-band card, TOFU applies: the attacker could substitute keys once. Verification (safety number or contact card) closes this window.

**Mesh relay (untrusted intermediate device):**
- Cannot read, forge, or re-address envelopes (sender and recipient are bound into the AEAD).
- Can drop, delay or replay packets (replays are rejected by the ratchet). Can observe hashed addresses and therefore link that "hash A talks to hash B".

**Device seizure (locked, password enabled):**
- Must brute-force the password through Argon2id. Wipe-after-5-attempts applies to the app UI only; an attacker with a disk image is limited by the KDF cost and password strength.
- Without a password the master key is in the keystore; protection then relies on the Android lock screen and hardware key attestation.

**Compromise of a device's long-term keys:**
- Past direct-link sessions stay confidential (ephemeral DH in every handshake). Past asynchronous sessions are protected from the first reply onward (Double Ratchet healing). Future traffic is compromised until the victim rotates identity (panic wipe + new identity) and contacts re-verify.

## Known limitations

1. **Kyber implementation.** `package:post_quantum` implements CRYSTALS-Kyber round 3, not the final FIPS 203 ML-KEM encoding, and is an unaudited pure-Dart library. It is always combined with X25519; a Kyber break alone does not compromise sessions.
2. **Legacy handles.** Identities created before v3 keep an ID derived from 32 bits of the X25519 key. Peers verify the binding, but two such handles can collide; security still rests on the pinned full keys.
3. **Mesh metadata.** Hashed addresses are stable, so relays can correlate traffic between the same pair over time.
4. **BLE transport.** The peripheral role is implemented natively for Android; iOS is not supported. Throughput is limited by GATT MTU.
5. **DHT.** Experimental; announcements are signed but there is no NAT traversal and no Sybil resistance.
6. **Internet relay / Tor.** Present in the code base as an optional module but not wired into the UI in this release.
7. **No formal verification or third-party audit** has been performed. The protocol follows published designs (X3DH, Double Ratchet, Sender Keys) and is covered by unit tests, but it is an implementation by a small team.

## Reproducing the security tests

```
flutter test test/crypto
```

covers the Double Ratchet (ordering, skipped keys, tampering, replay,
persistence), the handshake (signature and nonce checks, id binding, key
agreement), the secure channel (replay, tamper), Kyber round trips, sender
keys (rotation, signature, replay), session management (async bootstrap,
collision resolution, reset) and trust-store behaviour.