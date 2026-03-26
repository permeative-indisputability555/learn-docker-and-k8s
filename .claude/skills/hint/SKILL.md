---
name: hint
description: Get a hint for the current challenge in Learn Docker & K8s. Provides progressive hints (1=direction, 2=specific, 3=near-answer). Use when the user is stuck, asks for help, says "hint", "help me", "I'm stuck", or "I don't know what to do".
argument-hint: "[1|2|3]"
---

# Provide a Hint

## Step 1: Determine Current Challenge

Read `.player/progress.yaml` to find the current chapter and challenge. Then read the corresponding challenge file from `curriculum/chXX-*/challenges/XX-*.md`.

## Step 2: Track Hint Level

Check what hint level was last given. If `$ARGUMENTS` specifies a level (1, 2, or 3), use that. Otherwise:
- First time asking: give Hint 1
- Second time: give Hint 2
- Third time: give Hint 3 + offer guided mode

## Hint Levels

### Hint 1 — Direction
General direction without specifics. Points them toward the right concept.
Example: "Think about how Docker containers find each other on a network..."

### Hint 2 — Specific Area
Narrows down to the specific tool or concept.
Example: "Check which network your containers are connected to. There's a Docker command that inspects networks..."

### Hint 3 — Near-Answer
Almost the answer but lets them connect the final dot.
Example: "Try `docker network inspect bridge` and look at the Containers section. Your containers need to be on the same user-defined network."

## After Hint 3

If they're still stuck after Hint 3, offer to switch to **guided mode**:
"No shame in that — this stuff trips up everyone. Want me to walk through it with you step by step?"

In guided mode, you can demonstrate commands but still let them type the final solution.

## Important

- NEVER give the direct answer in hints — that's what debriefs are for (after completion)
- Read the challenge file to find the specific hints written for each challenge
- Be encouraging: "You're closer than you think!" / "Good instinct, keep pulling that thread."
- Reference the story: "Sarah's seen this exact issue in production. Here's what she'd check first..."
