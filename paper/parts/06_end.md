## 8. Security Analysis

We argue for each goal of Section 3, citing the machine-checked lemma where one exists (Section 5, formal verification); the collision rule's consistency lemmas are the only ones not yet decided by the prover.

**Confidentiality and integrity against observers and relays.** Message content and in-conversation metadata are inside envelopes encrypted under per-message keys that both parties derive from the ratchet, whose root comes either from the handshake master secret or from the asynchronous agreement. An observer or relay holds neither. The associated data binds sender, recipient and kind, and the ratchet header is authenticated, so modification or re-addressing is detected. Duplicates and replays are rejected because a consumed message key is deleted and a skipped-key entry is removed once used.

**Peer authentication.** After first contact, a peer must present the pinned identity key and prove possession of it: the handshake signature is over a transcript that includes the fresh nonces, and the master secret includes dh1, which an impostor without the identity private key cannot compute. On true first contact the design is trust-on-first-use, the same assumption Signal makes before safety-number verification; contact cards remove even that assumption.

**Forward secrecy and post-compromise security.** Every direct-link handshake contributes ephemeral values (dh2, dh3, dh4), so recorded sessions remain confidential after an identity-key compromise. Within a session the Double Ratchet deletes chain and message keys as it advances and heals after a compromise once the honest party performs a DH ratchet step [2, 3]. Asynchronous sessions started with a one-time prekey are no weaker: the recipient deletes the prekey's private half after the first decrypt, so the KEM secret, and with it the root, is forward secret from the first message (Tamarin lemma `async_pq_forward_secrecy`). Only the fallback without a prekey behaves as X3DH without one-time pre-keys: until the recipient replies, confidentiality against later compromise of the recipient's keys rests on the sender's ephemeral key alone (dh2), and post-quantum confidentiality on the long-term KEM key; both are restored at the first reply.

**Post-quantum confidentiality.** The KEM secret enters the master secret and the asynchronous root through HKDF alongside the classical values. A quantum adversary that breaks X25519 still needs the Kyber decapsulation key; conversely, a flaw in the Kyber implementation leaves the classical security intact. We stress that `package:post_quantum` is an unaudited implementation of the pre-standard Kyber construction; the hybrid combination is what justifies relying on it at all, and swapping in an ML-KEM binding changes one file.

**Link and presence privacy.** A LAN observer sees the two hellos, which reveal handles, display names and public keys of the two parties that chose to connect, and thereafter only sealed frames whose padded lengths and timing leak activity. In private discovery mode the beacons reveal nothing: presence tokens are HMAC outputs under a key only a contact holds, the Bloom filter is refreshed every slot, and the mDNS instance name is random; an observer cannot tell that a device runs NyxChat, let alone who it is, and cannot correlate two slots. Public mode is an explicit user choice.

**Unlinkability on the mesh and on relays.** A relay sees a recipient token and a reply token that both rotate hourly (daily on Nostr relays), per-launch random relay ids, and a payload wrapped under the pair key. It can link the two tokens of one packet and count packets within an epoch; it cannot map tokens to identities, cannot link epochs, cannot read the ratchet header, and cannot distinguish an ack from a beacon by content. Colluding relays gain only the union of these views. The wrapper is authenticated, so a relay cannot alter or re-address a packet without the drop being noticed.

**Identity rotation.** A key transition is accepted only if it carries valid signatures under both the pinned old key and the new key and the new handle is bound to the new keys, so an attacker holding neither key cannot redirect a conversation, and an attacker holding only the new keys cannot claim the old identity. An attacker holding the old key can rotate the victim's identity, which is no more than they could already do.

**Data at rest and coercion.** The database is unreadable without the master key, which is either keystore-protected or Argon2id-wrapped. The duress profile has its own keys and boxes, so the real identity and contacts are not exposed by opening it, and its optional wipe-first behaviour leaves nothing to recover. An adversary with a disk image is bounded by the password's entropy and the Argon2id cost, not by the in-app attempt counter.

**Residual risks.** Pair keys are derived from the static agreement between identity keys, so the compromise of one identity key retroactively exposes the victim's presence tokens and the outer wrapper of its past mesh and relay traffic (never the ratchet-protected content); rotating the identity closes the exposure. Bloom filters admit false positives that reveal to a stranger only that some contact of the scanner collided. Group membership is authenticated only to current members: a malicious member can add anyone. The Tamarin models have not been machine-checked in the repository and the application has not been externally audited.

## 9. Limitations and Future Work

The Bluetooth and Wi-Fi Direct transports have been exercised through the simulator and the integration tests and compile for Android, but this paper does not report measurements from a physical multi-device deployment; throughput, connection stability across Android vendors, and battery cost under continuous scanning, advertising and beacon rotation are the most important open questions and the subject of ongoing testing. Files over the mesh are capped at 4 MiB to protect relay storage. The simplified DHT lacks NAT traversal and Sybil resistance. Legacy handles from version 2 are still accepted and are derived from only 32 bits of key material; they remain safe only because trust rests on pinned keys, and they will be retired. Pair keys could be made forward-secret by deriving them from the ratchet root instead of the static agreement, at the cost of a bootstrapping problem for the first contact. One-time prekeys exist only for contacts met on a direct link and are consumed one per initiation from a pool of eight topped up at every meeting, so contacts that rarely meet but often restart sessions fall back to the long-term key, which the contact screen shows; and because unused prekeys are part of encrypted backups, restoring one can resurrect a private half the live device had deleted, leaving that session only as confidential as the backup. Planned work includes an iOS peripheral, header encryption within the ratchet, deciding the three open collision lemmas and extending the Tamarin models to the ratchet and group layers, an external audit, and a field study with volunteer users in a connectivity-constrained setting.

## 10. Conclusion

NyxChat shows that a messenger can be infrastructure-free, cryptographically conservative and private towards the strangers whose phones carry its traffic. By making an authenticated, forward-secret, padded envelope the only unit that any carrier transports, the same guarantees hold over an encrypted Wi-Fi link, through a chain of untrusted Bluetooth relays, on a public Nostr relay, and across days spent in an outbox; by deriving presence tokens, addresses and a sealed-sender wrapper from pair keys, discovery and relaying reveal nothing to anyone but the two contacts; by deriving sessions from pinned keys with a deterministic collision rule, asynchronous messaging works without a server; and by pinning keys, exposing safety numbers and signing key transitions, users can detect the attacks that have broken earlier mesh messengers without being punished for rotating their keys. The evaluation quantifies the cost of these choices, about a kilobyte per message on the mesh and tens of milliseconds per handshake with a native FIPS 203 KEM, and the delivery achievable by bounded replication, 68-99% across the densities studied at a small fraction of the cost of flooding, unaffected by the switch to rotating addresses. The case study of the previous release is a reminder that these properties exist only when the code, the tests and the documentation agree; all three, together with the fuzzers, the end-to-end tests and the formal models, are published with this paper.

## References

[1] M. Marlinspike and T. Perrin, "The X3DH Key Agreement Protocol," Signal Technical Specification, rev. 1, Nov. 2016.

[2] T. Perrin and M. Marlinspike, "The Double Ratchet Algorithm," Signal Technical Specification, rev. 1, Nov. 2016.

[3] K. Cohn-Gordon, C. Cremers, B. Dowling, L. Garratt, and D. Stebila, "A Formal Security Analysis of the Signal Messaging Protocol," Journal of Cryptology, vol. 33, pp. 1914-1983, 2020.

[4] E. Kret and R. Schmidt, "The PQXDH Key Agreement Protocol," Signal Technical Specification, rev. 3, 2023.

[5] National Institute of Standards and Technology, "Module-Lattice-Based Key-Encapsulation Mechanism Standard," FIPS 203, Aug. 2024.

[6] M. R. Albrecht, J. Blasco, R. B. Jensen, and L. Marekova, "Mesh Messaging in Large-Scale Protests: Breaking Bridgefy," in Topics in Cryptology (CT-RSA), LNCS 12704, Springer, 2021, pp. 375-398.

[7] M. R. Albrecht, R. B. Jensen, and L. Marekova, "Collective Information Security in Large-Scale Urban Protests: the Case of Hong Kong," in Proc. 30th USENIX Security Symposium, 2021, pp. 3363-3380.

[8] T. Spyropoulos, K. Psounis, and C. S. Raghavendra, "Spray and Wait: An Efficient Routing Scheme for Intermittently Connected Mobile Networks," in Proc. ACM SIGCOMM Workshop on Delay-Tolerant Networking (WDTN), 2005, pp. 252-259.

[9] A. Vahdat and D. Becker, "Epidemic Routing for Partially-Connected Ad Hoc Networks," Duke University, Tech. Rep. CS-200006, 2000.

[10] K. Fall, "A Delay-Tolerant Network Architecture for Challenged Internets," in Proc. ACM SIGCOMM, 2003, pp. 27-34.

[11] Briar Project, "Briar: Secure messaging, anywhere," and "Bramble Transport Protocol," https://briarproject.org, accessed Sept. 2026.

[12] Meshtastic, "Meshtastic: An open source, off-grid, decentralized mesh network," https://meshtastic.org, accessed Sept. 2026.

[13] WhatsApp, "WhatsApp Encryption Overview," Technical white paper, 2017 (updated 2023).

[14] P. Rosler, C. Mainka, and J. Schwenk, "More is Less: On the End-to-End Security of Group Chats in Signal, WhatsApp, and Threema," in Proc. IEEE European Symposium on Security and Privacy (EuroS&P), 2018, pp. 415-429.

[15] A. Biryukov, D. Dinu, D. Khovratovich, and S. Josefsson, "Argon2 Memory-Hard Function for Password Hashing and Proof-of-Work Applications," RFC 9106, Sept. 2021.

[16] H. Krawczyk and P. Eronen, "HMAC-based Extract-and-Expand Key Derivation Function (HKDF)," RFC 5869, May 2010.

[17] A. Langley, M. Hamburg, and S. Turner, "Elliptic Curves for Security," RFC 7748, Jan. 2016.

[18] Apple Security Engineering and Architecture, "iMessage with PQ3: The new state of the art in quantum-secure messaging at scale," Apple Security Research Blog, Feb. 2024.

[19] Bluetooth SIG, "Bluetooth Core Specification, Version 5.0," Dec. 2016.

[20] Berty Technologies, "Wesh Network Protocol," https://berty.tech, accessed Sept. 2026.

[21] J. Bos, L. Ducas, E. Kiltz, T. Lepoint, V. Lyubashevsky, J. M. Schanck, P. Schwabe, G. Seiler, and D. Stehle, "CRYSTALS-Kyber: A CCA-Secure Module-Lattice-Based KEM," in Proc. IEEE EuroS&P, 2018, pp. 353-367.

[22] D. J. Bernstein, N. Duif, T. Lange, P. Schwabe, and B.-Y. Yang, "High-speed high-security signatures," Journal of Cryptographic Engineering, vol. 2, pp. 77-89, 2012.

[23] N. Unger, S. Dechand, J. Bonneau, S. Fahl, H. Perl, I. Goldberg, and M. Smith, "SoK: Secure Messaging," in Proc. IEEE Symposium on Security and Privacy, 2015, pp. 232-249.

[24] M. J. Kannwischer, P. Schwabe, D. Stebila, and T. Wiggers, "Improving Software Quality in Cryptography Standardization Projects," in Proc. IEEE EuroS&P Workshops, 2022 (PQClean), and https://github.com/PQClean/PQClean, commit 0586a82, accessed Sept. 2026.

[25] fiatjaf et al., "NIP-01: Basic protocol flow description," Nostr Implementation Possibilities, https://github.com/nostr-protocol/nips, accessed Sept. 2026.

[26] Vitor Pamplona et al., "NIP-59: Gift Wrap," Nostr Implementation Possibilities, https://github.com/nostr-protocol/nips, accessed Sept. 2026.

[27] B. H. Bloom, "Space/time trade-offs in hash coding with allowable errors," Communications of the ACM, vol. 13, no. 7, pp. 422-426, 1970.

[28] S. Meier, B. Schmidt, C. Cremers, and D. Basin, "The TAMARIN Prover for the Symbolic Analysis of Security Protocols," in Proc. CAV, LNCS 8044, Springer, 2013, pp. 696-701.