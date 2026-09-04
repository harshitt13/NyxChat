| Operation | Mean (ms) | p95 (ms) |
|---|---|---|
| X25519 key generation | 2.880 | 2.806 |
| X25519 Diffie-Hellman | 2.183 | 2.836 |
| Ed25519 sign (256 B) | 8.735 | 13.902 |
| Ed25519 verify (256 B) | 6.485 | 9.232 |
| Kyber-768 key generation | 11.768 | 127.773 |
| Kyber-768 encapsulation | 3.193 | 13.730 |
| Kyber-768 decapsulation | 3.512 | 6.227 |
| Full v3 handshake (both sides, incl. 2 signatures, 4 DH, KEM) | 62.165 | 79.328 |
| Asynchronous session initiation (X3DH-lite + KEM) | 9.856 | 14.740 |
| Double Ratchet encrypt (symmetric step, 272 B) | 2.561 | 5.070 |
| Double Ratchet decrypt (symmetric step) | 1.811 | 3.974 |
| Double Ratchet round trip with DH ratchet (2 msgs) | 21.770 | 40.748 |
| Link-layer seal (500 B frame) | 1.079 | 3.184 |
| Link-layer open (500 B frame) | 0.353 | 0.701 |
| Sender-key group encrypt + sign | 8.698 | 13.644 |
| Sender-key group verify + decrypt | 7.854 | 11.437 |
| Argon2id unlock KDF (32 MiB, 2 passes) | 612.990 | 855.832 |
| Safety number (5120 SHA-256 iterations) | 260.183 | 273.980 |
Table: Cryptographic operation latency on the host Dart VM (x86-64, single isolate). Phone figures are expected to be roughly 2-5x higher.
