## 5. Transports and Delivery

### 5.1 Private discovery

Every device announces itself over multicast DNS (service `_nyxchat._tcp`, random instance name per launch) and in its BLE scan response. In private mode the announcement is a Bloom filter [27] of the presence tokens (Section 4.8) that each pinned contact expects from the device in the current slot: 128 bits with three positions in the 24 bytes available in a BLE scan response, 512 bits in a TXT record. A stranger sees bits that change every 15 minutes and carry no identity; a contact computes the token it expects for the current and adjacent slots, tests the filter and, on a hit, dials the device. A false positive (about 2% per stranger with ten contacts on BLE) merely causes a handshake that fails harmlessly. In public mode, which users enable to meet new people, the handle and name are announced as before. To avoid two simultaneous links, the device with the smaller handle dials first, and both sides keep the link dialled by the smaller handle if duplicates arise.

### 5.2 Bluetooth LE mesh

Standard Flutter libraries provide only the central role, which is why two instances of the previous version could never find each other. NyxChat ships a native Android GATT server that advertises the service UUID with the beacon in the scan response and exposes a write characteristic for inbound chunks and a notify characteristic for outbound ones; the beacon is rotated every slot. Links form in either role, exchange the handle and a per-launch random relay id, negotiate an MTU up to 512 bytes and carry binary frames chunked with a two-byte header, reassembled under a 64 KiB cap.

### 5.3 Sealed-sender store-and-forward

A mesh packet (binary, 61-byte header) carries a random id, a recipient token, a reply token, a TTL of seven hops, a timestamp with 24-hour expiry, the relay ids traversed and a payload sealed under the pair's wrapping key. A node deduplicates by id, learns a route to the reply token through the neighbour that delivered the packet, forwards to the learned next hop when known and otherwise sprays up to three copies among current neighbours after a random delay, and offers stored packets to every new neighbour (Spray-and-Wait [8]). Whether a packet is "for me" is decided by the application, which maintains the tokens it currently listens on for every pinned contact and for the joined emergency channel. The destination answers with an ack addressed to the reply token; every relay that sees the ack purges the packet, so the store is bounded by outstanding traffic rather than by the expiry alone. A relay therefore observes, per epoch, that token X talks to token Y, and nothing else: no identities, no ratchet headers, no message sizes finer than the padding bucket. Wi-Fi Direct endpoints and direct TCP links forward the same packets, so a LAN bridges Bluetooth neighbourhoods.

### 5.4 Internet relays

When the user enables it, an envelope that cannot go directly or over the mesh is sealed for the pair and published to public Nostr relays [25] as a kind-1059 event [26] tagged with the recipient's daily token and signed with a throwaway key; the recipient subscribes to its tokens for the current and previous day. Relays keep such events for days, so this provides worldwide store-and-forward with no infrastructure operated by the project; the connection can be routed through Tor via Orbot. Relays learn tokens, sizes and timing, never identities or content.

### 5.5 Emergency channel

A location-scoped broadcast lets people who share no contacts communicate in a crisis. The device computes its geohash cell (about 5 km at five characters) locally, derives a channel key from the cell name, and listens on a rotating channel token. Messages are AES-256-GCM sealed under the channel key and relayed by every node with TTL 10; channel packets are delivered to every member and still forwarded. The sender is anonymous unless it chooses to include a name or position.

### 5.6 Delivery state machine

Sending a message tries, in order: the authenticated TCP link, the mesh (if at least one neighbour is present and the contact's keys are pinned), the internet relay (if enabled and connected), and otherwise the persistent outbox, which stores inner messages in plaintext inside the encrypted database and re-encrypts on every attempt with exponential backoff. Receivers acknowledge text and files end to end inside the ratchet; mesh acks additionally drive the delivered state for messages that travelled through relays.

## 6. Implementation

NyxChat is written in Dart with Flutter for the user interface, Kotlin for the BLE peripheral and location access, and C for ML-KEM. Table 1 summarises the code base.

| Component | Lines |
|---|---|
| Cryptographic core and protocol formats (`core/crypto`, `core/protocol`) | 3,677 |
| Networking, mesh, relays and storage (`core/network`, `core/mesh`, `core/relay`, `core/storage`) | 5,161 |
| Services (identity, lock, settings, backup, messaging engine, discovery) | 2,737 |
| User interface | 3,234 |
| Native Android (Kotlin: GATT server, location, window security) and the ML-KEM wrapper (C) | 517 (+ vendored PQClean) |
| Tests and benchmarks (119 tests: unit, fuzz, integration, relay; simulator) | 4,128 |
Table: Size of the NyxChat code base (protocol v4).

Several engineering details are security-relevant. Every parser goes through a small hardening layer that converts type and range errors into `FormatException` and enforces field types, key lengths and size limits (1 MiB per link frame, 512 KiB per envelope, 64 KiB per mesh packet and per BLE reassembly); a socket that exceeds its buffer is closed. Frames on a link are processed strictly in order even though socket events arrive asynchronously, because link decryption is stateful. ML-KEM runs on the calling isolate through FFI (a few milliseconds), whereas Argon2id runs on a background isolate. Secret buffers are zeroed after use where the runtime allows. Continuous integration builds the native library, runs analysis and the full test suite, and builds a debug APK on every push; release builds publish SHA-256 checksums.