# Machine-check results for `formal/`

The three Tamarin theories were run through `tamarin-prover` on 2026-09-04/05.
This file records the environment, the exact command lines, the outcome of
every lemma, the changes that had to be made to the models, and what the
results mean. The expected-outcome table in `README.md` has been replaced by
the actual outcomes.

## Environment

| | |
|---|---|
| Tamarin | `tamarin-prover 1.12.0`, release binary `tamarin-prover-1.12.0-linux64-ubuntu.tar.gz` (git revision `82780bbaf3328a45f624ddb41e51bf75425f851c`, compiled 2026-03-07) |
| Maude | 3.5.1, release binary `Maude-3.5.1-linux-x86_64.zip` (`maude` plus the `*.maude` prelude files copied next to it) |
| GraphViz | not installed (no root in the VM); only the interactive GUI needs it |
| Host | Windows 11 Pro 10.0.26200, WSL2 Ubuntu 24.04 (kernel 6.6.114.1-microsoft-standard-WSL2, glibc 2.39), 16 logical CPUs, 7.8 GB RAM visible to the VM, models read from the NTFS mount |
| `tamarin-prover test` | Maude found and accepted, all 55 unification-infrastructure cases pass; the GraphViz line fails, which makes the self-test end with "Some tests failed" (cosmetic without the GUI) |
| Memory | one `--prove` process peaked at about 3.4 GB RSS on the handshake model, so at most two or three lemmas were run in parallel |

Installation (no root needed):

```
mkdir -p ~/.local/bin && cd /tmp
curl -sSL -o tamarin.tar.gz https://github.com/tamarin-prover/tamarin-prover/releases/download/1.12.0/tamarin-prover-1.12.0-linux64-ubuntu.tar.gz
tar xzf tamarin.tar.gz && install -m 755 tamarin-prover ~/.local/bin/
curl -sSL -o maude.zip https://github.com/maude-lang/Maude/releases/download/Maude3.5.1/Maude-3.5.1-linux-x86_64.zip
unzip -oq maude.zip -d maude && install -m 755 maude/maude ~/.local/bin/ && cp maude/*.maude ~/.local/bin/
export PATH=$HOME/.local/bin:$PATH && tamarin-prover test
```

The same binaries are installed by `.github/workflows/formal.yml` (cached).
The WSL installation is left in place under `~/.local/bin`, so a second run
only costs the proof time.

## Command lines

Everything below was produced by `tool/prove_formal.sh`, which is also what
CI runs. Per lemma it executes, from `formal/`:

```
tamarin-prover --derivcheck-timeout=120 <model>.spthy                 # well-formedness pass
timeout --kill-after=30 <T> tamarin-prover --prove=<lemma> <model>.spthy   # one process per lemma
```

with the default `smart` heuristic, no `--bound`, no `--heuristic`, no
`--stop-on-trace` override and no oracle. `T` was 1500 s for the handshake
pass (two lemmas at a time) and 1200 s for the asynchronous pass (three at a
time). Tamarin was allowed its default use of all cores. Times below are
wall-clock seconds for the whole process, including about 20 s of
precomputation each.

## Results: `nyxchat_v4_handshake.spthy`

Well-formedness: `All wellformedness checks were successful` (29 s).
Raw sources: 17 cases, deconstructions complete (no `sources` lemma needed).

| Lemma | Kind | Outcome | Time (s) | Steps | Notes |
|---|---|---|---|---|---|
| `executable` | exists-trace | trace found (verified) | 494 | 23 | The trace is the honest run: `I_Send_Hello`, `R_Recv_Hello_Send_Response`, `I_Recv_Response`, no reveal. The time is the search's, not the trace's: the depth-first search first exhausted a dead subtree (the proof starts at `case 2`). Tagged `long`, see "CI". |
| `secrecy_master` | all-traces | verified | 47 | 20 | |
| `forward_secrecy` | all-traces | verified | 51 | 20 | |
| `kem_only_secrecy` | all-traces | verified | 76 | 20 | |
| `kem_only_forward_secrecy` | all-traces | verified | 49 | 20 | post-quantum forward secrecy via the per-handshake KEM key |
| `dh_only_secrecy` | all-traces | verified | 79 | 62 | |
| `mutual_auth_initiator` | all-traces | verified | 49 | 17 | full injective agreement on (A, B, nA, nB, EK_A, EK_B, master) |
| `mutual_auth_responder` | all-traces | verified | 35 | 9 | injective per responder |
| `replay_resistance` | all-traces | verified | 27 | 2 | follows from the `NonceCache` restriction |
| `response_replay_resistance` | all-traces | verified | 45 | 13 | |
| `hello_accepted_by_two_responders` | exists-trace | trace found (verified) | 48 | 15 | The documented residual: two different responders (`$B`, `$B.1`) both answer the same `I_Send_Hello` (same `nA`, `EK_A`). Resource use only; `secrecy_master` covers the orphaned key. |
| `key_agreement_consistency` | all-traces | verified | 37 | 10 | |

All twelve outcomes match the author's expectations. No lemma was
falsified, so no protocol issue was found in the direct-link handshake.
## Results: `nyxchat_v4_async.spthy`

Well-formedness: `All wellformedness checks were successful` (2 s after the
split, see "Model fixes" item 5). The theory covers the prekey path and the
long-term fallback (20 rules, 9 lemmas).

| Lemma | Kind | Outcome | Time (s) | Steps | Notes |
|---|---|---|---|---|---|
| `async_executable` | exists-trace | trace found (verified) | 5 | 10 | fallback path, honest run |
| `async_secrecy` | all-traces | verified | 5 | 22 | |
| `async_secrecy_responder` | all-traces | verified | 11 | 104 | exact condition under which the fallback root leaks |
| `async_kem_only_secrecy` | all-traces | verified | 6 | 8 | |
| `async_dh_only_secrecy` | all-traces | verified | 5 | 26 | |
| `async_agreement` | all-traces | verified | 7 | 46 | prekey and fallback path |
| `async_executable_opk` | exists-trace | trace found (verified) | 6 | 12 | prekey path, honest run |
| `async_pq_forward_secrecy` | all-traces | verified | 10 | 57 | post-quantum forward secrecy with a one-time prekey: every DH secret and every long-term key of both parties may leak after acceptance |
| `async_pq_forward_secrecy_initiator` | all-traces | verified | 6 | 8 | KEM-only variant |

All nine outcomes match the expectations. The same lemmas did not
terminate within 5 minutes while the collision rule lived in the same
theory (see "Model fixes", item 5).

## Results: `nyxchat_v4_collision.spthy`

Well-formedness: `All wellformedness checks were successful` (10 s).

| Lemma | Kind | Outcome | Time (s) | Steps | Notes |
|---|---|---|---|---|---|
| `collision_executable` | exists-trace | trace found (verified) | 114 | 32 | both parties initiate, `a` ignores, `b` adopts and replies, `a` confirms |
| `collision_consistency` | all-traces | undecided | > 293 (5 min budget) | - | no counterexample found within the budget; see below |
| `abandoned_init_blacklisted` | all-traces | undecided | > 293 (5 min budget) | - | falsified in 85 s on the model BEFORE fix 6 (see "Finding"); no counterexample found since |
| `abandoned_init_never_adopted` | all-traces | undecided | > 291 (5 min budget) | - | no counterexample found within the budget |

The three all-traces lemmas of the collision theory are the only open
items. A longer run (45 minutes per lemma) was started after this table
was written; if it terminates its outcome is appended under "Long-run
addendum". Until then the guarantee they state rests on the reasoning in
the comments of the file plus the regression tests in
test/crypto/session_manager_test.dart (`a stale init from a lost
collision cannot replace a confirmed session`, `a stale init arriving
after the adopted reply is still rejected`, `a replayed old initiation
cannot displace a recovered session`). They are tagged `long` in
`formal/lemmas.conf` and skipped in CI.

## Finding from machine-checking: replayed accepted init (fixed)

On the model as first merged, `abandoned_init_blacklisted` was
**falsified in 85 s**. Trace, in code terms: `a` (smaller handle) and `b`
both initiate; `b` adopts `a`'s init and records its abandoned ephemeral
`e_b`; the adversary replays `a`'s own init to `b`; the model had no
memory of the ephemeral `b` had already accepted, so the replay took the
recovery path, re-derived the same root and **reset `b`'s announcement**
(`Final(..., 'none')`); `b`'s later reply therefore carried no `ab`, `a`
confirmed without blacklisting `e_b`, and a stale copy of `b`'s init could
still take `a`'s recovery path.

In the code the replay of the *latest* accepted init already took the fast
path (`acceptedInitEph`), so this exact trace was a modelling artifact,
but the same trace with an *older* accepted init was real: after a genuine
recovery `acceptedInitEph` pointed at the new ephemeral and a replayed copy
of the previous initiation (whose first message decrypts under a freshly
derived session) rebuilt a session the peer no longer had. Fix 6 below and
`SessionRecord.acceptedInitEphs` (every accepted ephemeral, max 8, all of
them fast-path) close both; the recovery path also carries
`abandonedInitEph` over. Regression test: `a replayed old initiation
cannot displace a recovered session`.


## Model fixes

Neither original file had a syntax or well-formedness error: both parsed
and loaded on the first run with 1.12.0, and the only complaint was that the
message-derivation check hit its 5 s default timeout. Precomputation was,
however, impractically slow (399 s and 482 s before the first proof step,
paid again by every `--prove` process), and that is what was changed. Every
edit is listed so it can be re-applied to a merged file.

1. **Pinned-key pattern** (performance; no change in behaviour). Every rule
   that raises a pinned X25519 public key taken from `!Pk` / `!CPk` to a
   private exponent now matches that key as `'g'^~ik`, by one extra first
   line in the rule's `let` block:

   | Model | Rule | Added `let` line |
   |---|---|---|
   | handshake | `R_Recv_Hello_Send_Response` | `pkIKA  = 'g'^~ikA` |
   | handshake | `I_Recv_Response` | `pkIKB  = 'g'^~ikB` |
   | async | `Async_Initiate` | `pkIKB = 'g'^~ikB` |
   | async | `Async_Respond` | `pkIKA = 'g'^~ikA` |
   | async | `C_Initiate`, `C_Adopt_From_Idle`, `C_Collision_Adopt`, `C_Recover` | `pkIKY = 'g'^~ikY` |

   Soundness: `!Pk` is produced only by `Register_Keys` as
   `!Pk($A, 'g'^~ik, pk(~sk), kempk(~kk))` and `!CPk` only by
   `Collision_Setup` as `!CPk(h, 'g'^~ik, kempk(~kk))`, so every ground
   instance of those facts already has that shape; the set of rule instances
   is unchanged and the new fresh variable is used nowhere else in the rule.
   Effect: `I_Recv_Response` dropped from about 1,150 AC variants (four
   exponentiations with variable bases, times `verify`, times `kemdec`) to
   a few dozen, and the well-formedness/precomputation pass from 399 s to
   24 s (handshake) and from 482 s to 23 s (async).

2. **`[no_derivcheck]`** on those eight rules. Tamarin 1.10+ checks that
   every variable of a rule is derivable from the rule's premises, to catch
   unintended pattern matching; with the pattern above it reports
   `Failed to derive Variable(s): ~ikA` (resp. `~ikB`, `~ikY`) for exactly
   these rules, which is the intended match. The attribute disables that one
   heuristic for these rules only; every other well-formedness check still
   runs and passes. The proofs are identical with or without it.

3. **Comments only.** The header banners now point to this file, and the
   async header's remark that `Envelope.associatedDataFor` does not cover
   `ab` was stale (the code binds `ab` into the AEAD associated data,
   README finding 6) and was corrected. A short "machine-checking note"
   above the first protocol rule of each file explains items 1 and 2.

4. **Tried and removed.** A `sources` lemma for the echoed nonce `nA`
   (`sources_nonce`, verified in 3 steps) was added first because Tamarin
   prints `[Open Chains] Too many chain constraints, stopping
   precomputation` on the handshake model. That message comes from the
   message-derivation checker's own precomputation (it disappears with
   `--derivcheck-timeout=0`), and the interactive view shows the raw sources
   as "17 cases, deconstructions complete", so the lemma was unnecessary
   and the final files contain no `sources` lemma.


5. **Theory split** (performance). The asynchronous-initiation rules and
   the collision rules were one theory; with both present, every
   all-traces lemma of Part 1 timed out at 5 minutes because each proof
   search had to consider the collision rules as message sources. The
   collision rule now lives in `nyxchat_v4_collision.spthy` (its own
   `theory NyxChat_Collision`, same builtins, functions, equations and
   generic restrictions, its two specific restrictions, the eight `C_*`
   rules and its four lemmas). After the split the nine initiation
   lemmas verify in 5-11 s each.

6. **Accepted-init deduplication** (model AND code, see the finding
   above). New action `AcceptedInit(X, Y, ekY)` on `C_Adopt_From_Idle`,
   `C_Collision_Adopt` and `C_Recover`, restriction
   `AcceptedInitsDeduplicated` (no `Recover` for an ephemeral accepted
   earlier), and `C_Recover` now keeps `ab` instead of resetting it to
   `'none'`, mirroring `SessionRecord.abandonedInitEph` being carried over.

Apart from item 6, no lemma statement, restriction, rule premise, action or
conclusion was changed.

### Re-applying the async edits on a merged file

The main tree's `nyxchat_v4_async.spthy` has meanwhile been extended with
one-time prekeys (`Register_Prekey`, `Reveal_OPK`, `Async_Initiate_OPK`,
`Async_Respond_OPK` and three lemmas). To carry the fixes over: for each of
the six rules in the table above add the listed `let` line as the first
line of the `let` block and `[no_derivcheck]` after the rule name
(`rule Async_Respond [no_derivcheck]:`). The two new `_OPK` rules will need
the same treatment wherever they compute `pkIK...^~...` from a `!Pk` key
(and `'g'^~opk`-style prekeys from their own registration fact), otherwise
each `--prove` run pays minutes of precomputation. Add one line per new
lemma to `formal/lemmas.conf`. The WSL installation described above is
still in place.

## CI

`.github/workflows/formal.yml` (triggers: `workflow_dispatch`, and
push / pull_request touching `formal/**`, `tool/prove_formal.sh` or the
workflow) installs the same two binaries into `~/.local/bin` (cached by
version), runs `tamarin-prover test`, then
`DERIV_TIMEOUT=300 tool/prove_formal.sh --skip-long --jobs 2`, appends
`summary.md` to the job summary and uploads `build/formal/` (one log per
lemma, the well-formedness reports, `results.tsv`, `summary.md`) as the
artifact `tamarin-proofs`. Per-lemma timeouts live in `formal/lemmas.conf`;
they are the measured times above with a margin of roughly 7x for the
slower 4-vCPU runner (600 s for lemmas that took up to 80 s here).
Lemmas tagged `long` are skipped in CI and listed in the summary as
"skipped"; they are documented here instead. The script exits non-zero on a
well-formedness failure, a timeout, an error, or a falsified lemma that is
not listed in the block below.

## Accepted falsified lemmas

`tool/prove_formal.sh` reads this block; one `file:lemma` per line.

<!-- prove_formal:accepted-falsified
-->

None.

## Conclusions

* Direct-link handshake: all 12 lemmas hold (secrecy, forward secrecy
  including the post-quantum variant, mutual injective agreement, replay
  resistance on both sides, consistency), plus the documented residual.
* Asynchronous initiation: all 9 lemmas hold, including post-quantum
  forward secrecy through one-time prekeys and agreement on both paths.
* Collision rule: the executable trace exists; the three consistency
  lemmas are undecided within a 5-minute budget (no counterexample found).
  Machine-checking this theory found one real replay issue that is fixed
  in 3.2.0.
* Total: 25 lemmas, 22 verified (12 + 9 + 1 exists-trace), 3 undecided.

## Long-run addendum

(filled in when the 45-minute run of the three collision lemmas
terminates; absent means still undecided)
