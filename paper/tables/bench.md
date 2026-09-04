| Operation | Mean (ms) | p95 (ms) |
|---|---|---|
| X25519 key generation | 2.826 | 2.366 |
| X25519 Diffie-Hellman | 2.020 | 2.805 |
| Ed25519 sign (256 B) | 6.168 | 8.830 |
| Ed25519 verify (256 B) | 5.730 | 7.821 |
| Kyber-768 key generation | 1.290 | 18.900 |
| Kyber-768 encapsulation | 0.487 | 3.320 |
| Kyber-768 decapsulation | 0.298 | 1.915 |
| Full v3 handshake (both sides, incl. 2 signatures, 4 DH, KEM) | 43.948 | 58.530 |
| Asynchronous session initiation (X3DH-lite + KEM) | 5.373 | 6.748 |
| Double Ratchet encrypt (symmetric step, 272 B) | 1.294 | 2.979 |
| Double Ratchet decrypt (symmetric step) | 1.227 | 2.039 |
| Double Ratchet round trip with DH ratchet (2 msgs) | 15.785 | 17.991 |
| Link-layer seal (500 B frame) | 0.885 | 2.344 |
| Link-layer open (500 B frame) | 0.330 | 0.557 |
| Sender-key group encrypt + sign | 6.947 | 9.713 |
| Sender-key group verify + decrypt | 6.918 | 8.766 |
| Argon2id unlock KDF (32 MiB, 2 passes) | 414.522 | 571.101 |
| Safety number (5120 SHA-256 iterations) | 207.971 | 262.751 |
Table: Cryptographic operation latency on the host Dart VM (x86-64, single isolate). Phone figures are expected to be roughly 2-5x higher.
