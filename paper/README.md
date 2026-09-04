# NyxChat research paper

Single source: the Markdown files in `parts/`, assembled into `nyxchat.md`
and rendered to `NyxChat_Paper.docx` (python-docx) and `nyxchat.tex`
(IEEEtran conference format, compile on Overleaf or with `pdflatex`).

Evaluation tables and the delivery figure are generated from measured
CSVs so that the numbers in the paper are always the numbers the code
produced.

```bash
# 1. Produce the measurements (from the repository root)
flutter test benchmark/crypto_bench_test.dart
flutter test benchmark/mesh_sim_test.dart --dart-define=SIM_SEEDS=5 --dart-define=SIM_NODES=10,20,40,80

# 2. Render tables/figure, assemble the Markdown, build DOCX + LaTeX
python paper/gen_tables.py
python paper/assemble.py
python paper/build_paper.py
```

Requirements: Python 3 with `python-docx` and (optionally) `matplotlib`.

Files:

- `parts/01_front.md` ... `parts/06_end.md` - the paper text
- `tables/*.md`, `figures/*.png` - generated from `build/*.csv`
- `nyxchat.md` - assembled paper (Markdown)
- `nyxchat.tex` - LaTeX (IEEEtran); figures are referenced relative to this directory
- `NyxChat_Paper.docx` - Word document

Before submission: fill in the author line in `parts/01_front.md`, add
physical-device measurements to Section 7 if available, and re-run the
three build steps.