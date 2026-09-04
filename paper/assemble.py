"""Assemble paper/nyxchat.md from paper/parts/*.md and generated tables."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
parts = sorted(ROOT.joinpath("parts").glob("*.md"))
text = "\n\n".join(p.read_text(encoding="utf-8").strip() for p in parts) + "\n"
tables = ROOT.joinpath("tables")
for name in ["bench", "sizes", "sim"]:
    f = tables.joinpath(name + ".md")
    text = text.replace("<<%s_table>>" % name, f.read_text(encoding="utf-8").strip() if f.exists() else "(pending)")
fig = ROOT.joinpath("figures", "mesh_delivery.png")
text = text.replace("<<sim_figure>>",
                    "![Delivery ratio and transmission overhead versus node count for the three forwarding strategies.](figures/mesh_delivery.png)" if fig.exists() else "")
ROOT.joinpath("nyxchat.md").write_text(text, encoding="utf-8")
print("assembled paper/nyxchat.md from", len(parts), "parts")