# Balance

Numbers here were tuned against `tests/TestPlaythrough.tscn`, which plays 200
real battles — 40 per region — with the whole turn engine running: turn order,
enemy AI, statuses ticking, deaths, rewards.

## Where it stands

| region | level | win rate | avg turns | HP lost per fight |
|---|---|---|---|---|
| meadow | 3 | 40/40 | 2.0 | 21% |
| wood | 10 | 39/40 | 3.3 | 40% |
| crag | 20 | 31/40 | 3.8 | 52% |
| cave | 30 | 36/40 | 4.4 | 44% |
| deep | 42 | 34/40 | 5.2 | 48% |

Crag is the sharpest step, which seems right: it is where the forgiving early
game ends.

**These are pessimistic.** The soak player never drinks a tonic despite
carrying ninety-nine of them, and always casts its single biggest damage song
rather than playing well. A human who heals will do better than this table.

## The thing worth remembering

The first balance pass used a probe that compared one player against **one**
enemy and reported turns-to-kill against turns-to-die. Every number looked
fine.

Real fights have one to three enemies, and they all attack every round. When
the soak actually played them, the player was losing **194 of 216 HP per
fight** at crag and winning half. The probe was not wrong about what it
measured; it measured the wrong thing, and no amount of care in reading it
would have shown that.

Three things came out of fixing it:

- **Enemy damage is far lower than the player's** (`atk * 0.62`, since raised
  to `0.95`), because there are several of them and one of you.
- **Enemy HP scales super-linearly with tier** (`tier^1.85`). Fights that end
  in two turns are swingy rather than tense.
- **Enemy attack scales sub-linearly** (`tier^0.78`). Late fights last longer,
  so linear attack growth compounds into a region that cannot be survived
  however well it is played.

## Tuning it

Everything is in `scripts/Data.gd`:

- `DEF_K` and the multipliers in `mitigate()`, `phys_damage()`,
  `song_damage()`, `enemy_damage()` — global lethality
- `REGIONS[].tier` — per-region difficulty
- the exponents in `make_enemy()` — how HP and attack grow with tier
- `Player.apply_level_choice()` — per-level stat gains

After any change, run the soak and read the table:

    godot --headless --path . res://tests/TestPlaythrough.tscn

It fails in **both** directions — if a region becomes unwinnable, and if it
becomes a speed bump that costs less than 12% of your health or ends in under
1.6 turns.

## One caution about sample size

At 12 fights per region the win rate swung by 30 points between runs. That is
enough to look exactly like a regression and send you tuning something that was
never broken. It is 40 now. If you lower it to make the test faster, stop
trusting small differences.
