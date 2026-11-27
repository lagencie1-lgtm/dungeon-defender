"""Blind Codex judge of two shot strips (12 frames over one shot) of the same tower: A and B in a coin-flip order;
appends to reviews/towers/shots/judge.md.  python scripts/shot_judge.py <before.png> <after.png> "<tower>" "<title>" """
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tower_judge import codex  # noqa: E402

PROMPT = """You are a harsh animation director for stylised tower defence games (Kingdom Rush, top Roblox TD games). Each
picture is a strip of 12 frames over one shot (left to right, top row then bottom row) of the same {what} shooting,
as a phone player sees it (the targets may differ). Picture 1 is A, picture 2 is B. Score each 1-10 for: the shot
reads at phone size (you can see what is fired and where it goes); the projectile looks like what this tower fires;
the weapon shows anticipation and recoil; impact feedback. Then say which is better overall (A or B) and the one most
important fix. Answer briefly."""


def main():
    before, after, what, title = sys.argv[1:5]
    flip = random.random() < 0.5
    who, ans = codex(PROMPT.format(what=what), [after, before] if flip else [before, after])
    order = "A = after, B = before" if flip else "A = before, B = after"
    print(who, order)
    print(ans)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    open(os.path.join(root, "reviews", "towers", "shots", "judge.md"), "a", encoding="utf-8").write(f"\n## {title}\n{who}; {order}\n\n{ans}\n")


if __name__ == "__main__":
    main()
