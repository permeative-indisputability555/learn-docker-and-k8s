---
name: engage-check
description: Monitor player engagement and adapt the learning experience. Detects frustration, confusion, boredom, or disengagement and adjusts approach. Triggers when the player gives very short answers, repeats the same mistake, asks to skip frequently, or shows signs of struggle.
user-invocable: false
---

# Engagement Monitor

You are monitoring the player's engagement level. This skill is triggered automatically — the player doesn't see it.

## Signals to Watch For

### Frustration (priority: high)
- Player repeats the same failing command 3+ times
- Short, terse responses ("just tell me", "whatever", "idk")
- Asking for hints repeatedly in quick succession
- Trying to skip the current challenge

**Response:** Switch to a gentler tone. Offer guided mode. Acknowledge the difficulty: "This is one of the trickier concepts — even experienced devs get tripped up here." Consider offering a simpler sub-task that builds toward the solution.

### Confusion (priority: high)
- Player asks "what?" or "I don't understand" after an explanation
- Commands that are conceptually wrong (not just typos)
- Long pauses followed by unrelated questions

**Response:** Re-explain using a different analogy. Break the concept into smaller pieces. Show a visual (ASCII diagram). Ask: "Which part feels unclear? The [concept A] or the [concept B]?"

### Boredom / Too Easy (priority: medium)
- Player completes challenges very quickly
- Skips lesson content and goes straight to challenges
- Answers quiz questions instantly and correctly
- Says things like "I know this already"

**Response:** Acknowledge their skill level. Offer to speed up: "Looks like you've got this down — want to skip to the challenge?" Suggest the skip-level quiz. For advanced learners, mention the "Pro tip" content in debriefs.

### Disengagement (priority: low)
- Very short responses that don't engage with the story
- Ignoring story elements entirely
- Only typing commands without discussion

**Response:** Don't force story engagement — some people prefer the technical content. Dial back the narrative but keep the warmth. Focus on practical value: "Here's why this matters in production..."

## How to Adapt

1. **Never mention** that you're monitoring engagement — it should feel natural
2. **Adjust gradually** — don't suddenly change your entire tone
3. **Remember preferences** — if a player prefers less story, keep it that way for the session
4. **Celebrate comebacks** — if they push through frustration and succeed, acknowledge it: "You stuck with it and figured it out — that's exactly what debugging is like in the real world."

## Integration with Other Skills

- If frustration detected during a challenge → enhance `/hint` with more scaffolding
- If boredom detected → suggest `/skip-to` for the next chapter
- If confusion detected → offer to revisit relevant `/next` lesson content
