## 2. Background and Related Work

### 2.1 Secure messaging protocols

The Signal protocol consists of X3DH [1], an asynchronous key agreement in which an initiator combines Diffie-Hellman values between its identity and ephemeral keys and the recipient's identity and pre-keys, and the Double Ratchet [2], which derives a fresh message key for every message from a root chain advanced by Diffie-Hellman ratchet steps and symmetric chains advanced by a key derivation function. The combination provides forward secrecy and post-compromise security; its formal analysis is given by Cohn-Gordon et al. [3]. Signal's PQXDH [4] and Apple's PQ3 [18] add a post-quantum KEM (Kyber, standardised as ML-KEM in FIPS 203 [5]) to the initial agreement so that recorded traffic cannot be decrypted by a future quantum computer. Group messaging in WhatsApp and Signal uses Sender Keys [13]: each member distributes a symmetric chain and a signing key through pairwise sessions; Rösler et al. [14] analysed the resulting group security and the importance of authenticated membership changes. Unger et al. [23] survey the wider design space.

NyxChat adopts these designs rather than inventing new cryptography. What differs is the environment: there is no server to host pre-keys, so asynchronous agreement must use long-term keys the sender already holds; and there is no trusted transport, so the ratchet must tolerate out-of-order and duplicated delivery through relays.

### 2.2 Delay-tolerant networking

Delay-tolerant networking (DTN) [10] addresses networks without a contemporaneous end-to-end path. Epidemic routing [9] replicates every message to every encountered node and maximises delivery at the cost of bandwidth and storage. Spray-and-Wait [8] bounds replication: the source sprays L copies, and holders wait until they meet the destination. NyxChat's router combines Spray-and-Wait with routes learned from the paths recorded in packets, so that a node with a known next hop forwards a single copy.

### 2.3 Infrastructure-free messengers

Briar [11] routes messages over Bluetooth, Wi-Fi and Tor with its own Bramble transport protocol and pairwise handshakes; it targets contacts who have met in person and does not relay through strangers. Meshtastic [12] uses LoRa radios for long-range text with channel keys rather than per-user identities. Bridgefy [6] relayed through arbitrary phones but, as Albrecht et al. showed, its original protocol leaked social graphs, allowed message forgery and decryption by relays, and was vulnerable to a zip-bomb denial of service; Berty's Wesh [20] pursues a similar goal with IPFS-based primitives. Several BLE mesh chat applications released in 2025 initially transmitted messages without any identity binding and added authenticated handshakes only after external review. NyxChat's contribution relative to these systems is the combination of relay-through-strangers delivery with a protocol that gives relays nothing to read or forge, and with the same forward-secret ratchet used for direct links.

## 3. Threat Model

We consider an application running on two or more Android devices that may be connected over a shared Wi-Fi network, directly reachable over BLE, or connected only through a chain of intermediate NyxChat devices that are not trusted. We assume the cryptographic primitives (X25519 [17], Ed25519 [22], AES-256-GCM, HKDF [16], Argon2id [15]) are secure, and that Kyber-768 [21] may or may not be; the design must remain secure if either the classical or the post-quantum component holds.

Adversaries and their capabilities:

- **Passive observer** on the same Wi-Fi network or within Bluetooth range. Reads every byte transmitted.
- **Active network attacker** who can inject, modify, replay and drop traffic, including presenting itself as a peer during discovery.
- **Malicious relay**: a NyxChat device on the mesh path that runs modified software and may store, replay, alter or selectively drop packets, and colludes with other relays.
- **Device seizure**: physical access to a locked device, including a full disk image, with the ability to coerce the owner into entering a password.
- **Long-term key compromise** of one party at some point in time.

Security goals: confidentiality and integrity of message content and of in-conversation metadata (message ids, receipts, reactions, group membership) against all adversaries above; authentication of the peer's identity after first contact; forward secrecy and post-compromise security of conversations; unlinkability of transport-level metadata from a LAN observer beyond the fact that two devices communicate; confidentiality of data at rest under seizure, bounded by the password's entropy; and plausible deniability of the real profile under coercion.

Out of scope: malware on the endpoint, hardware side channels, denial of service by jamming, and a global adversary correlating traffic timing across the whole mesh. Mesh addressing uses stable hashes, so a relay can learn that two hashed identities communicate; we discuss this limitation in Section 8.