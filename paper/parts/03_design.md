## 4. Cryptographic Design

### 4.1 Identity

Each device generates an X25519 identity key IK, an Ed25519 signing key SK and a Kyber-768 key KPK, and keeps the private halves in Android's keystore-backed secure storage. The user-visible handle is `NC-` followed by 64 bits of SHA-256 over a domain string and both classical public keys. Every peer re-derives the handle from the keys it is shown and refuses a handshake if they disagree, so a handle cannot be claimed without the corresponding keys. The handle is only a routing label; trust decisions use the full pinned keys (Section 4.9).

### 4.2 Direct-link handshake

When two devices connect over TCP they exchange one signed hello each. The initiator sends its identity, signing and Kyber public keys, an ephemeral X25519 key EK, a 128-bit nonce, its listening port and capability list; the responder answers with the same fields plus the initiator's nonce and a Kyber ciphertext computed against the initiator's KPK. Each hello is signed over a length-prefixed transcript of all its fields with the sender's Ed25519 key. Both sides then compute

dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B), dh3 = X25519(IK_A, EK_B), dh4 = X25519(EK_A, EK_B),

master = HKDF(salt = nonce_A || nonce_B, ikm = 0xFF^32 || dh1 || dh2 || dh3 || dh4 || kem, info = "NyxChat-Handshake-v3").

The structure is that of X3DH [1] with the responder's ephemeral key playing the role of a signed pre-key, extended with the KEM secret as in PQXDH [4]. dh1 authenticates both identity keys; dh2 and dh3 give forward secrecy against later compromise of either identity key; dh4 gives forward secrecy against compromise of both; the KEM secret protects recorded transcripts against a future quantum adversary. The responder's signature over the initiator's nonce prevents replay of a captured response, and the responder checks the initiator's keys against its pin store *before* revealing its own hello, so a key-changed or impersonating initiator learns nothing beyond the refusal. Kyber is mandatory in protocol v3; there is no downgrade path.

From the master secret both sides derive two link keys (Section 4.3) and a ratchet root. The initiator is always the Double Ratchet's "Alice" with the responder's EK as the initial remote ratchet key, and sends a *session-open* message immediately so the responder, who has no sending chain until it receives one message, can reply. If a session already exists from an earlier meeting it is kept; the new handshake only refreshes the link keys.

### 4.3 Link layer

After the handshake every frame on the link is sealed with AES-256-GCM under a per-direction key derived from the master secret, using a 64-bit counter as nonce and as associated data. The receiver requires the counter to equal the next expected value, so replayed, reordered or dropped-and-reinjected frames terminate the link. Everything above this layer, including pings, receipts, reactions, group updates and file chunks, is therefore hidden from a LAN observer, who sees two signed hellos followed by opaque lines. This is deliberately separate from end-to-end encryption: the link protects one hop against a local observer, the envelope protects the message against everyone on the path.

### 4.4 Envelopes and inner messages

An *inner message* is a small JSON document with a type (text, file descriptor, reaction, receipt, sender-key distribution, group update, session-open), an id, a timestamp and a body. An *envelope* wraps its ciphertext with the sender and recipient handles, the kind of encryption (pairwise ratchet or group sender key), the ratchet header, and optionally a session-init block (Section 4.6). The associated data of every envelope is a length-prefixed encoding of a domain string, the sender handle, the recipient handle and the kind, so a relay that changes any of them causes authentication to fail. Envelopes are what transports carry; the transports never see inner messages.

### 4.5 Pairwise sessions

Pairwise conversations use the Double Ratchet [2] as specified: the root KDF is HKDF-SHA256 with the root key as salt and the DH output as input; the chain KDF derives the message key as HMAC(ck, 0x01) and the next chain key as HMAC(ck, 0x02); the message key is expanded by HKDF into an AES-256 key and a 96-bit nonce; and the header (ratchet public key, previous chain length, message number) is concatenated to the envelope's associated data. Up to 256 messages can be skipped per chain and 1024 skipped keys are retained, which is what allows delivery through relays that reorder or duplicate. Two implementation choices matter for robustness: every decrypt operates on a working copy of the state and commits only after the tag verifies, so a forged or corrupted envelope can never desynchronise a session; and sessions are serialised to the encrypted database after every step, so forward secrecy does not reset to identity-derived keys on every launch.

### 4.6 Asynchronous sessions and collisions

A user may write to a contact who is not connected. Without a server there is no pre-key bundle to fetch, but the sender holds the contact's pinned IK and KPK. The sender generates an ephemeral EK and computes dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B) and a Kyber encapsulation to KPK_B; the ratchet root is HKDF over 0xFF^32 || dh1 || dh2 || kem. The recipient's identity key doubles as its initial ratchet key and is replaced by a fresh key at its first reply, after which the session is indistinguishable from one created by a handshake. The ephemeral key and Kyber ciphertext are attached to every envelope as a session-init block until the sender has decrypted a reply; a recipient that already accepted that block ignores repeats.

Two contacts may initiate towards each other before either message arrives. NyxChat resolves this deterministically: on receiving an init block while itself holding a pending initiation, the device with the lexicographically smaller handle ignores the incoming block, and the other adopts the incoming session, verified by decrypting the first message, and resends its own queued messages through it. If a device lost its session state (for example after a database reset) it fails to decrypt, and on a direct link both sides re-derive the session from the current handshake after a rate-limited *session-reset* frame; messages that had been sent but not acknowledged as delivered are re-queued.

### 4.7 Groups

Each member owns, per group, a random 256-bit chain key and an Ed25519 signing key, distributed to the other members inside pairwise ratchet envelopes. A group message is encrypted with a key derived from the chain (HMAC step, HKDF expansion, AES-256-GCM with the envelope's associated data) and signed over the group id, iteration counter, ciphertext and associated data. Receivers verify the signature under the sender's distributed key before deriving message keys, retain up to 512 skipped keys for out-of-order delivery, and reject iterations they have already consumed. Membership updates travel through pairwise sessions and are accepted only from current members; whenever a member leaves or is removed, every remaining member rotates its chain and redistributes it, so the departed member cannot read later traffic, and receivers discard the departed member's chain.

### 4.8 Files

Ratcheting once per chunk would be wasteful and would make resumption awkward. Instead the sender hashes the file, generates a random 256-bit key and 64-bit nonce prefix, and sends a descriptor inside the ratchet. Each 32 KiB chunk is sealed with AES-256-GCM under nonce = prefix || chunk index and associated data (file id, index, total), so chunks verify independently, may arrive in any order, and a transfer can resume after a disconnect. The receiver writes chunks into a sparse temporary file and compares the SHA-256 of the result with the descriptor before exposing it.

### 4.9 Trust management

Keys are pinned on first contact. A later handshake presenting different keys for the same handle is refused, the user is told that the safety number changed, and the link stays blocked until they accept. A safety number is derived from both fingerprints by 5120 iterations of SHA-256, rendered as twelve groups of five digits; it is identical on both phones if no attacker is in the middle. A contact card, shown as a QR code and copyable as text, carries only public keys; importing one pins and marks the contact as verified without any network contact, which closes the trust-on-first-use window entirely for users who meet in person.

### 4.10 Data at rest and coercion

All local state, including ratchet sessions, sender keys, pinned keys and the outbox, lives in AES-256 encrypted database boxes under a random master key held in secure storage. With the optional lock, the master key is wrapped with AES-256-GCM under a key derived by Argon2id [15] (32 MiB, two passes, two lanes); installations that used PBKDF2 are transparently re-wrapped on their next unlock. A duress password, verified through its own Argon2id hash, opens a second profile with independent identity keys and database boxes and may be configured to destroy the real profile first; five failed attempts wipe everything. Identity keys never enter the database, so a corrupted database is deleted and recreated without forcing re-onboarding.