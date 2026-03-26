---
name: skip-to
description: Skip ahead to a specific chapter in Learn Docker & K8s, with a knowledge quiz for skipped chapters. Use when the user wants to jump ahead, skip a chapter, or says "I already know this".
disable-model-invocation: true
argument-hint: "<chapter-number>"
---

# Skip to Chapter

The player wants to jump to Chapter $ARGUMENTS. This is allowed, but they must pass a quiz on skipped content.

## Step 1: Determine What's Being Skipped

Read `.player/progress.yaml` to find current position. Calculate which chapters would be skipped.

If the target chapter is already completed or the player is already there, just navigate to it.

## Step 2: Administer Skip-Level Quiz

For EACH skipped chapter that isn't already completed:

1. Read `curriculum/chXX-*/quiz.md`
2. Present 3-5 questions from the quiz (pick the most important ones)
3. Wait for answers
4. Score: need >= 80% (4/5) to pass

### Quiz Passed

- Record in progress.yaml: `status: skipped`, `skip_quiz_passed: true`, `quiz_score: X/Y`
- "Nice — you clearly know your stuff! Let's skip ahead."
- Navigate to the target chapter

### Quiz Failed

- Show which questions they got wrong and the correct answers
- Suggest specific lessons to review: "You might want to check out Lesson 2 in Chapter X — it covers [topic] which tripped you up."
- Offer options:
  - Try the quiz again
  - Go through the suggested lessons first
  - Start from their current chapter instead

## Step 3: Begin Target Chapter

Read the target chapter's `README.md` and deliver the story opening. Update progress.yaml with current chapter.

## Important

- Be encouraging even if they fail the quiz: "No worries — these are tricky concepts. The good news is the lessons are pretty quick."
- If they want to skip to Chapter 6 or 7 (K8s), check that kind and kubectl are installed first
- If they skip multiple chapters, quiz them on ALL skipped chapters (not just one)
