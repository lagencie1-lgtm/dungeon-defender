# The 6A principles

The core principles behind "6A": a quality bar two notches past AAA. They were distilled from two months of work with
AI agents across games (shooters, brawlers, idle and skill games, a racer, a co-op wave game), music (rendered
classical recitals and game scores), trailers and short videos, a phone app and developer tools. One owner judged
everything by playing, watching and listening. Each principle held across several of those projects; one-off
lessons were left out. The companion file `6A.md` keeps the concrete numbers and cases.

---

## I. What quality is

**1. Quality is experienced, not inspected.**
Judge as the real person, on the real device, in the real first minutes: a child on a cheap phone, a viewer
scrolling, a listener with earbuds. Never judge by the code, the editor view, the tidy document or the effort spent.
Previews lie (no shadows, wrong scale, wrong speakers), and so do desktop machines and well-written reports.

**2. The whole is judged before the parts.**
The weakest thing a person meets sets the grade. A perfect system inside an unfinished whole reads as unfinished.
Bring every visible part to the same level before taking one part further.

**3. Small scope, total finish.**
Depth beats breadth. A short piece played perfectly beats a long one that tries to fit everything in. A few
features that are flawless beat many that are good. When in doubt, cut.

**4. Restraint is the craft.**
Most polish is removal. Every addition takes the place of something else instead of stacking on top. Effects are
rare, small and short, and they stay away from where the person is looking and aiming. Protect the core sensation
(the shot, the hit, the note, the voice) from anything that blurs it. If a viewer can name the effect, it is too strong.

**5. Clarity before beauty.**
It must read at a glance, at real size, without words. Nothing stands between the person and the content: no
blinds or reveals before a choice, no waiting, no fake buttons, no clutter, no text over the thing that matters.
One message at a time, in the order the eye follows.

**6. Nothing lies.**
Honesty is a quality axis:
- The world: a door that looks like a door is one.
- The rewards: a payout is shown once, at its true size.
- The marketing: what the cover promises happens early.
- The offer: no paid luck, no false scarcity, no pressure.
People feel a lie before they can name it, and it reads as cheap.

**7. Alive means imperfect by rules.**
Machine-made work fails by being too even: constant speeds, steady tempo, identical repeats, flat light, synthetic
voices. Life comes from structured variation:
- motion with weight, anticipation and settle
- timing that breathes
- voicing and dynamics that follow the phrase
- human recordings over generated ones where people listen closely

The variation follows rules and is measured. It is never random noise.

**8. Generic is the failure mode of AI work.**
The typical tells:
- symmetry and copy-paste (mirrored halves, identical rooms)
- objects placed without a reason
- tables of systems instead of a feeling
- emoji where a crafted icon belongs
- polish that is the same everywhere

Every element needs a reason to be exactly where and what it is, and the whole needs a signature: a landmark, a
look, a sound that belongs to this work only.

---

## II. What makes a game worth polishing

**9. One sentence a child can repeat.**
If the idea needs a document, it is designed for a reader, not a player. Verbs must be physical and visible. Build
on a proven format and change about a fifth of it. Lead with two or three big hooks and a clear pick, never a
feature list.

**10. The core action is the game.**
Every reward flows through the one skill the game is about. Progression makes each action worth more; it never
makes the player do more of them. Side systems earn their place by how many people actually use them. A shortcut
around the core action makes the game worse even when every timing metric improves.

**11. Keep the promise in the first minute.**
What the store page, title or thumbnail sells must happen within the first minute. The first reward and the first
upgrade come fast, priced so the first success can pay for them. Whether a player returns tomorrow is decided by
whether today's first session ran long; the first ten minutes decide everything after.

**12. Power is earned.**
A tutorial may show the top so the player wants it, but never hands over its power. Nothing a player earned should
be cheap to get.

**13. Good first minutes are not a reason to come back.**
Onboarding fixes move players further into a game; they do not make them return. Returning needs a visible next
goal and something that grows between sessions. Build both on purpose.

**14. Fairness is a design rule.**
Money buys time, capacity or certainty, never luck or power over others. There is one earned currency and a free
path to everything. Nothing has a countdown or applies pressure. A paid item is visible and used constantly. Price
for the real audience: children usually have nothing to spend.

---

## III. How to make it

**15. Question the foundation first.**
Before optimizing anything, ask whether it should exist. Measure who uses it. Cutting or parking a system often
beats polishing it, and a rule inherited from an earlier version may be the real flaw.

**16. Match a reference's structure before its surface.**
When there is a reference, read it frame by frame and match its layout, scale, proportion and camera first, then
its look. Polish never rescues a wrong layout. Understand what the reference is for and fit that to this work's
palette and play, rather than copying its surface literally.

**17. Numbers, not adjectives.**
"Smooth", "juicy" and "premium" carry no information. Before building, write a short spec the owner can veto in
seconds: the reference, the numbers (timings, curves, sizes, budgets), what it replaces, what it must never do, and
how it will be judged. Lock reference numbers in tests so they cannot drift.

**18. Instruments over imagination.**
An AI agent cannot see or hear the running work, so give it instruments:
- labs that run the real code headless
- per-frame telemetry and plots
- filmed takes stepped frame by frame
- loudness and spectrum measurements ("listening by numbers")
- bots that play like a newcomer
- checkers that score maps or layouts from data

Tune from measurements, never by imagining what a constant feels like. Copy a real system's rule, not just its
numbers.

**19. Separate the maker from the judge.**
The maker cannot see its own blind spots.
- Use reviewers who never saw the intent: fresh agents, video and audio models, adversarial code reviews. Give
  them the definition of the bar and a harsh frame.
- Check every claim against the evidence before acting; critics are noisy and invent things.
- Read the claims, not the scores.
- When independent reviewers name the same flaw unprompted, it is real: fix the whole class.
- When the same axes stay stuck for rounds, the limit is the pipeline or the assets, not the polish. Name it.

**20. Every complaint becomes a rule.**
When the owner names a flaw, write it as a rule with a number that a tool checks on every build. Over time these
rules become the house standard, and the same mistake cannot come back unnoticed.

**21. Never regress.**
- Measure the old version before changing it.
- Compare old and new under identical conditions, several times interleaved: single numbers are noise.
- Quality and performance only move one way.
- Keep old versions playable beside reworks.
- Make big changes live switches so they can be undone without a release.

**22. Effort follows risk.**
Most small changes are right the first time: look, ship, move on. Rigorous testing goes where a mistake is expensive
or invisible: money, saves, performance on weak devices, first-time players, anything public.

**23. The owner's eye is final, and their time is the bottleneck.**
- Hand over something playable or watchable every time, not a report.
- For taste calls, show two or three variants side by side with a recommendation, and batch them.
- Read requests closely: short asks usually name something that already exists, and a burst of messages is one
  message.
- Compare what the owner hands over against what is already built before swapping it in.
- Merging, publishing and spending happen only on the owner's word.

**24. Read data honestly.**
- Check the denominator.
- Separate traffic sources, because paid and organic players behave like different games.
- Compare cohorts at the same age.
- Watch the worst device (the 10th percentile), not the average.
- Fix the measurement before declaring a verdict.

Data decides what to build next. The owner's eye decides how it looks and feels.

**25. Write it down as it happens.**
Decisions, rules, lessons and the owner's own words go into a shared memory the moment they occur. A fresh session
should start from the standard, not from zero. Taste that is not written down has to be relearned through failure.

---

## IV. About prompting for quality

Superlatives work only once their meaning has been written down. After that, more adjectives add nothing.

What raises quality:
- a concrete reference
- explicit numbers
- instruments that show the running result
- a judge who never saw the reasoning

Maximalist instructions ("layer every effect", "implement every implied detail", "never ship good enough") produce
exactly the generic overdone work the bar rejects. Ask for restraint, small scope, honesty and the first ten
minutes instead.

---

## Appendix: starting numbers that held across projects

Starting points to tune from, not laws:
- **Motion.** Frame-rate-independent smoothing (`1 - exp(-k·dt)`) or critically damped springs, stepped at a
  fixed small step; never per-frame `lerp(x, t, 0.1)` or constant speed.
- **Input.** Act on the press frame. Buffer presses 100-130 ms early, give 100 ms of coyote time, and never drop a
  press silently.
- **Impact.** Hit-stop of 45-120 ms on heavy contacts, taken out of the recovery so the rhythm holds.
- **UI timing.** Small responses 90-160 ms with ease-out; reveals 280-450 ms with a 25-40 ms stagger; reward
  reveals about 2.5 s and skippable.
- **Effects.** At most one rare flash every 2-3 s, about half the first instinct's size.
- **Camera framing.** The subject fills 45-70% of frame height, with nothing over the character. A 9:16 cut shows
  as much as the 16:9 cut.
- **Video edits.** Integer speed changes only; zoom of 0.8% or less per frame; cuts on the beat grid.
- **Mixing.** Words at least 10 dB over music in the 1-4 kHz band; at most one sound cue a second; one voice and
  one growing piece of music; −14 LUFS for online video.
- **Performance.** Frame time never worse than before. Budget effects, lights and text by camera distance, step
  quality down automatically within seconds, and judge on the worst devices.
- **Retention.** The time played in the first session is the earliest predictor of return. Aim to get first-time
  players past ten minutes.
