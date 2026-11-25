"""The pets' move sounds, made from code (no library sounds, nothing to license): one short, quiet sound per pet move.
6A: rare and small. Each is under 0.4 s and plays only when the pet acts (a few times a minute).

  python art/sounds/pet_sounds.py        -> art/sounds/pet_<move>.wav (44.1 kHz, mono, 16 bit)
Upload: python scripts/upload_sounds.py (ids go into Config.Sounds).
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(7)


def env(t, attack, decay):
    """fast rise, exponential fall"""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def lowpass(xs, k):
    out, y = [], 0.0
    for x in xs:
        y += k * (x - y)
        out.append(y)
    return out


def write(name, xs, peak=0.8):
    m = max(abs(x) for x in xs) or 1
    fade = int(RATE * 0.01)
    xs = [x / m * peak for x in xs]
    for i in range(fade):
        xs[-1 - i] *= i / fade
    path = os.path.join(OUT, f"pet_{name}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in xs))
    print(path, "%.2f s" % (len(xs) / RATE))


def pounce():
    """a soft thump: a low tone that drops in pitch, with a short padded click on top"""
    n = int(RATE * 0.22)
    xs, ph = [], 0.0
    noise = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.25)
    for i in range(n):
        t = i / RATE
        f = 70 + 110 * math.exp(-t / 0.035)
        ph += 2 * math.pi * f / RATE
        xs.append(math.sin(ph) * env(t, 0.004, 0.07) + noise[i] * 0.35 * env(t, 0.001, 0.012))
    write("pounce", xs)


def bell(freqs, t0s, length, decay=0.16):
    n = int(RATE * length)
    xs = [0.0] * n
    for f, t0 in zip(freqs, t0s):
        for i in range(int(t0 * RATE), n):
            t = i / RATE - t0
            e = env(t, 0.003, decay)
            xs[i] += e * (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t / 0.05)
                          + 0.15 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t / 0.03))
    return xs


def rally():
    """two rising chime notes (E5, A5): 'go on!'"""
    write("rally", lowpass(bell([659.3, 880.0], [0.0, 0.09], 0.4), 0.55), 0.6)   # top end softened


def mark():
    """one bright little 'ting'"""
    write("mark", bell([1568.0], [0.0], 0.28, decay=0.09), 0.6)


def spark():
    """a quick crackle under a rising chirp"""
    n = int(RATE * 0.2)
    xs, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        f = 1200 + 2200 * (t / 0.2)
        ph += 2 * math.pi * f / RATE
        crackle = random.uniform(-1, 1) if random.random() < 0.08 else 0.0
        xs.append(0.5 * math.sin(ph) * env(t, 0.004, 0.06) + crackle * 0.4 * env(t, 0.02, 0.06))
    # (an outside listen called the first crackle "borderline harsh": softer, faded in, the hiss taken off)
    write("spark", lowpass(xs, 0.35), 0.5)


def dig():
    """three quick scrapes in the dirt"""
    n = int(RATE * 0.32)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    low = lowpass(noise, 0.18)
    band = [a - b for a, b in zip(low, lowpass(low, 0.02))]
    xs = [0.0] * n
    for k, t0 in enumerate((0.0, 0.1, 0.2)):
        for i in range(int(t0 * RATE), n):
            t = i / RATE - t0
            xs[i] += band[i] * env(t, 0.008, 0.035) * (1 - 0.15 * k)
            # a soft low thud under each scrape, so it sounds like earth and not paper (outside listen)
            xs[i] += 0.25 * math.sin(2 * math.pi * 95 * t) * env(t, 0.004, 0.03)
    write("dig", xs, 0.7)


if __name__ == "__main__":
    pounce()
    rally()
    mark()
    spark()
    dig()
