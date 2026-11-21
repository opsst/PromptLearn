BEGIN;
SET LOCAL search_path TO promptlearn, public;

-- Uses the synthetic course, offering, and student from demo_seed.sql.
INSERT INTO assessments (id, course_id)
VALUES ('a1000000-0000-4000-8000-000000000013', 'a1000000-0000-4000-8000-000000000006')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_versions (id, assessment_id, version_number, title, kind, purpose, published_at)
VALUES ('a1000000-0000-4000-8000-000000000014', 'a1000000-0000-4000-8000-000000000013',
        1, 'HW 3.2', 'homework', 'formative', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_items (id, assessment_version_id, position, kind, prompt, max_points, answer_key)
VALUES ('a1000000-0000-4000-8000-000000000015', 'a1000000-0000-4000-8000-000000000014', 4,
        'show_work', 'Simplify (x^2)(x^5). Show how you combine the powers.', 1,
        '{"answer":"x^7","valid_reasoning":"Expand both factors or show x^(2+5) before simplifying."}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assignments (id, offering_id, course_id, assessment_id, assessment_version_id, published_at,
                         audience, allow_ai_hints, require_work, accept_paper_photos)
VALUES ('a1000000-0000-4000-8000-000000000016', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000013',
        'a1000000-0000-4000-8000-000000000014', now(), 'selected_students', true, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO assignment_recipients (assignment_id, offering_id, student_id)
VALUES ('a1000000-0000-4000-8000-000000000016', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000003')
ON CONFLICT DO NOTHING;

INSERT INTO learning_outcomes (id, syllabus_version_id, description)
VALUES ('a1000000-0000-4000-8000-000000000017', 'a1000000-0000-4000-8000-000000000007',
        'Apply properties of powers with positive integer exponents.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_item_outcomes (item_id, outcome_id)
VALUES ('a1000000-0000-4000-8000-000000000015', 'a1000000-0000-4000-8000-000000000017')
ON CONFLICT DO NOTHING;

INSERT INTO rubric_criteria (id, item_id, position, name, max_points)
VALUES ('a1000000-0000-4000-8000-000000000018', 'a1000000-0000-4000-8000-000000000015',
        1, 'Show valid reasoning before giving the simplified power.', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO rubric_levels (criterion_id, name, awarded_points, description)
VALUES ('a1000000-0000-4000-8000-000000000018', 'Full', 1, 'Shows valid reasoning and the correct result.'),
       ('a1000000-0000-4000-8000-000000000018', 'Partial', 0.5, 'Shows valid reasoning but makes a computation error.'),
       ('a1000000-0000-4000-8000-000000000018', 'None', 0, 'The reasoning is invalid or absent.')
ON CONFLICT (criterion_id, name) DO NOTHING;

COMMIT;
