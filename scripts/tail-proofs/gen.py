# Regenerates the BND-84 tail-loop equivalence proofs. Run from the repo root:
#   python3 scripts/tail-proofs/gen.py
# Literal Char/U32 patterns are split bit by bit (bits.py), mirroring how Bend
# compiles them, so a tail loop and its *_spec reduce in step. Right folds use
# one template (folds.py). tail_laws.py writes proof/tail-laws.bend and
# proof/tail.bend from one table of laws.
import os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
outputs = {"bytes_tail.py": "proof/bytes-tail.bend", "parse_tail.py": "proof/parse-tail.bend",
           "fold_tail.py": "proof/fold-tail.bend", "misc_tail.py": "proof/misc-tail.bend"}
for script, target in outputs.items():
    text = subprocess.run([sys.executable, os.path.join(here, script)], check=True, capture_output=True, text=True).stdout
    with open(target, "w") as f:
        f.write(text.rstrip() + "\n")
subprocess.run([sys.executable, os.path.join(here, "tail_laws.py")], check=True, stdout=subprocess.DEVNULL)
