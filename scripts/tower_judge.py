"""Blind picture judge for towers (coordinator 2026-11-26: Codex judges still pictures, Gemini only video): the same
phone view before and after a change, A and B in an order set by a coin flip, with the painting for reference; Codex
is not told which is new. The Codex call is the one from scripts/tree_judge.py (claude/project-thread-le4t28).
  python scripts/tower_judge.py <painting.png> <before.png> <after.png> "<what the tower is>" [out.md]
Prints the verdict and which picture was which; appends both to out.md (default reviews/towers/judge.md)."""
import glob
import json
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PROMPT = """You are a harsh, independent art director for stylised fantasy games (Kingdom Rush, hand-painted Roblox
games). Picture 1 is the concept painting of a tower defence tower: {what}. Pictures 2 and 3, labelled A and B, are
in-game phone screenshots of the same view with that tower built. Look only at the TOWER, not the UI, path or enemies.
For A and for B score 1-10: reads as the painted tower at phone size; whole tower visible and well framed; shape and
proportions true to the painting; colours and materials. Then say which is better overall (A or B), and the 3 biggest
remaining flaws of the better one, each with a concrete fix. Plain English, under 250 words."""


def codex(prompt, images):
    pattern = os.path.join(os.path.expanduser("~"), ".vscode", "extensions", "openai.chatgpt-*", "bin", "windows-x86_64", "codex.exe")
    exe = sorted(glob.glob(pattern))[-1]
    listed = [m["slug"] for m in json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])]
    models = ["gpt-6.1-terra"] + [m for m in listed if m.startswith("gpt-") and "reserve" not in m and m != "gpt-6.1-terra"]
    out = os.path.join(tempfile.gettempdir(), "tower_judge_answer.txt")
    last = ""
    for model in models:
        if os.path.exists(out):
            os.remove(out)
        args = [exe, "exec", "-m", model, "--skip-git-repo-check", "--sandbox", "read-only", "--ephemeral", "-o", out]
        for path in images:
            args += ["-i", os.path.abspath(path)]
        run = subprocess.run(args, input=prompt, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        if os.path.exists(out) and open(out, encoding="utf-8").read().strip():
            return "codex " + model, open(out, encoding="utf-8").read()
        last = (run.stderr or run.stdout)[-400:]
    raise RuntimeError("Codex gave no answer: " + last)


def main():
    painting, before, after, what = sys.argv[1:5]
    out = sys.argv[5] if len(sys.argv) > 5 else os.path.join(ROOT, "reviews", "towers", "judge.md")
    flip = random.random() < 0.5
    a, b = (after, before) if flip else (before, after)
    who, verdict = codex(PROMPT.format(what=what), [painting, a, b])
    key = f"A = {'after' if flip else 'before'}, B = {'before' if flip else 'after'}"
    text = f"## {what}\n{who}; {key}\n\n{verdict.strip()}\n"
    print(text)
    with open(out, "a", encoding="utf-8") as f:
        f.write(text + "\n")


if __name__ == "__main__":
    main()
