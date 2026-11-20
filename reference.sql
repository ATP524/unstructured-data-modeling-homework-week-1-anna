-- Student inputs for program 908. Run in the Day 2 student schema.
-- Evidence intervals are provided separately for scoring.
CREATE OR REPLACE VIEW hw1_assigned_lessons AS
SELECT column1::NUMBER AS lesson_slot, TRIM(column2::VARCHAR) AS lesson_slug
FROM VALUES
    (1, 'unstructureddatamodelingonsnowflakeday1lecture-nov26'),
    (2, 'unstructureddatamodelingonsnowflakeday1lab-nov26');

CREATE OR REPLACE VIEW hw1_questions AS
SELECT column1::VARCHAR AS question_id, TRIM(column2::VARCHAR) AS question_text,
       column3::BOOLEAN AS is_scored
FROM VALUES
    ('Q1', 'Why convert a video to MP3 before sending it for transcription?', TRUE),
    ('Q2', 'What share of all data is estimated to be unstructured?', TRUE),
    ('Q3', 'When is an ARRAY a good choice for modeling data in Snowflake?', TRUE),
    ('Q4', 'Which data types does the lecture say compress best in Snowflake?', TRUE),
    ('Q5', 'What three AI_PARSE_DOCUMENT modes does the lecture describe?', TRUE),
    ('Q6', 'How can you build a ground-truth dataset to check whether AI extraction is correct?', TRUE),
    ('Q7', 'How do I connect the Day 1 lab GitHub repository in Snowflake Workspaces?', TRUE),
    ('Q8', 'Which three financial metrics does the Day 1 lab extract first?', TRUE),
    ('U1', 'What is the parking policy at the DataExpert office?', FALSE);

-- Both checks must return TRUE before using the assignment inputs.
SELECT COUNT(*) = 2 AND COUNT(DISTINCT lesson_slug) = 2
       AND COALESCE(COUNT_IF(lesson_slug = '' OR STARTSWITH(lesson_slug, 'REPLACE_')), 0) = 0
       AS lesson_inputs_ready
FROM hw1_assigned_lessons;

SELECT COUNT(*) = 9 AND COUNT(DISTINCT question_id) = 9
       AND COUNT(DISTINCT question_text) = 9 AND COUNT_IF(is_scored) = 8
       AND COALESCE(COUNT_IF(question_text = '' OR STARTSWITH(question_text, 'REPLACE_')), 0) = 0
       AS question_inputs_ready
FROM hw1_questions;
