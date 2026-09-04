## 8. Security Analysis

We argue informally for each goal of Section 3; a machine-checked model is future work.

**Confidentiality and integrity against observers and relays.** Message content and in-conversation metadata are inside envelopes encrypted under per-message keys that both parties derive from the ratchet, whose root comes either from the handshake master secret or from the asynchronous agreement. An observer or relay holds neither. The associated data binds sender, recipient and kind, and the ratchet header is authenticated, so modification or re-addressing is detected. Duplicates and replays are rejected because a consumed message key is deleted and a skipped-key entry is removed once used.

**Peer authentication.** After first contact, a peer must present the pinned identity key and prove possession of it: the handshake signature is over a transcript that includes the fresh nonces, and the master secret includes dh1, which an impostor without the identity private key cannot compute. On true first contact the design is trust-on-first-use, the same assumption Signal makes before safety-number verification; contact cards remove even that assumption.

**Forward secrecy and post-compromise security.** Every direct-link handshake contributes ephemeral values (dh2, dh3, dh4), so recorded sessions remain confidential after an identity-key compromise. Within a session the Double Ratchet deletes chain and message keys as it advances and heals after a compromise once the honest party performs a DH ratchet step [2, 3]. Asynchronous sessions are the weaker case: until the recipient replies, confidentiality against later compromise of the recipient's identity key rests on the sender's ephemeral key alone (dh2), exactly as in X3DH without one-time pre-keys; it is restored at the first reply.

**Post-quantum confidentiality.** The KEM secret enters the master secret and the asynchronous root through HKDF alongside the classical values. A quantum adversary that breaks X25519 still needs the Kyber decapsulation key; conversely, a flaw in the Kyber implementation leaves the classical security intact. We stress that `package:post_quantum` is an unaudited implementation of the pre-standard Kyber construction; the hybrid combination is what justifies relying on it at all, and swapping in an ML-KEM binding changes one file.

**Link privacy.** A LAN observer sees the two hellos, which reveal handles, display names and public keys, and thereafter only sealed frames whose lengths and timing leak activity. Stealth mode suppresses the discovery announcements that would otherwise reveal presence even without a connection.

**Data at rest and coercion.** The database is unreadable without the master key, which is either keystore-protected or Argon2id-wrapped. The duress profile has its own keys and boxes, so the real identity and contacts are not exposed by opening it, and its optional wipe-first behaviour leaves nothing to recover. An adversary with a disk image is bounded by the password's entropy and the Argon2id cost, not by the in-app attempt counter.

**Residual risks.** Mesh addresses are stable hashes of handles, so colluding relays can learn that two hashed identities communicate and how often; a sealed-sender construction with rotating recipient tokens would remove this and is planned. Group membership is authenticated only to current members: a malicious member can add anyone. The application has not been formally verified or externally audited.

## 9. Limitations and Future Work

The Bluetooth transport has been exercised through the simulator and compiles for Android, but this paper does not report measurements from a physical multi-device deployment; throughput, connection stability across Android vendors, and battery cost under continuous scanning and advertising are the most important open questions and the subject of ongoing testing. Files require a direct link; chunked transfer over the mesh is possible but was excluded to protect relay storage. The simplified DHT and the internet relay exist in the code but are not part of the default path and lack NAT traversal and Sybil resistance. Legacy handles from version 2 are still accepted and are derived from only 32 bits of key material; they remain safe only because trust rests on pinned keys, and they will be retired. Planned work includes an iOS peripheral, an audited ML-KEM binding, sealed-sender mesh addressing, a formal model of the asynchronous initiation and collision rules, and a field study with volunteer users in a connectivity-constrained setting.

## 10. Conclusion

NyxChat shows that a messenger can be both infrastructure-free and cryptographically conservative. By making an authenticated, forward-secret envelope the only unit that any transport carries, the same guarantees hold over an encrypted Wi-Fi link, through a chain of untrusted Bluetooth relays, and across days spent in an outbox; by deriving sessions from pinned keys with a deterministic collision rule, asynchronous messaging works without a server; and by pinning keys and exposing safety numbers, users can detect the attacks that have broken earlier mesh messengers. The evaluation quantifies the cost of these choices, roughly half a kilobyte per message and tens of milliseconds per handshake, and the delivery achievable by bounded replication, 72-98% across the densities studied at a small fraction of the cost of flooding. The case study of the previous release is a reminder that these properties exist only when the code, the tests and the documentation agree; all three are published with this paper.

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