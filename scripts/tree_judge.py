"""Blind outside check of map trees (the tower workflow's last gate): two in-game stills of the same view, A and B in
an order set by a coin flip, judged without being told which is new: by Codex (Lemp 2026-11-26: "use the codex",
the owner's ChatGPT login on this PC) or with --gemini by Gemini.
  python scripts/tree_judge.py old.jpg new.jpg [more_old.jpg more_new.jpg ...] [--gemini]
Prints the verdict and which picture was which; appends to reviews/maps/trees.md."""
import base64
import glob
import json
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

PROMPT = """You are a harsh, independent art director for stylised fantasy games (think Kingdom Rush, Dungeon
Defenders, hand-painted Roblox games). Below are pairs of screenshots of the SAME view of a Roblox tower defense map,
labelled A and B. Look only at the TREES (crowns, trunks, how they sit together), not at the UI, path or characters.
For A and for B, score 1-10 each:
- Painted look: does it read as hand-painted stylised fantasy foliage (10), or as glossy plastic balls / bubble gum
  (1-2)?
- Shape: believable trunk, limbs and crown masses with a clear silhouette, or blobs on sticks?
- Light: a clear light side and shadow side in the crowns, or flat one-colour green?
- Fit: do the trees suit a painted fantasy game world?
Then: which set of trees is better overall (A or B), and the 3 biggest remaining flaws of the better one, each with a
concrete fix. Plain English, under 300 words."""


def image(path):
    return {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()}}


def codex(prompt, images):
    """the picture judge: Codex with the pictures attached, read-only; its last message is the verdict"""
    pattern = os.path.join(os.path.expanduser("~"), ".vscode", "extensions", "openai.chatgpt-*", "bin", "windows-x86_64", "codex.exe")
    exe = sorted(glob.glob(pattern))[-1]
    # (the first model in Codex's list is not always served for a ChatGPT login: try them in turn, the one that
    # judged before first)
    listed = [m["slug"] for m in json.load(open(os.path.expanduser("~/.codex/models_cache.json"), encoding="utf-8")).get("models", [])]
    models = ["gpt-6.1-terra"] + [m for m in listed if m.startswith("gpt-") and "reserve" not in m and m != "gpt-6.1-terra"]
    out = os.path.join(tempfile.gettempdir(), "tree_judge_answer.txt")
    last = ""
    for model in models:
        if os.path.exists(out):
            os.remove(out)
        args = [exe, "exec", "-m", model, "--skip-git-repo-check", "--sandbox", "read-only", "--ephemeral", "-o", out]
        for path in images:
            args += ["-i", os.path.abspath(path)]
        # (the prompt goes in on stdin: --image takes every argument after it as a picture)
        run = subprocess.run(args, input=prompt, capture_output=True, text=True, encoding="utf-8", errors="ignore", timeout=900)
        if os.path.exists(out) and open(out, encoding="utf-8").read().strip():
            return "codex " + model, open(out, encoding="utf-8").read()
        last = (run.stderr or run.stdout)[-400:]
    raise RuntimeError("Codex gave no answer: " + last)


def main():
    use_gemini = "--gemini" in sys.argv
    files = [f for f in sys.argv[1:] if f != "--gemini"]
    flip = random.Random().random() < 0.5
    parts = [{"text": PROMPT}]
    order = []
    for i in range(0, len(files), 2):
        old, new = files[i], files[i + 1]
        a, b = (new, old) if flip else (old, new)
        parts += [{"text": f"Pair {i // 2 + 1}, A:"}, image(a), {"text": f"Pair {i // 2 + 1}, B:"}, image(b)]
        order += [(f"Pair {i // 2 + 1}, A", a), (f"Pair {i // 2 + 1}, B", b)]
    if use_gemini:
        from pet_bench import call
        model, text = call(parts)
    else:
        listing = " ".join(f"Attached picture {k + 1} is {label}." for k, (label, _) in enumerate(order))
        model, text = codex(PROMPT + "\n\n" + listing + " Do not open or run anything; answer from the pictures.",
                            [p for _, p in order])
    key = f"(blind: A = {'NEW' if flip else 'OLD'}, B = {'OLD' if flip else 'NEW'}; {model})"
    print(text)
    print(key)
    with open(os.path.join(ROOT, "reviews", "maps", "trees.md"), "a", encoding="utf-8") as f:
        f.write(f"\n## Judge {key}\nFiles: {', '.join(os.path.basename(x) for x in files)}\n\n{text}\n")


if __name__ == "__main__":
    main()
