BEGIN;
SET LOCAL search_path TO promptlearn, public;

INSERT INTO organizations (id, name)
VALUES ('a1000000-0000-4000-8000-000000000001', 'โรงเรียนตัวอย่าง PromptLearn')
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, auth_subject, display_name) VALUES
    ('a1000000-0000-4000-8000-000000000002', 'promptlearn-demo-teacher', 'ครูสมชาย'),
    ('a1000000-0000-4000-8000-000000000003', 'promptlearn-demo-student', 'นักเรียนตัวอย่าง')
ON CONFLICT (id) DO NOTHING;

INSERT INTO organization_memberships (organization_id, user_id)
SELECT 'a1000000-0000-4000-8000-000000000001', id
FROM users WHERE auth_subject IN ('promptlearn-demo-teacher', 'promptlearn-demo-student')
ON CONFLICT DO NOTHING;

INSERT INTO academic_terms (id, organization_id, academic_year, semester, starts_on, ends_on)
VALUES ('a1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', 2569, 1, '2026-05-18', '2026-10-02')
ON CONFLICT (id) DO NOTHING;

INSERT INTO class_sections (id, term_id, organization_id, grade_level, name)
VALUES ('a1000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001', 'ม.1', 'ม.1/1')
ON CONFLICT (id) DO NOTHING;

INSERT INTO courses (id, organization_id, subject_code, title, grade_level, credits)
VALUES ('a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000001', 'M101', 'คณิตศาสตร์', 'ม.1', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO syllabus_versions (id, course_id, version_number)
VALUES ('a1000000-0000-4000-8000-000000000007', 'a1000000-0000-4000-8000-000000000006', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_offerings (id, organization_id, course_id, class_section_id, first_teaching_day, last_teaching_day)
VALUES ('a1000000-0000-4000-8000-000000000008', 'a1000000-0000-4000-8000-000000000001',
        'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000005', '2026-05-18', '2026-10-02')
ON CONFLICT (id) DO NOTHING;

INSERT INTO offering_memberships (offering_id, organization_id, user_id, role)
SELECT 'a1000000-0000-4000-8000-000000000008', 'a1000000-0000-4000-8000-000000000001',
       id, CASE auth_subject WHEN 'promptlearn-demo-teacher' THEN 'teacher' ELSE 'student' END
FROM users WHERE auth_subject IN ('promptlearn-demo-teacher', 'promptlearn-demo-student')
ON CONFLICT DO NOTHING;

INSERT INTO syllabus_units (id, syllabus_version_id, position, title, target_periods)
VALUES ('a1000000-0000-4000-8000-000000000009', 'a1000000-0000-4000-8000-000000000007', 1, 'เลขยกกำลัง', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO syllabus_lessons (id, unit_id, position, title)
VALUES ('a1000000-0000-4000-8000-000000000010', 'a1000000-0000-4000-8000-000000000009', 1, 'คูณเลขยกกำลังที่มีฐานเดียวกัน')
ON CONFLICT (id) DO NOTHING;

INSERT INTO planned_periods (id, syllabus_version_id, unit_id, lesson_id, position, kind)
VALUES ('a1000000-0000-4000-8000-000000000011', 'a1000000-0000-4000-8000-000000000007',
        'a1000000-0000-4000-8000-000000000009', 'a1000000-0000-4000-8000-000000000010', 1, 'instruction')
ON CONFLICT (id) DO NOTHING;

INSERT INTO lesson_sessions (id, offering_id, course_id, syllabus_version_id, planned_period_id, scheduled_start,
                             scheduled_end, actual_start, actual_end, status, recording_source, record_enabled)
VALUES ('a1000000-0000-4000-8000-000000000012', 'a1000000-0000-4000-8000-000000000008',
        'a1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000007',
        'a1000000-0000-4000-8000-000000000011', '2026-07-17 09:00+07', '2026-07-17 09:50+07',
        '2026-07-17 09:00+07', '2026-07-17 09:50+07', 'completed', 'slides', true)
ON CONFLICT (id) DO NOTHING;
COMMIT;
