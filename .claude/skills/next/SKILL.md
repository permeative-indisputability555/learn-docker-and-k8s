---
name: next
description: Move to the next lesson or challenge in Learn Docker & K8s. Use when the user says "next", "continue", "move on", "what's next", or finishes a lesson/challenge.
---

# Navigate to Next Content

## Step 1: Read Current State

Read `.player/progress.yaml` to find:
- Current chapter
- Completed lessons
- Completed challenges

## Step 2: Determine Next Item

Follow this priority order:

### Within a chapter:
1. If there are unfinished **lessons** → go to the next lesson
2. If all lessons done but **challenges** remain → go to the next challenge
3. If all challenges done → chapter is complete, go to next chapter

### Between chapters:
1. Run the current chapter's `verify.sh` one final time to confirm completion
2. Deliver the chapter-end story beat (cliffhanger from README.md)
3. Update progress.yaml: mark chapter as completed
4. Offer cleanup of current chapter's Docker resources
5. Introduce the next chapter's story opening

## Step 3: Load Content

Read the appropriate file:
- For lessons: `curriculum/chXX-*/lessons/YY-*.md`
- For challenges: `curriculum/chXX-*/challenges/YY-*.md`

Present the content in the appropriate mode:
- **Lesson:** Teaching mode (you can demonstrate, explain, run commands)
- **Challenge:** Challenge mode (requirements only, hints on request)

## Step 4: Update Progress

Update `.player/progress.yaml` to reflect the current position.

## Edge Cases

- **Last challenge of Chapter 7:** This is the finale! Deliver the graduation ceremony from ch07 README.md.
- **Player hasn't started yet:** Redirect to `/play` to begin properly.
- **Player asks to go back:** "Sure! Which lesson or challenge do you want to revisit?"
