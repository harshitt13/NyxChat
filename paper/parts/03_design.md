## 4. Cryptographic Design

### 4.1 Identity

Each device generates an X25519 identity key IK, an Ed25519 signing key SK and an ML-KEM-768 key KPK, and keeps the private halves in Android's keystore-backed secure storage. The user-visible handle is `NC-` followed by 64 bits of SHA-256 over a domain string and both classical public keys. Every peer re-derives the handle from the keys it is shown and refuses a handshake if they disagree. The handle is only a routing label; trust decisions use the full pinned keys (Section 4.10).

### 4.2 Post-quantum KEM

NyxChat uses ML-KEM-768 as standardised in FIPS 203 [5], compiled from PQClean's "clean" C99 reference implementation [24] into a small shared library and called through `dart:ffi`. The implementation is constant-time by construction; the binding adds the FIPS 203 input checks (public-key modulus check, secret-key hash check) that the reference leaves to callers, draws randomness from `getrandom(2)` on Android and verifies its return, and is tested against NIST ACVP vectors for key generation, encapsulation, decapsulation and implicit rejection. The KEM is never used alone: every secret it produces is combined with X25519 outputs through HKDF, so a flaw in either component leaves the other's security intact.

### 4.3 Direct-link handshake

When two devices connect over TCP they exchange one signed hello each. The initiator sends its identity, signing and KEM public keys, an ephemeral X25519 key EK, a fresh per-handshake ML-KEM public key, a 128-bit nonce, its listening port and capability list; the responder answers with the same fields plus the initiator's nonce, an ML-KEM ciphertext computed against the initiator's *ephemeral* KEM key, and the SHA-256 hash of the initiator's entire hello. Each hello is signed over a length-prefixed transcript of all its fields. Both sides then compute

dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B), dh3 = X25519(IK_A, EK_B), dh4 = X25519(EK_A, EK_B),

master = HKDF(salt = nonce_A || nonce_B, ikm = 0xFF^32 || dh1 || dh2 || dh3 || dh4 || kem, info = "NyxChat-Handshake-v3").

The structure is that of X3DH [1] with the responder's ephemeral key playing the role of a signed pre-key, extended with the KEM secret as in PQXDH [4]. dh1 authenticates both identity keys; dh2 and dh3 give forward secrecy against later compromise of either identity key; dh4 against compromise of both; the KEM secret, encapsulated to a key that lives only for this handshake, protects recorded transcripts against a future quantum adversary even if the long-term KEM key is later compromised. The responder's signature over the initiator's nonce and hello hash prevents replay of a captured response and binds the response to exactly one initiator, which rules out the identity-misbinding attack that the Tamarin model of an earlier draft exposed; the responder additionally refuses initiator nonces seen recently, and checks the initiator's keys against its pin store before revealing its own hello. There is no downgrade path. From the master secret both sides derive two link keys and a ratchet root; the initiator is the Double Ratchet's "Alice" and sends a session-open message immediately so the responder can reply.

### 4.4 Link layer

After the handshake every frame on the link is sealed with AES-256-GCM under a per-direction key derived from the master secret, using a 64-bit counter as nonce and as associated data. Replayed, reordered or dropped-and-reinjected frames terminate the link. Everything above this layer, including pings, receipts, reactions, group updates and file chunks, is hidden from a LAN observer.

### 4.5 Envelopes, inner messages and padding

An *inner message* is a small JSON document with a type (text, file descriptor, reaction, receipt, sender-key distribution, group update, session-open, chunk request, key transition), an id, a timestamp and a body. Before encryption it is padded to the next power-of-two bucket of at least 256 bytes with a length prefix, so ciphertext length reveals only the bucket. An *envelope* wraps the ciphertext with the sender and recipient handles, the kind of encryption (pairwise ratchet or group sender key), the ratchet header, and optionally a session-init block. The associated data binds a domain string, the sender handle, the recipient handle and the kind, so an envelope cannot be re-addressed.

### 4.6 Pairwise sessions

Pairwise conversations use the Double Ratchet [2] as specified: HKDF-SHA256 root KDF, HMAC-SHA256 chain KDF, per-message AES-256-GCM keys expanded by HKDF, header authenticated together with the envelope's associated data. Up to 256 messages can be skipped per chain and 1024 skipped keys are retained, which is what allows delivery through relays that reorder or duplicate. Every decrypt operates on a working copy and commits only after the tag verifies; sessions are serialised to the encrypted database after every step; a peer ratchet key that is a low-order point is rejected.

### 4.7 Asynchronous sessions and collisions

A user may write to a contact who is not connected. The sender holds the contact's pinned IK and KPK, generates an ephemeral EK and computes dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B) and an ML-KEM encapsulation to KPK_B; the ratchet root is HKDF over 0xFF^32 || dh1 || dh2 || kem. The recipient's identity key doubles as its initial ratchet key and is replaced at its first reply. The ephemeral key and KEM ciphertext ride in every envelope until the sender has decrypted a reply. If both contacts initiate before either message arrives, the device with the lexicographically smaller handle ignores the incoming init and the other adopts the incoming session after decrypting its first message, then resends its queued messages. Two guards keep a late copy of the abandoned initiation from displacing the session that survived: the winner remembers every init it ignored, and the loser names its abandoned ephemeral on each message (authenticated as associated data of the AEAD, so relays can neither strip nor forge it) until the winner has demonstrably heard from it, so the winner blacklists it no later than the moment it stops waiting for a reply. The Tamarin model of the collision found both orderings before release. On a direct link, an undecryptable envelope triggers a rate-limited session-reset frame and both sides re-derive from the current handshake; messages not yet acknowledged as delivered are re-queued.

### 4.8 Pair keys: presence, addressing and sealing

The novelty of the v4 protocol is that everything an untrusted party can observe on the infrastructure-free paths is a function of a secret shared only by the two contacts. From the static agreement s = X25519(IK_A, IK_B), both contacts derive with HKDF and distinct labels a discovery key, a mesh key, a relay key and a wrapping key. From these:

- the *presence token* T_disc(slot, X) = HMAC(k_disc, "disc" || slot || X)[0..8) that X shows to the other contact in a 15-minute slot;
- the *mesh address* T_mesh(epoch, R) = HMAC(k_mesh, "mesh" || epoch || R)[0..16) under which R receives in a one-hour epoch;
- the *relay address* T_relay(day, R) = HMAC(k_relay, "nostr" || day || R), a 32-byte token per day;
- the *sealed-sender wrapper* AES-256-GCM(k_wrap, nonce, envelope) with a random nonce.

Including the recipient's handle in the token input makes the two directions of a pair distinct. Tokens rotate with the slot, epoch or day, so nothing observed in one period links to another. Section 5 describes how beacons and mesh packets use them.

### 4.9 Groups, files, identity rotation, backup

Groups use Sender Keys [13]: each member owns per group a chain key and an Ed25519 signing key, distributed through pairwise ratchet envelopes; each message is padded, encrypted under the chain and signed over group id, iteration, ciphertext and associated data; up to 512 skipped keys are retained; chains rotate whenever membership shrinks, and receivers discard the departed member's chain. Files are described inside the ratchet (random key, nonce prefix, SHA-256, chunk count) and sent as independently authenticated 32 KiB chunks over whatever carrier is available; the receiver periodically requests missing chunks and verifies the hash before exposing the file. An identity is rotated by publishing a *key transition*, a statement naming the old and new handles and the new public keys, signed by both the old and the new signing key and valid for 180 days; a contact that has the old key pinned verifies both signatures and the new handle's binding, merges the conversation, session and group memberships, and inherits the verified status, so rotation raises no alarm. The whole profile (keys, pinned contacts, sessions, group keys, messages, settings) can be exported as an Argon2id- and AES-256-GCM-protected backup and restored on another device.

### 4.10 Trust management and data at rest

Keys are pinned on first contact; a later handshake presenting different keys for the same handle is refused until the user accepts after comparing 60-digit safety numbers (5120 iterations of SHA-256 over both fingerprints). Contact cards, shown as QR codes and scannable with the camera, pin and verify a contact without any network contact. Local state lives in AES-256 encrypted database boxes under a keystore-held master key; with the optional lock the master key is wrapped under an Argon2id-derived key (32 MiB, two passes); a duress password opens a second profile with independent identity keys and may destroy the real one first; five failed attempts wipe everything.