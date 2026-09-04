"""Render evaluation tables and figures from measured CSVs into the paper.

Reads:  build/crypto_bench.csv, build/crypto_sizes.csv, build/mesh_sim.csv
        (produced by flutter test benchmark/crypto_bench_test.dart and benchmark/mesh_sim_test.dart)
Writes: paper/tables/*.md (Markdown tables), paper/figures/mesh_delivery.png
The paper source (paper/nyxchat.md) includes them via placeholder lines
"<<bench_table>>", "<<sizes_table>>", "<<sim_table>>", "<<sim_figure>>"
which paper/assemble.py substitutes.
"""
import csv
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT.joinpath("build")
OUT = ROOT.joinpath("paper", "tables")
OUT.mkdir(parents=True, exist_ok=True)
FIG = ROOT.joinpath("paper", "figures")
FIG.mkdir(parents=True, exist_ok=True)

LABELS = {
    "x25519_keygen": "X25519 key generation",
    "x25519_dh": "X25519 Diffie-Hellman",
    "ed25519_sign_256B": "Ed25519 sign (256 B)",
    "ed25519_verify_256B": "Ed25519 verify (256 B)",
    "kyber768_keygen": "Kyber-768 key generation",
    "kyber768_encaps": "Kyber-768 encapsulation",
    "kyber768_decaps": "Kyber-768 decapsulation",
    "handshake_full_both_sides": "Full v3 handshake (both sides, incl. 2 signatures, 4 DH, KEM)",
    "async_session_init": "Asynchronous session initiation (X3DH-lite + KEM)",
    "ratchet_encrypt_same_chain": "Double Ratchet encrypt (symmetric step, 272 B)",
    "ratchet_decrypt_same_chain": "Double Ratchet decrypt (symmetric step)",
    "ratchet_pingpong_roundtrip": "Double Ratchet round trip with DH ratchet (2 msgs)",
    "link_seal_500B": "Link-layer seal (500 B frame)",
    "link_open_500B": "Link-layer open (500 B frame)",
    "senderkey_encrypt": "Sender-key group encrypt + sign",
    "senderkey_decrypt": "Sender-key group verify + decrypt",
    "argon2id_32MiB_2pass": "Argon2id unlock KDF (32 MiB, 2 passes)",
    "safety_number": "Safety number (5120 SHA-256 iterations)",
}


def bench_table():
    rows = list(csv.DictReader(BUILD.joinpath("crypto_bench.csv").open()))
    lines = ["| Operation | Mean (ms) | p95 (ms) |", "|---|---|---|"]
    for r in rows:
        lines.append("| %s | %s | %s |" % (LABELS.get(r["operation"], r["operation"]), r["mean_ms"], r["p95_ms"]))
    lines.append("Table: Cryptographic operation latency on the host Dart VM (x86-64, single isolate). Phone figures are expected to be roughly 2-5x higher.")
    OUT.joinpath("bench.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def sizes_table():
    rows = list(csv.DictReader(BUILD.joinpath("crypto_sizes.csv").open()))
    names = {
        "inner_text_200B": "Inner message, 200-character text (plaintext JSON)",
        "hello_signed": "Signed hello (identity, signing and Kyber keys, ephemeral, nonce, signature)",
        "envelope_ratchet": "Ratchet envelope carrying the 200-character text",
        "envelope_ratchet_with_init": "Same envelope with asynchronous session-init block (ephemeral + Kyber ciphertext)",
        "envelope_senderkey": "Sender-key group envelope carrying the same text",
        "sealed_frame_envelope": "Link-sealed frame carrying the ratchet envelope",
    }
    lines = ["| Object | Bytes on the wire |", "|---|---|"]
    for r in rows:
        lines.append("| %s | %s |" % (names.get(r["object"], r["object"]), r["bytes"]))
    lines.append("Table: Wire sizes of protocol objects (JSON with base64/hex encoding, before transport framing).")
    OUT.joinpath("sizes.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def sim_table():
    path = BUILD.joinpath("mesh_sim.csv")
    if not path.exists():
        OUT.joinpath("sim.md").write_text("(simulation results pending)\n", encoding="utf-8")
        return
    rows = list(csv.DictReader(path.open()))
    groups = defaultdict(list)
    for r in rows:
        groups[(r["strategy"], int(r["nodes"]))].append(r)
    lines = ["| Strategy | Nodes | Delivery ratio | Mean latency (s) | p95 latency (s) | Transmissions per delivered msg | Mean stored packets per node |",
             "|---|---|---|---|---|---|---|"]
    order = ["direct", "spray", "epidemic"]
    names = {"direct": "Direct contact only", "spray": "Spray-and-Wait (L=3), NyxChat default", "epidemic": "Epidemic flooding"}
    series = defaultdict(list)
    for strategy in order:
        for nodes in sorted({n for (s, n) in groups if s == strategy}):
            rs = groups[(strategy, nodes)]
            ratio = statistics.mean(float(r["ratio"]) for r in rs)
            lat = statistics.mean(float(r["mean_latency_s"]) for r in rs)
            p95 = statistics.mean(float(r["p95_latency_s"]) for r in rs)
            ovh = statistics.mean(float(r["overhead"]) for r in rs)
            store = statistics.mean(float(r["mean_store"]) for r in rs)
            series[strategy].append((nodes, ratio, ovh))
            lines.append("| %s | %d | %.2f | %.0f | %.0f | %.0f | %.1f |" % (names[strategy], nodes, ratio, lat, p95, ovh, store))
    seeds = len(next(iter(groups.values())))
    lines.append("Table: Mesh delivery in a 600 x 600 m arena with 40 m radio range, random-waypoint mobility (0.5-2 m/s), 60 messages injected during the first 10 minutes of a 30-minute run; mean over %d seeds per cell." % seeds)
    OUT.joinpath("sim.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(8, 3.2))
        for strategy in order:
            pts = series[strategy]
            ax1.plot([p[0] for p in pts], [p[1] for p in pts], marker="o", label=names[strategy])
            ax2.plot([p[0] for p in pts], [p[2] for p in pts], marker="o", label=names[strategy])
        ax1.set_xlabel("Nodes"); ax1.set_ylabel("Delivery ratio"); ax1.set_ylim(0, 1.05); ax1.grid(alpha=0.3)
        ax2.set_xlabel("Nodes"); ax2.set_ylabel("Transmissions per delivered message"); ax2.set_yscale("log"); ax2.grid(alpha=0.3)
        ax1.legend(fontsize=7)
        fig.tight_layout()
        fig.savefig(FIG.joinpath("mesh_delivery.png"), dpi=200)
    except Exception as e:  # matplotlib optional
        print("figure skipped:", e)


if __name__ == "__main__":
    bench_table()
    sizes_table()
    sim_table()
    print("tables written to", OUT)