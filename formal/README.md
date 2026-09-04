# Formal models of the NyxChat handshake and asynchronous session initiation

> **Status: provided for review, not yet machine-checked in this repository.**
> Tamarin is not installed on the machine these models were written on, so
> none of the lemmas below has been run through `tamarin-prover`. The files
> were written by hand against Tamarin 1.8+ syntax using only builtin
> theories plus a small user-defined KEM signature. The first thing a
> reviewer should do is run them (see "Running") and record the outcome in
> this file.

| File | Contents |
|---|---|
| `nyxchat_v4_handshake.spthy` | Direct-link handshake (protocol v4): signed hellos with a per-handshake ML-KEM key, X3DH-style DH quadruple + KEM, initiator-hello hash in the response, responder nonce cache, master secret. 9 rules, 12 lemmas. |
| `nyxchat_v4_async.spthy` | Part 1: asynchronous (store-and-forward) initiation against pinned keys, both with a one-time ML-KEM prekey that the recipient registered over an authenticated link (consumed on use, private half deleted on acceptance) and with the long-term KEM key as the fallback. Part 2: the concurrent-initiation collision rule with two parties `'a' < 'b'`, including the `ignoredInitEphs` blacklist and the abandoned-init announcement (`ab`). 20 rules, 13 lemmas. |

Naming: `HelloMessage.protocolVersion` is 4 and the documentation calls the
protocol v4; the domain strings inside `lib/core/crypto` still read
`NyxChat-...-v3` (`NyxChat-Hello-v3`, `NyxChat-Handshake-v3`,
`NyxChat-Async-Session-v3`, `NyxChat-ID-v3`), while the one-time-prekey
variant added in 3.2 is labelled `NyxChat-Async-Prekey-Session-v4`. The
models mirror the code and use the labels as opaque public constants;
renaming them changes nothing in the proofs.

## Installing Tamarin

Tamarin needs the Maude rewriting engine (3.1 or newer; 3.2+ recommended)
on `PATH`, and GraphViz (`dot`) for the interactive GUI.

**macOS (Homebrew)**

```
brew install tamarin-prover/tap/tamarin-prover
```

This pulls in Maude and GraphViz.

**Linux**

1. Download the `tamarin-prover-<version>-linux64-ubuntu.tar.gz` release from
   <https://github.com/tamarin-prover/tamarin-prover/releases> and put the
   binary on `PATH`.
2. Install Maude 3.x: either the distribution package (`apt install maude`
   on Debian/Ubuntu, then check `maude --version` is >= 3.1) or the binary
   from <https://github.com/maude-lang/Maude/releases>; the executable must
   be named `maude` and be on `PATH`.
3. `apt install graphviz` (only for the GUI).

**Windows**: use WSL2 and follow the Linux steps. The Tamarin manual
(<https://tamarin-prover.com/manual/>) has the authoritative instructions.

Check the installation with `tamarin-prover test`.

## Running

From the repository root:

```
# Parse, type-check and report well-formedness warnings (no proving):
tamarin-prover formal/nyxchat_v4_handshake.spthy
tamarin-prover formal/nyxchat_v4_async.spthy

# Prove every lemma (the summary at the end lists verified / falsified):
tamarin-prover --prove formal/nyxchat_v4_handshake.spthy
tamarin-prover --prove formal/nyxchat_v4_async.spthy

# A single lemma:
tamarin-prover --prove=forward_secrecy formal/nyxchat_v4_handshake.spthy

# Interactive exploration (open http://127.0.0.1:3001):
tamarin-prover interactive formal/
```

Use `tamarin-prover --prove +RTS -N4 -RTS file.spthy` to run on 4 cores.
If a proof does not terminate within a few minutes, open the lemma in the
interactive mode and inspect the open goals; the DH + signature + KEM
combination here is small and should be in reach of the default `smart`
heuristic, but this has not been confirmed.

If the well-formedness check reports **partial deconstructions**, add a
`sources` lemma (see the manual, "Sources lemmas") for the offending term;
the most likely candidates are the nonce `nA` and the hash `ih` that the
responder echoes, or the ciphertext `c` in the async model. None is
included, because writing a correct sources lemma blind is more likely to
hide a problem than fix one.

## Expected outcome

Every lemma has a comment in the file stating what it means. The table
lists what the author expects Tamarin to report; a different result is
either a modelling error or a genuine finding and should be recorded.

| File | Lemma | Kind | Expected |
|---|---|---|---|
| handshake | `executable` | exists-trace | trace found |
| handshake | `secrecy_master` | all-traces | verified |
| handshake | `forward_secrecy` | all-traces | verified |
| handshake | `kem_only_secrecy` | all-traces | verified |
| handshake | `kem_only_forward_secrecy` | all-traces | verified (post-quantum forward secrecy, new with the per-handshake KEM key) |
| handshake | `dh_only_secrecy` | all-traces | verified |
| handshake | `mutual_auth_initiator` | all-traces | verified (full injective agreement, new with `ih`) |
| handshake | `mutual_auth_responder` | all-traces | verified (injective per responder, new with the nonce cache) |
| handshake | `replay_resistance` | all-traces | verified (follows from the `NonceCache` restriction) |
| handshake | `response_replay_resistance` | all-traces | verified |
| handshake | `hello_accepted_by_two_responders` | exists-trace | trace found (documents a harmless residual) |
| handshake | `key_agreement_consistency` | all-traces | verified |
| async | `async_executable` | exists-trace | trace found |
| async | `async_secrecy` | all-traces | verified |
| async | `async_secrecy_responder` | all-traces | verified |
| async | `async_kem_only_secrecy` | all-traces | verified |
| async | `async_dh_only_secrecy` | all-traces | verified |
| async | `async_agreement` | all-traces | verified (both the prekey and the fallback path) |
| async | `async_executable_opk` | exists-trace | trace found |
| async | `async_pq_forward_secrecy` | all-traces | verified (post-quantum forward secrecy of asynchronous sessions, new with one-time prekeys; every DH secret and every long-term key of both parties may leak after acceptance, B's long-term KEM key at any time) |
| async | `async_pq_forward_secrecy_initiator` | all-traces | verified (KEM-only: nothing but the used prekey's private half, which is deleted on use, protects the initiator's root) |
| async | `collision_executable` | exists-trace | trace found |
| async | `collision_consistency` | all-traces | verified (unconditional, recovery path included) |
| async | `abandoned_init_blacklisted` | all-traces | verified (the announcement reaches the winner before it settles) |
| async | `abandoned_init_never_adopted` | all-traces | verified (the stale-init trace no longer exists) |

## Mapping from model symbols to code

| Model | Code |
|---|---|
| `Register_Keys`, `!Ltk($A, ~ik, ~sk, ~kk)`, `!Pk(...)` | `KeyManager` (`lib/core/crypto/key_manager.dart`): X25519 identity key `~ik`, Ed25519 signing key `~sk`, long-term ML-KEM-768 key `~kk`. `!Pk` doubles as the peer's pinned record (`PinnedPeer` in `lib/core/storage/trust_store.dart`). |
| `h(<'NyxChat_ID_v3', pk(sk), 'g'^ik>)` | `NyxId.derive` / `NyxId.verify` (`lib/core/crypto/nyx_id.dart`). |
| `'g'^~ek`, `!Eph($A, ~ek)` | `CryptoUtils.newX25519KeyPair()` inside `Handshake.createInitiatorHello` / `Handshake.respond` / `Handshake.asyncInitiate`. |
| `kempk(~ekk)`, `!EphKem($A, ~ekk)` | `KyberKem.generateKeyPair()` in `Handshake.createInitiatorHello`; public half is `HelloMessage.ephemeralKemKey` (`ekpk`), private half `InitiatorState.ephemeralKem`, wiped after decapsulation. |
| `kempk(k)`, `kemenc(pk, r)`, `kemdec(ct, k)` | `KyberKem.generateKeyPair / encapsulate / decapsulate` (`lib/core/crypto/hybrid_key_exchange.dart`, ML-KEM-768 via PQClean); `r` is the KEM shared secret. |
| `tA = <'NyxChat_Hello_v3','role1',hA,$infoA,IK,SK,KPK,EK,nA,ekpk>` | `HelloMessage.transcriptFor(isResponse:false, ..., ephemeralKemKey: ekpk)` (`lib/core/crypto/handshake.dart`). `$infoA` stands for displayName, listeningPort and capabilities together; tuple order differs from the byte layout, which is irrelevant symbolically. |
| `tB = <'NyxChat_Hello_v3','role2',hB,$infoB,IK,SK,KPK,EK,nB,nA,kct,ih>` | `HelloMessage.transcriptFor(isResponse:true, peerNonce: nA, kyberCiphertext: kct, initiatorHelloHash: ih)`. |
| `ih = h(tA)` / `Eq(ih, h(tA))` | `sha256(initiatorHello.transcript())` in `Handshake.respond`; `constantTimeEquals(response.initiatorHelloHash, ownHash)` in `Handshake.completeInitiator`. |
| `kct = kemenc(ekpk, ~kem)` / `kemdec(kct, ~ekk)` | `KyberKem.encapsulate(initiatorHello.ephemeralKemKey)` in `respond`; `decapsulate(kct, state.ephemeralKem.privateKey)` in `completeInitiator`. |
| `sign(t, ~sk)` / `Eq(verify(sig, t, pk), true)` | `KeyManager.sign` / `CryptoUtils.ed25519Verify` in `Handshake._buildHello` / `Handshake._verifyHello`. |
| `Eq(hA, h(<...>))` | `NyxId.verify` call in `Handshake._verifyHello`. |
| `Neq($A, $B)` | the "peer claims our own identity" checks in `Handshake.respond` / `completeInitiator`. |
| `!Pk($A, ...)` premise of the receiving rules | `TrustStore.check` via `ConnectionManager._checkTrust` (`lib/core/network/connection_manager.dart`): presented keys must equal the pinned ones for that handle. |
| `RespNonce($B, nA)` + restriction `NonceCache` | `ConnectionManager._recentInitiatorNonces` (2048 entries) in `_handleIncoming`: a replayed initiator hello is refused before `Handshake.respond` runs. |
| pattern `~nA` inside `tB` in `I_Recv_Response` | `constantTimeEquals(response.peerNonce, state.nonce)` in `Handshake.completeInitiator`. |
| `master = kdf(<'NyxChat_Handshake_v3', nA, nB, dh1, dh2, dh3, dh4, kem>)` | `Handshake._derive`: HKDF(salt = nA‖nB, ikm = 0xFF*32‖dh1‖dh2‖dh3‖dh4‖kem, info). |
| `SessionKey`, `InitKey`, `RespKey` | `HandshakeResult.masterSecret`. The ratchet root and link keys are HKDF outputs of master and inherit its secrecy. |
| `Async_Initiate` | `SessionManager.encrypt` with no session and a `PinnedPeer` -> `Handshake.asyncInitiate` (encapsulates to the pinned long-term `KPK_B`), `DoubleRatchetSession.initAlice`, `SessionInitBlock(EK_A, kct)`. |
| `Async_Respond` | `SessionManager.decrypt` with an init block -> `Handshake.asyncRespond`, `DoubleRatchetSession.initBob`, decrypt-then-save. |
| `root = kdf(<'NyxChat_Async_Session_v3', dh1, dh2, kem>)` | `Handshake.asyncRoot` without a prekey id (the fallback). |
| `Register_Prekey`, `OPK($B, $A, ~opk)`, `OPKPub($A, $B, kempk(~opk))` | `PrekeyStore.replenish` (B generates ML-KEM-768 pairs for A, `lib/core/crypto/prekey_store.dart`) and `PrekeyExchange` (`lib/core/network/prekey_exchange.dart`): the Ed25519-signed, time-stamped `PrekeyBundle` (`lib/core/crypto/prekey_bundle.dart`) sent as a `prekeys` frame inside the link encryption after every handshake, verified by A against its pinned signing key of B (`PrekeyBundle.validate`, which also refuses anything not strictly newer than the bundle on file) and stored by `PrekeyStore.replacePeerBundle`. The 8-byte prekey id (truncated SHA-256 of the public key) stands in for `kempk(~opk)` itself in the model. |
| `Async_Initiate_OPK`, consumption of `OPKPub` | `SessionManager.encrypt` -> `PrekeyStore.takePeerPrekey` (removed from the pool before use, never re-admitted from a later bundle) -> `Handshake.asyncInitiate(prekeyId:, prekeyPublicKey:)`; the id travels as `SessionInitBlock.prekeyId` (`pk`). |
| `Async_Respond_OPK`, consumption of `OPK` | `SessionManager.decrypt` -> `PrekeyStore.findOwn` -> `Handshake.asyncRespond(prekeyId:, prekeyPrivateKey:)` -> `ratchet.decrypt` -> `PrekeyStore.deleteOwn` (only after the first message decrypted; the private half is wiped and removed from the encrypted `prekeys` box). |
| `root = kdf(<'NyxChat_Async_Prekey_Session_v4', pkOPK, dh1, dh2, kem>)` | `Handshake.asyncRoot` with a prekey id: HKDF(salt = prekey id, ikm = 0xFF*32‖dh1‖dh2‖kem, info = "NyxChat-Async-Prekey-Session-v4"). |
| `Reveal_OPK` | compromise of an unused prekey's private half (readable from the encrypted `prekeys` box, or from a backup) before it is used. |
| (no rule) an `init_opk` naming a prekey B does not hold | `UnknownPrekeyException` -> signed `PrekeyUnknownNotice` in a control envelope (`k: 'ct'`) back to the initiator, which discards the peer's pool, drops the pending session and re-initiates through `Async_Initiate`. The notice is an availability mechanism whose effect is the modelled fallback path; it is not modelled. |
| `senc('session_open', kdf(<'NyxChat_DR_Root_v3', root>))` | the first ratchet envelope (`InnerMessage.sessionOpen`) encrypted under the first message key of a `DoubleRatchetSession` seeded with `root`. |
| `!Less('a','b')`, `C_Collision_Ignore`, `C_Collision_Adopt` | `myId.compareTo(peerId) < 0` -> `SessionCollisionException`, otherwise re-derive and replace, in `SessionManager.decrypt`. |
| `Ignored(X, Y, eph)`, `NotIgnored(X, Y, eph)`, restriction `IgnoredInitsDropped` | `SessionRecord.ignoredInitEphs` (last 8 entries): appended when a collision is won and whenever a fast-path decrypt sees an `ab` field; checked before the collision and recovery branches of `SessionManager.decrypt`; copied when a session is replaced. |
| `Final(X, Y, root, ab)`, `Abandoned(X, Y, eph)`, `senc(<'reply', ab>, ...)` in `C_Reply` | `SessionRecord.abandonedInitEph`: set to the own pending ephemeral when a collision is lost (`existing?.pendingInit?.ephemeralHex`), sent as `Envelope.abandonedInitEph` (JSON `ab`, `lib/core/protocol/envelope.dart`) with every envelope while set; AAD-bound via `Envelope.associatedDataFor(from, to, kind, abandonedInitEph:)` (length-prefixed, empty string when absent) on both `SessionManager.encrypt` and `decrypt`, so a stripped or forged `ab` fails authentication. |
| `C_Recv_Reply_Final` (`AbCleared`) | fast path of `SessionManager.decrypt` on an envelope without an init block: `existing.abandonedInitEph = null`; every fast-path decrypt also runs `_remember(ignoredInitEphs, envelope.abandonedInitEph)`. |
| `C_Confirm` | the fast path in `SessionManager.decrypt` that clears `pendingInit`. |
| `C_Recover` | the re-derive-and-replace branch taken when `existing.pendingInit == null`, `acceptedInitEph != init.ephemeralHex` and the ephemeral is not in `ignoredInitEphs`; the blacklist is carried into the new record. |
| `Reveal_LTK` | compromise of all three long-term private keys of one device. |
| `Reveal_KEM_Key` / `Reveal_KEM_Ephemeral` | compromise of the long-term / per-handshake ML-KEM private key (or a break of ML-KEM). |
| `Reveal_DH_Identity` + `Reveal_DH_Ephemeral` | compromise of every X25519 secret (or a break of X25519, e.g. by a quantum computer). |

## Abstractions and their limitations

* **KEM.** ML-KEM is modelled as public-key encryption of a fresh secret:
  `kemdec(kemenc(kempk(k), r), k) = r`. Encapsulation is deterministic in
  the model (no coins), so two encapsulations of the same secret yield the
  same ciphertext; decapsulation with the wrong key is an opaque term (no
  failure), matching ML-KEM's implicit rejection. IND-CCA subtleties,
  malformed keys and ciphertext malleability are not represented.
* **KDF / HKDF.** A free function `kdf/1` over a tuple; the 0xFF prefix,
  salt/info split and output length are irrelevant symbolically.
* **Hello fields.** displayName, port and capabilities are one public value
  `$info`; the protocol version byte is the `'role1'`/`'role2'` tag. Field
  length prefixes (`CryptoUtils.lengthPrefixed`) are assumed to make the
  transcript unambiguous, which Tamarin tuples are by construction. `ih` is
  the hash of the model's tuple, not of the byte encoding.
* **Key pinning.** `!Pk($A, ...)` is the only source of a peer's keys, so a
  hello is accepted only if its keys are the registered ones for that
  identity. This models the post-TOFU state; the first-contact substitution
  window described in SECURITY.md is out of scope. An adversary-controlled
  identity is any `$E` whose keys were revealed with `Reveal_LTK`.
* **One key set per identity** (restriction `UniqueKeys`); key rotation
  (signed key transitions) is not modelled.
* **Nonce cache and ignored-init list are unbounded** in the model; the
  code keeps 2048 nonces and 8 ephemerals. An attacker who can push more
  than that many entries through before replaying is outside the model.
* **Per-handshake KEM key reveal.** `Reveal_KEM_Ephemeral` exists only in
  the handshake model. The async model's counterpart is the one-time
  prekey (`Reveal_OPK`), which exists only until it is used; the fallback
  path has no such secret (it encapsulates to the pinned long-term
  `KPK_B`).
* **Prekey registration is an ideal authenticated channel.** The signed
  bundle, its issue-time replay check and the link encryption collapse
  into direct state transfer (`OPKPub`). Pool size (8), the 30-day expiry,
  the notice for an unknown prekey and the session record's fallback flag
  are not modelled; an init naming a prekey B does not hold matches no
  rule, and the fallback is the separately modelled long-term path.
* **`ab` is modelled as integrity-protected.** The collision model puts the
  abandoned-init announcement inside the authenticated payload
  (`senc(<'reply', ab>, k)`); the code binds it into the AEAD associated
  data of every envelope (finding 6), which is equivalent for the lemmas.
* **No Double Ratchet, no link layer.** The models stop at the master
  secret / ratchet root. In the async model the first ratchet message is
  abstracted as `senc('session_open', kdf(root))`; the real first message
  key also mixes DH(ratchet key, IK_B), which does not change who can
  compute it. Per-message forward secrecy, healing and replay rejection of
  the ratchet are therefore not covered, and the async agreement lemma is
  non-injective for that reason.
* **No transport.** TCP, BLE, mesh relays and Nostr are all the Dolev-Yao
  network. Padding, sealed-sender wrappers, pair keys and tokens are not
  modelled.
* **Collision sub-model.** Exactly two parties, fixed handles, no key
  compromise; each party initiates at most once toward the other (as in the
  code: a session, once present, is reused). Session reset and identity
  rotation are not modelled.
* **Sources.** No `sources` lemma is included; see "Running".

## Findings and caveats from writing the models

The models produced six findings (the sixth while modelling the fix for
the fifth); the code was changed in response (per-handshake KEM key, `ih`
in the responder transcript, responder nonce cache, `ignoredInitEphs`, the
abandoned-init announcement and its AAD binding). Status after the changes:

1. **Initiator agreement (fixed).** Previously the responder's transcript
   did not cover the initiator's identity, keys or the derived master, so an
   adversary with its own valid identity could make A believe it had
   authenticated B while B talked to the adversary (keys differed, no
   secrecy loss). The response now carries `ih = SHA-256(initiator hello)`
   and A refuses a mismatch, so `mutual_auth_initiator` is stated as full
   injective agreement on (A, B, nA, nB, EK_A, EK_B, master).
2. **Initiator-hello replay (fixed, with a harmless residual).** The
   responder now refuses a nonce it has seen (`_recentInitiatorNonces`);
   `replay_resistance` and the injective `mutual_auth_responder` follow.
   The cache is per device and the hello names no intended responder, so a
   captured hello can still be delivered to a *different* responder, which
   answers with fresh keys that nobody else can compute
   (`hello_accepted_by_two_responders`). Resource use only.
3. **Asynchronous root had no forward secrecy against the recipient's
   long-term keys (addressed in 3.2 with one-time prekeys; fallback
   documented).** The async flow used to encapsulate to the pinned
   long-term `KPK_B` and B contributes no ephemeral, so an adversary who
   later obtained `IK_B` and `KPK_B` recovered every root B accepted before
   its first reply. Now every device hands each contact a pool of one-time
   ML-KEM prekeys on every direct link, an initiation encapsulates to one
   of them and B deletes the private half after the first message
   decrypts; `async_pq_forward_secrecy` states the resulting guarantee.
   `async_secrecy_responder` still states the exact condition for the
   fallback, taken only when the initiator holds no prekey of B (never
   met, pool used up, or B lost its store), which the session record flags
   and the contact screen shows.
4. **Post-quantum forward secrecy on direct links (fixed).** The initiator
   hello now carries a per-handshake ML-KEM key and the responder
   encapsulates to it, so a harvest-now-decrypt-later adversary who breaks
   X25519 and later seizes both devices' long-term keys still cannot
   recover master (`kem_only_forward_secrecy`). The long-term KEM key no
   longer plays any role in the direct-link handshake. The async flow gets
   the same property from one-time prekeys and keeps the long-term key as
   a flagged last resort (finding 3).
5. **Stale-init divergence in collision handling (fixed).** With handles
   `a < b` both initiating, a stale copy of `b`'s init delivered after `b`
   had adopted `a`'s session used to take the recovery branch at `a` and
   replace `a`'s session while `b` kept `a`'s. `ignoredInitEphs` closed the
   ordering in which `a` had ignored `b`'s init; the abandoned-init
   announcement (`abandonedInitEph`, envelope field `ab`, recorded on every
   fast-path decrypt) closes the ordering in which `b`'s reply reached `a`
   first. `collision_consistency` is now stated without any condition on
   the recovery path; `abandoned_init_blacklisted` and
   `abandoned_init_never_adopted` state the mechanism directly. Regression
   test: `test/crypto/session_manager_test.dart`, "a stale init arriving
   after the adopted reply is still rejected".
6. **`ab` was not authenticated (fixed).** When the announcement was added,
   `Envelope.associatedDataFor` bound only the domain string, sender,
   recipient and kind, so an active attacker or misbehaving relay could
   strip `ab` from the loser's messages (re-opening finding 5 for the
   reply-first ordering) or inject an `ab` naming a genuine recovery
   ephemeral of the peer (blacklisting that recovery until a direct-link
   reset); availability effects only. `Envelope.associatedDataFor` now
   takes `abandonedInitEph` and appends it, length-prefixed (empty string
   when absent), to the AEAD associated data; `SessionManager` passes
   `rec.abandonedInitEph` on encrypt and `envelope.abandonedInitEph` on
   decrypt, so a stripped or forged `ab` fails authentication and, because
   the ratchet commits only on success, leaves the session untouched.
   Regression test: `test/crypto/session_manager_test.dart` (both
   tampering cases). The model's `senc(<'reply', ab>, k)` is the symbolic
   equivalent of this binding. Demonstration of why it matters: move `ab`
   out of the `senc` in `C_Reply`, `C_Confirm` and `C_Recv_Reply_Final`
   and re-run; `collision_consistency` should then be falsified by the
   stripped-announcement trace.

## Reviewer checklist
- [ ] `tamarin-prover formal/nyxchat_v4_handshake.spthy` and
      `... formal/nyxchat_v4_async.spthy` parse with no well-formedness
      errors; note any partial-deconstruction warning.
- [ ] `--prove` results match the "Expected outcome" table. Record the
      Tamarin and Maude versions, the machine and the wall-clock time here.
- [ ] `tA`, `tB` and the async init block match `HelloMessage.transcriptFor`
      and `SessionInitBlock` field for field (role byte, echoed nonce, KEM
      ciphertext, `ekpk` only in the initiator hello, `ih` only in the
      response).
- [ ] `master` and `root` in the model use the same DH pairs and inputs as
      `Handshake._derive` and `Handshake._asyncRoot` (both nonces, all four
      DH values, the KEM secret; two DH values and the KEM secret), and the
      handshake KEM secret is the one decapsulated with
      `InitiatorState.ephemeralKem`, not the long-term key.
- [ ] The `!Pk` lookup is an acceptable model of `TrustStore.check`: one key
      set per handle, a key change refused before the responder sends its
      hello (`ConnectionManager._handleIncoming`) and before the initiator
      uses the link (`ConnectionManager._finish`).
- [ ] `NonceCache` matches `_recentInitiatorNonces`: the check happens
      before `Handshake.respond`, per device, and the 2048-entry bound is
      acceptable for the deployment.
- [ ] `IgnoredInitsDropped` matches `SessionRecord.ignoredInitEphs`: the
      check precedes both the collision branch and the recovery branch, the
      list is persisted with the session and copied when a session is
      replaced, and the 8-entry bound is acceptable.
- [ ] The abandoned-init announcement matches the code: set on collision
      loss only (`existing?.pendingInit?.ephemeralHex`), sent with every
      envelope while set, cleared on the first fast-path decrypt of an
      envelope without an init block, and recorded by the receiver on every
      successful fast-path decrypt (`C_Collision_Adopt`, `C_Reply`,
      `C_Confirm`, `C_Recv_Reply_Final`).
- [ ] The prekey rules match the code: `PrekeyStore.takePeerPrekey` removes
      the public half before `Handshake.asyncInitiate` runs;
      `SessionManager.decrypt` calls `PrekeyStore.deleteOwn` only after
      `ratchet.decrypt` succeeded; the two root labels differ
      (`NyxChat-Async-Prekey-Session-v4` vs `NyxChat-Async-Session-v3`) and
      the prekey id is the HKDF salt; a bundle is accepted only from the
      authenticated link peer, with a signature by the pinned key, and with
      an issue time strictly newer than the bundle on file.
- [ ] The reveal rules cover the compromise scenarios claimed in
      SECURITY.md ("Compromise of long-term keys", "always combined with
      X25519") and the lemma assumptions are not stronger than those claims.
- [ ] Findings 2 (residual) and 3 correspond to the current code paths, or
      the code has since changed and the model needs updating.
- [ ] The `ab` binding matches the model's integrity assumption:
      `Envelope.associatedDataFor(..., abandonedInitEph:)` is used with the
      same value on both `SessionManager.encrypt` and `decrypt`, and the
      absent case is encoded unambiguously (empty length-prefixed field).
- [ ] Once checked: replace the status banner at the top of this file with
      the recorded results and add the two `--prove` runs to CI
      (Tamarin's exit code does not reflect falsified lemmas; grep the
      summary for `falsified`).
