| Object | Bytes on the wire |
|---|---|
| Inner message, 200-character text (plaintext JSON) | 272 |
| Signed hello (identity, signing and Kyber keys, ephemeral, nonce, signature) | 2838 |
| Ratchet envelope carrying the 200-character text | 554 |
| Same envelope with asynchronous session-init block (ephemeral + Kyber ciphertext) | 2094 |
| Sender-key group envelope carrying the same text | 589 |
| Link-sealed frame carrying the ratchet envelope | 804 |
Table: Wire sizes of protocol objects (JSON with base64/hex encoding, before transport framing).
