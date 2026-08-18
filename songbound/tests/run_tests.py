#!/usr/bin/env python3
"""Run the whole suite, and refuse to call it green if it was shouting.

    python3 tests/run_tests.py            # everything
    python3 tests/run_tests.py TestAudio  # just one

A GDScript runtime error does not fail a test. It aborts the function it happens
in and execution carries on, so a check that never ran cannot fail, a failure
counter that was never incremented stays at zero, and the scene prints PASSED on
its way out. That has happened twice here: once when a renamed function left
five stale calls in a test, and once when a test read a field that had just
moved onto the player -- the second aborted before its first assertion and
reported success having verified nothing at all.

So a run is only a pass if the exit code is zero AND the output contains a
success line AND there is no error text anywhere in it.
"""
import subprocess
import sys
import os
import re

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Scenes that need a real renderer, and so run under xvfb.
RENDERED = {"TestField", "TestWater", "TestCreation", "TestVisual", "TestWalk",
            "TestWorldMap", "TestGuide", "ShotTown", "ShotKnown"}

# Anything Godot prints when something has gone wrong, however calmly the test
# itself then reports success.
ERROR_MARKERS = re.compile(
    r"SCRIPT ERROR|Invalid access|Invalid call|Parse Error|Compile Error|"
    r"Cannot call method|Nonexistent function|Trying to assign|"
    r"Attempt to call|out of bounds", re.I)

# How long a scene may take before it is presumed hung. A script that fails to
# parse loads as a bare node that does nothing, so the scene never reaches its
# own quit and runs until something kills it -- that has to be cheap to
# discover. The soak is the one scene whose work is honestly measured in
# minutes: it fights six hundred battles.
DEADLINE = 240
LONG_DEADLINE = {"TestPlaythrough": 900}

# What a scene prints to say it got to the end. Screenshot scenes have no
# assertions to pass, so they say they saved their pictures instead -- without
# that, a scene that worked perfectly and a scene that died silently looked
# exactly the same from out here.
SUCCESS = re.compile(r"PASSED|ALL CHECKS|SHOTS SAVED")


def scenes():
    out = []
    for name in sorted(os.listdir(os.path.join(PROJECT, "tests"))):
        if name.endswith(".tscn"):
            out.append(name[:-5])
    return out


def run(name):
    cmd = ["godot", "--path", PROJECT, "res://tests/%s.tscn" % name]
    if name in RENDERED:
        cmd = ["xvfb-run", "-a"] + cmd + ["--rendering-driver", "opengl3"]
    else:
        cmd.insert(1, "--headless")
    try:
        # A script that fails to parse loads as a bare node that does nothing,
        # so the scene never reaches its own quit and runs until something kills
        # it. Twenty minutes of that eats a whole run and reports nothing; a
        # scene that has not finished in four is broken.
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=LONG_DEADLINE.get(name, DEADLINE))
    except subprocess.TimeoutExpired:
        return name, "TIMED OUT (after %ds)" % LONG_DEADLINE.get(name, DEADLINE), []
    text = r.stdout + r.stderr
    noise = [l.strip() for l in text.splitlines() if ERROR_MARKERS.search(l)]
    failed = [l.strip() for l in text.splitlines() if l.strip().startswith("FAIL")]

    if r.returncode != 0:
        return name, "FAILED (exit %d)" % r.returncode, (failed or noise)[:6]
    if noise:
        # the important one: exit zero, says PASSED, and errored on the way
        return name, "ERRORED WHILE PASSING", noise[:6]
    if not SUCCESS.search(text):
        return name, "NO RESULT REPORTED", []
    return name, "ok", []


def main():
    wanted = sys.argv[1:] or scenes()
    bad = []
    for name in wanted:
        n, status, detail = run(name)
        print("%-16s %s" % (n, status))
        for line in detail:
            print("    %s" % line)
        if status != "ok":
            bad.append(n)
    print("")
    if bad:
        print("FAILING: %s" % ", ".join(bad))
        return 1
    print("all %d green, and quiet" % len(wanted))
    return 0


if __name__ == "__main__":
    sys.exit(main())
