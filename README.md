# Week 1 homework: Find the Moment

Build a Snowflake search workflow that answers a question about a DataExpert lesson and tells a learner where to jump in the recording. Compare Day 2’s character-based transcript chunks with windows built from the API’s timed cues. A search can find the right passage and still send the learner to the wrong moment; measure both.

**100 points · Work in Snowsight**

## A. Verify the Day 2 API transcripts (15 points)

1. In Snowsight, select your assigned warehouse and the student schema you used for Day 2. Run [reference.sql](reference.sql). It contains two assigned lesson slugs, eight scored questions (`Q1` through `Q8`), and one unsupported question (`U1`). Both readiness checks must return `TRUE`.
2. Join `HW1_ASSIGNED_LESSONS` to Day 2’s `LESSON_TRANSCRIPTS` on `lesson_slug`. Confirm that both assigned lessons have full transcript text and nonempty `transcript:cues` arrays. Export a redacted inventory with the lesson slugs, `run_id`, `fetched_at`, and `cue_count`. Existing Day 2 API runs count; you do not need to fetch the transcripts again.
3. If an assigned transcript is missing, use the existing Day 2 ingestion workflow (`03_ingest.sql`, including `ingest_lessons` for the assigned program), then check the inventory again. If ingestion fails, include the query ID and tell your instructor. Keep credentials out of submissions.

## B. Build two chunk corpora (25 points)

- `CHARACTER`: Adapt Day 2’s `04_chunk_transcripts.sql` to use only the two assigned lessons in `LESSON_TRANSCRIPTS`. Split the cleaned full text into 1,500-character chunks with 200-character overlap. Estimate start and end seconds from character position and transcript duration, as in the lab.
- `CUE`: Flatten the raw `transcript:cues` array. Keep array order, lesson slug, cue text, and start and end seconds. Group consecutive cues into windows of roughly 30 to 45 seconds. Use the first cue’s start and last cue’s end; do not cut a cue at a window boundary. A shorter final window is fine. Explain your grouping rule.

Give each chunk a stable source ID, lesson slug, text, start, and end. Check malformed time ranges, missing or skipped cues, and unintended gaps. A pause in the source recording is not a processing gap. Explain any rows you exclude and report window counts and typical lengths for both methods.

### SQL hint: group cues by start time

One option is to put each cue in a 40-second bucket based on when it starts. For example, a cue from 39 to 42 seconds stays whole in the first bucket. Use the first and last cue timestamps as the chunk bounds, not the bucket edges.

```sql
WITH cues AS (
    SELECT t.lesson_slug,
           c.index AS cue_index,
           TRY_TO_DOUBLE(c.value:start::VARCHAR) AS cue_start,
           TRY_TO_DOUBLE(c.value:end::VARCHAR) AS cue_end,
           c.value:text::VARCHAR AS cue_text
    FROM lesson_transcripts t
    JOIN hw1_assigned_lessons a ON a.lesson_slug = t.lesson_slug,
    LATERAL FLATTEN(INPUT => t.transcript:cues) c
),
bucketed AS (
    SELECT *, FLOOR(cue_start / 40) AS bucket_id
    FROM cues
    WHERE cue_start >= 0 AND cue_end > cue_start
)
SELECT lesson_slug,
       lesson_slug || ':cue:' || bucket_id::VARCHAR AS source_id,
       MIN_BY(cue_start, cue_index) AS start_second,
       MAX_BY(cue_end, cue_index) AS end_second,
       COUNT(*) AS cue_count,
       LISTAGG(cue_text, ' ') WITHIN GROUP (ORDER BY cue_index) AS chunk_text
FROM bucketed
GROUP BY lesson_slug, bucket_id
ORDER BY lesson_slug, bucket_id;
```

This example assumes one transcript row per lesson and cues in chronological array order. Check those assumptions and count any cues the filter excluded. The bucket width is a target, not a guarantee: a pause can leave a short chunk, and the last cue can run past the bucket edge. Inspect the actual chunk lengths before using them in retrieval.

## C. Run a controlled retrieval comparison (20 points)

Use the same ranking method, embedding model, text formatting rules, two lessons, questions, and top‑k for both corpora. One option is Day 2’s `AI_EMBED` and cosine similarity. Rank each corpus separately, with a deterministic tie-break such as source ID. Use only the question text as query input and do not tune the scored run using the evidence intervals.

Save the top three results for each scored question and method using the CSV columns listed under “What to submit”. Use one-based ranks and seconds, and save the actual `jump_second` each citation would use. The default is the chunk’s start; document any alternative and apply the same rule to both methods. Keep a run log for all 16 scored question/method pairs, including searches that returned zero rows or failed. Export the rankings and run log before using the scoring intervals.

## D. Score retrieval and timestamp accuracy (25 points)

Use the instructor’s scoring intervals once the rankings are frozen. Match on lesson slug as well as time. A result qualifies if the chunk and an accepted evidence interval overlap for a positive duration; touching a boundary alone does not count.

- **Hit@3:** For each method, divide the number of questions with a qualifying result in the top three by eight. A completed search with no results is a miss. Flag missing or failed runs separately instead of claiming they completed.
- **Paired median timestamp error:** Keep only questions both methods hit. For each method, take its highest-ranked qualifying result and compare the saved jump point to the overlapping accepted interval. Error is zero inside the interval; outside it, use the distance to the nearest endpoint. If the chosen result overlaps several accepted intervals, use the smallest distance. Report a separate median in seconds for each method and the shared question count. If there are no shared hits, report `N/A` for both medians.

Explain one retrieval miss or poorly placed jump. If neither occurred, inspect the worst jump or a plausible distractor. Chunk lengths and the source text also differ between these two approaches, so avoid attributing every ranking difference to timestamps alone.

## E. Generate and verify cited answers (15 points)

Use `AI_COMPLETE` and a saved list of retrieved sources to answer one supported question. Ask for an answer, a faithful quote, and a source ID. Verify the quote against the source text. Look up the lesson and jump point from the retrieved Snowflake row; do not ask the model to invent a timestamp. Show the lesson and timestamp, with a jump link if supported by your lesson player.

Run `U1` using the same retrieval and answer workflow. Ask the model to say `I could not find that in the assigned transcripts.` when the sources do not support an answer. Save its actual output and say whether it abstained. Leave `U1` out of the scored metrics.

## What to submit

- Your completed worksheet or a Snowflake notebook export, with no credentials.
- Redacted ingestion evidence for both lessons.
- `ranked_results.csv` and a run-log export. Include `question_id,method,rank,source_id,lesson_slug,start_second,end_second,jump_second` in the ranked export.
- `results.md` with per-question results, the two Hit@3 scores and paired median errors, the paired sample size, your diagnosis, and both answer runs with the retrieved context used to check them. Keep course materials and excerpts in the private submission.

Grades reward the workflow and your diagnosis. Neither method has to win.
