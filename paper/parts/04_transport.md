## 5. Transports and Delivery

### 5.1 Discovery and links

On a shared network, devices advertise `_nyxchat._tcp` through multicast DNS and dial each other; to avoid two simultaneous links between the same pair, the device with the smaller handle dials first and the other waits three seconds. If duplicate authenticated links still arise, both sides apply the same rule, keeping the link dialled by the smaller handle, so they never disagree about which link survives.

Over Bluetooth, standard Flutter libraries provide only the central role, which is why two instances of the previous version could never find each other. NyxChat ships a native Android GATT server that advertises the service UUID with the handle in the scan response and exposes a write characteristic for inbound chunks and a notify characteristic for outbound ones. Every device scans and advertises simultaneously, so a link can form in either role and one device may be central to some neighbours and peripheral to others. After a link forms, the handle is exchanged, the MTU is negotiated up to 512 bytes, and messages are chunked with a two-byte sequence and flag header.

### 5.2 Mesh routing

A mesh packet carries an envelope, a TTL of seven hops, a timestamp with 24-hour expiry, the SHA-256 hashes of the sender and recipient handles, and the list of relay hashes it has traversed. A node deduplicates by packet id, learns a route to the sender through the last relay listed, and delivers packets addressed to its own hash to the messaging layer. Packets for others are stored in a bounded queue and forwarded after a random delay of 0.2-2 seconds: to the learned next hop if one is known, otherwise as a spray of up to three copies among current neighbours. Whenever a new neighbour appears, up to three stored packets are offered to it, which is the "wait" phase of Spray-and-Wait [8]. Periodic beacons with TTL 3 refresh routes. Because the payload is an envelope, a relay that reads, edits or re-addresses a packet gains nothing and causes only an authentication failure at the destination.

### 5.3 Delivery state machine

Sending a message tries three paths in order: the authenticated TCP link if the peer is connected, the mesh if the peer's keys are pinned and at least one BLE link is up, and otherwise the persistent outbox. The outbox stores inner messages in plaintext inside the encrypted database and re-encrypts them on every attempt, so a session reset never strands ciphertext; group messages, whose sender-key envelopes remain decryptable until the next rotation, are stored as envelopes. Attempts back off exponentially from five seconds to ten minutes and are reset whenever a session is established or a session-open arrives. Receivers acknowledge text and files with an end-to-end receipt inside the ratchet, which drives the sent, delivered and read states shown to the user and, for groups, the per-member delivery lists.

### 5.4 Privacy controls

Stealth mode stops all advertising, scanning and multicast announcements while keeping existing links; cover traffic sends random-sized packets to random hashes at random intervals so that idle and active periods look alike to a nearby observer; and a screenshot-blocking window flag, notification content control and disappearing messages complete the picture.

## 6. Implementation

NyxChat is written in Dart with Flutter for the user interface and a small Kotlin component for the BLE peripheral. Table 1 summarises the code base. Cryptographic primitives come from `package:cryptography` (X25519, Ed25519, HKDF, HMAC, AES-GCM, Argon2id) and Kyber-768 from `package:post_quantum`, a pure-Dart implementation of the round-3 CRYSTALS-Kyber construction; the lattice arithmetic and Argon2id run on background isolates so that the interface stays responsive.

| Component | Dart lines |
|---|---|
| Cryptographic core and protocol formats (`core/crypto`, `core/protocol`) | 2,644 |
| Networking, mesh and storage (`core/network`, `core/mesh`, `core/storage`) | 3,692 |
| Services (identity, lock, settings, messaging engine, discovery) | 2,366 |
| User interface | 2,627 |
| Native Android BLE peripheral and window security (Kotlin) | 304 |
| Tests (43 unit tests, benchmark harness, mesh simulator) | 1,169 |
Table: Size of the NyxChat code base (protocol v3).

Several engineering details are security-relevant. Every parser enforces types, key lengths and size limits (1 MiB per link frame, 512 KiB per envelope, 64 KiB per mesh packet), and a socket that exceeds its buffer is closed. Frames on a link are processed strictly in order even though socket events arrive asynchronously, because link decryption is stateful. Secret buffers are zeroed after use where the runtime allows. The handshake, ratchet, sender keys, secure channel, session manager, trust store and outbox are exercised by 43 unit tests that include tampering, replay, out-of-order delivery across ratchet boundaries, forged signatures, nonce mismatch, key-change refusal, persistence round trips and the initiation-collision rule. Continuous integration runs analysis, tests and a debug build on every push.