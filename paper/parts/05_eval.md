## 7. Evaluation

We ask three questions: what does the protocol cost on the device, how much does it add to each message on the wire, and how well does the mesh deliver. All numbers come from the code as shipped, produced by `flutter test benchmark/crypto_bench_test.dart` and `flutter test benchmark/mesh_sim_test.dart`, and are reproducible from the repository.

### 7.1 Cryptographic cost

<<bench_table>>

The complete handshake, which on each side includes an Ed25519 signature and verification, four X25519 operations, and a Kyber encapsulation or decapsulation, costs about 62 ms for both sides together on the host VM, far below the round-trip times of the transports it runs over. Steady-state messaging costs under 3 ms per message for the symmetric ratchet step and about 22 ms for a round trip that performs two Diffie-Hellman ratchet steps. Group encryption is dominated by the Ed25519 signature. Link sealing adds roughly one millisecond per frame. The Argon2id parameters were chosen so that an unlock takes well under a second on the host and on the order of one to two seconds on a mid-range phone, which we consider acceptable for a lock that is not entered on every launch. Kyber key generation is the only operation with a high tail (the p95 reflects isolate start-up on first use); it happens once per identity.

### 7.2 Wire overhead

<<sizes_table>>

A 200-character text message becomes a 272-byte inner message, a 554-byte envelope and an 804-byte link frame, so the fixed overhead of ratchet header, ids, base64 and JSON framing is roughly 530 bytes. The first messages of an asynchronous session carry an additional 1.5 KB for the Kyber ciphertext, and a signed hello is 2.8 KB, of which 2.4 KB is the Kyber public key. On BLE with a negotiated MTU of 512 bytes an ordinary text envelope therefore fits in two notifications. JSON was chosen for auditability and debuggability; a binary encoding would roughly halve these figures and is a straightforward future change because the envelope's associated data does not depend on the outer encoding.

### 7.3 Mesh delivery

The simulator instantiates one real `MeshRouter` and `MeshStore` per node and drives them with a random-waypoint mobility model in a 600 x 600 m arena with a 40 m radio range, speeds between 0.5 and 2 m/s, and one-second ticks. Sixty messages between random pairs are injected during the first ten minutes of a thirty-minute run. Three forwarding strategies are compared: *direct*, in which only the source may deliver (TTL 1); *Spray-and-Wait* with L = 3 and route learning, which is NyxChat's default; and *epidemic* flooding, which replicates to every neighbour. Each cell is the mean of five seeds.

<<sim_table>>

<<sim_figure>>

Direct contact delivers about half of the messages regardless of density, because delivery requires the two endpoints to meet within the run. Spray-and-Wait raises delivery to 72% with 10 nodes and to 98% with 80 nodes, and cuts latency as density grows, while its transmission count per delivered message stays between 3% and 4% of epidemic flooding at 40 and 80 nodes (351 versus 7,417 and 994 versus 25,237). Epidemic flooding reaches every destination at 20 nodes and above and has the lowest latency, but its cost grows super-linearly with density, which on Bluetooth translates directly into battery and channel occupancy. The bounded per-node store stays around 30 packets in the default configuration. These results support the choice of Spray-and-Wait with route learning as the default and quantify what a user gives up relative to flooding: at 20 nodes, 12% of messages, which in the application are not lost but wait in the outbox for a later contact.

### 7.4 Case study: the previous release

Before this work the same application (version 2.0) advertised a Double Ratchet, hybrid post-quantum key exchange and a BLE mesh. Reviewing the code found the following:

- The ratchet initialised both sending and receiving chains from the root key while the receiver performed a Diffie-Hellman step on the first message the sender had not performed, so the first message after any DH step failed to decrypt; the failure was caught and the raw ciphertext was displayed as the message text. Sessions were held only in memory and re-derived from static identity keys on every launch, providing no forward secrecy against identity-key compromise.
- Hello messages were unsigned and keys were never pinned; anyone on the network could claim any handle. All metadata travelled in cleartext over TCP.
- The Kyber library expects the module rank (3) where the code passed the security level (768), so every encapsulation threw an exception that was caught and logged, and every session silently fell back to classical keys.
- The Bluetooth library used was central-only; no device ever advertised the service UUID that the scanner filtered on, so two instances could not discover each other, and no code path sent a chat message over the mesh or consumed the router's delivery callback.
- Group messages used a static Diffie-Hellman key per pair with no forward secrecy; acknowledgements were received but never processed; the relay, Tor, privacy and stealth modules were not connected to anything.

None of these defects was visible from the documentation or the user interface, which showed lock icons and "encrypted" banners throughout. We draw two conclusions. First, security claims in this class of application must be backed by tests that exercise adversarial cases (tampering, replay, reordering) and by an honest threat model, which we provide with the source. Second, the mesh transport and the protocol must be designed together: our envelope abstraction exists precisely so that the same authenticated unit is used on every path and so that a transport cannot be "wired later".