BEGIN;

CREATE SCHEMA promptlearn;
SET LOCAL search_path TO promptlearn, public;

CREATE TABLE organizations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    time_zone text NOT NULL DEFAULT 'Asia/Bangkok'
);

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_subject text NOT NULL UNIQUE,
    display_name text NOT NULL
);

CREATE TABLE organization_memberships (
    organization_id uuid REFERENCES organizations,
    user_id uuid REFERENCES users,
    PRIMARY KEY (organization_id, user_id)
);

CREATE TABLE academic_terms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    academic_year integer NOT NULL,
    semester smallint NOT NULL CHECK (semester > 0),
    starts_on date NOT NULL,
    ends_on date NOT NULL CHECK (ends_on >= starts_on),
    UNIQUE (organization_id, academic_year, semester),
    UNIQUE (id, organization_id)
);

CREATE TABLE class_sections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    term_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    grade_level text NOT NULL,
    name text NOT NULL,
    FOREIGN KEY (term_id, organization_id) REFERENCES academic_terms (id, organization_id),
    UNIQUE (term_id, grade_level, name),
    UNIQUE (id, organization_id)
);

CREATE TABLE assets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    object_key text NOT NULL UNIQUE,
    content_type text NOT NULL,
    byte_size bigint CHECK (byte_size >= 0),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'failed')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE courses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    subject_code text NOT NULL,
    title text NOT NULL,
    grade_level text NOT NULL,
    credits numeric(5,2) NOT NULL CHECK (credits >= 0),
    UNIQUE (id, organization_id)
);

CREATE TABLE syllabus_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES courses,
    version_number integer NOT NULL CHECK (version_number > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    UNIQUE (course_id, version_number),
    UNIQUE (id, course_id)
);

CREATE TABLE course_offerings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    course_id uuid NOT NULL,
    class_section_id uuid NOT NULL,
    first_teaching_day date NOT NULL,
    last_teaching_day date NOT NULL CHECK (last_teaching_day >= first_teaching_day),
    FOREIGN KEY (course_id, organization_id) REFERENCES courses (id, organization_id),
    FOREIGN KEY (class_section_id, organization_id) REFERENCES class_sections (id, organization_id),
    UNIQUE (course_id, class_section_id),
    UNIQUE (id, organization_id),
    UNIQUE (id, course_id)
);

CREATE TABLE offering_memberships (
    offering_id uuid,
    organization_id uuid NOT NULL,
    user_id uuid,
    role text NOT NULL CHECK (role IN ('teacher', 'student')),
    FOREIGN KEY (offering_id, organization_id) REFERENCES course_offerings (id, organization_id),
    FOREIGN KEY (organization_id, user_id) REFERENCES organization_memberships,
    PRIMARY KEY (offering_id, user_id)
);

CREATE TABLE offering_syllabus_publications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id uuid NOT NULL,
    course_id uuid NOT NULL,
    syllabus_version_id uuid NOT NULL,
    published_at timestamptz NOT NULL DEFAULT now(),
    superseded_at timestamptz CHECK (superseded_at >= published_at),
    show_indicators boolean NOT NULL DEFAULT false,
    show_teaching_notes boolean NOT NULL DEFAULT false,
    FOREIGN KEY (offering_id, course_id) REFERENCES course_offerings (id, course_id),
    FOREIGN KEY (syllabus_version_id, course_id) REFERENCES syllabus_versions (id, course_id)
);

CREATE UNIQUE INDEX offering_one_current_syllabus
    ON offering_syllabus_publications (offering_id) WHERE superseded_at IS NULL;

CREATE TABLE venues (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    name text NOT NULL,
    latitude numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    UNIQUE (id, organization_id)
);

CREATE TABLE weekly_timetable_slots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    venue_id uuid,
    weekday smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    period_number smallint NOT NULL CHECK (period_number > 0),
    local_starts_at time NOT NULL,
    local_ends_at time NOT NULL CHECK (local_ends_at > local_starts_at),
    FOREIGN KEY (offering_id, organization_id) REFERENCES course_offerings (id, organization_id),
    FOREIGN KEY (venue_id, organization_id) REFERENCES venues (id, organization_id),
    UNIQUE (offering_id, weekday, period_number)
);

CREATE TABLE school_calendar_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    term_id uuid NOT NULL REFERENCES academic_terms,
    title text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('holiday', 'school_event', 'exam_window')),
    starts_on date NOT NULL,
    ends_on date NOT NULL CHECK (ends_on >= starts_on),
    blocks_regular_classes boolean NOT NULL DEFAULT true
);

CREATE TABLE textbooks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    title text NOT NULL,
    edition text,
    source_asset_id uuid REFERENCES assets,
    page_count integer CHECK (page_count > 0)
);

CREATE TABLE textbook_chapters (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    textbook_id uuid NOT NULL REFERENCES textbooks,
    position integer NOT NULL CHECK (position > 0),
    title text NOT NULL,
    UNIQUE (textbook_id, position)
);

CREATE TABLE curriculum_indicators (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    curriculum_edition text NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    UNIQUE (curriculum_edition, code)
);

CREATE TABLE syllabus_textbooks (
    syllabus_version_id uuid REFERENCES syllabus_versions,
    textbook_id uuid REFERENCES textbooks,
    PRIMARY KEY (syllabus_version_id, textbook_id)
);

CREATE TABLE learning_outcomes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    syllabus_version_id uuid NOT NULL REFERENCES syllabus_versions,
    indicator_id uuid REFERENCES curriculum_indicators,
    description text NOT NULL,
    UNIQUE (syllabus_version_id, indicator_id)
);

CREATE TABLE outcome_chapter_matches (
    outcome_id uuid REFERENCES learning_outcomes,
    chapter_id uuid REFERENCES textbook_chapters,
    source text NOT NULL CHECK (source IN ('ai', 'teacher')),
    status text NOT NULL CHECK (status IN ('suggested', 'accepted', 'rejected')),
    PRIMARY KEY (outcome_id, chapter_id)
);

CREATE TABLE syllabus_units (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    syllabus_version_id uuid NOT NULL REFERENCES syllabus_versions,
    position integer NOT NULL CHECK (position > 0),
    title text NOT NULL,
    target_periods integer NOT NULL CHECK (target_periods > 0),
    UNIQUE (syllabus_version_id, position),
    UNIQUE (id, syllabus_version_id)
);

CREATE TABLE syllabus_lessons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id uuid NOT NULL REFERENCES syllabus_units,
    position integer NOT NULL CHECK (position > 0),
    title text NOT NULL,
    UNIQUE (unit_id, position),
    UNIQUE (id, unit_id)
);

CREATE TABLE lesson_outcomes (
    lesson_id uuid REFERENCES syllabus_lessons,
    outcome_id uuid REFERENCES learning_outcomes,
    PRIMARY KEY (lesson_id, outcome_id)
);

CREATE TABLE planned_periods (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    syllabus_version_id uuid NOT NULL REFERENCES syllabus_versions,
    unit_id uuid,
    lesson_id uuid,
    position integer NOT NULL CHECK (position > 0),
    kind text NOT NULL CHECK (kind IN ('instruction', 'review', 'quiz', 'orientation', 'buffer')),
    FOREIGN KEY (unit_id, syllabus_version_id) REFERENCES syllabus_units (id, syllabus_version_id),
    FOREIGN KEY (lesson_id, unit_id) REFERENCES syllabus_lessons (id, unit_id),
    CHECK (lesson_id IS NULL OR unit_id IS NOT NULL),
    CHECK (kind <> 'instruction' OR lesson_id IS NOT NULL),
    UNIQUE (syllabus_version_id, position),
    UNIQUE (id, syllabus_version_id)
);

CREATE TABLE lesson_plan_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    planned_period_id uuid NOT NULL REFERENCES planned_periods,
    version_number integer NOT NULL CHECK (version_number > 0),
    approach text NOT NULL CHECK (approach IN ('ibl', '5e', 'cpa', 'flipped', 'custom')),
    source text NOT NULL CHECK (source IN ('ai', 'teacher')),
    teaching_notes text,
    UNIQUE (planned_period_id, version_number),
    UNIQUE (id, planned_period_id)
);

CREATE TABLE lesson_activities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_plan_version_id uuid NOT NULL REFERENCES lesson_plan_versions,
    position integer NOT NULL CHECK (position > 0),
    kind text NOT NULL,
    duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
    instructions text NOT NULL,
    UNIQUE (lesson_plan_version_id, position)
);

CREATE TABLE teaching_materials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES courses,
    title text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('slides', 'whiteboard', 'document'))
);

CREATE TABLE material_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id uuid NOT NULL REFERENCES teaching_materials,
    version_number integer NOT NULL CHECK (version_number > 0),
    asset_id uuid REFERENCES assets,
    document jsonb,
    CHECK (asset_id IS NOT NULL OR document IS NOT NULL),
    UNIQUE (material_id, version_number)
);

CREATE TABLE lesson_materials (
    lesson_plan_version_id uuid REFERENCES lesson_plan_versions,
    material_version_id uuid REFERENCES material_versions,
    PRIMARY KEY (lesson_plan_version_id, material_version_id)
);

CREATE TABLE lesson_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id uuid NOT NULL,
    course_id uuid NOT NULL,
    syllabus_version_id uuid NOT NULL,
    planned_period_id uuid NOT NULL,
    lesson_plan_version_id uuid,
    scheduled_start timestamptz NOT NULL,
    scheduled_end timestamptz NOT NULL CHECK (scheduled_end > scheduled_start),
    actual_start timestamptz,
    actual_end timestamptz,
    status text NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    recording_source text CHECK (recording_source IN ('slides', 'screen')),
    record_enabled boolean NOT NULL DEFAULT false,
    live_enabled boolean NOT NULL DEFAULT false,
    track_participation boolean NOT NULL DEFAULT false,
    FOREIGN KEY (offering_id, course_id) REFERENCES course_offerings (id, course_id),
    FOREIGN KEY (syllabus_version_id, course_id) REFERENCES syllabus_versions (id, course_id),
    FOREIGN KEY (planned_period_id, syllabus_version_id) REFERENCES planned_periods (id, syllabus_version_id),
    FOREIGN KEY (lesson_plan_version_id, planned_period_id) REFERENCES lesson_plan_versions (id, planned_period_id),
    CHECK (actual_end IS NULL OR (actual_start IS NOT NULL AND actual_end >= actual_start)),
    UNIQUE (offering_id, planned_period_id),
    UNIQUE (id, offering_id)
);

CREATE INDEX lesson_sessions_schedule ON lesson_sessions (offering_id, scheduled_start);

CREATE TABLE grading_plan_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    syllabus_version_id uuid NOT NULL REFERENCES syllabus_versions,
    name text NOT NULL,
    bucket text NOT NULL CHECK (bucket IN ('during_term', 'final')),
    allocated_points numeric(6,2) NOT NULL CHECK (allocated_points BETWEEN 0 AND 100),
    UNIQUE (syllabus_version_id, name),
    UNIQUE (id, syllabus_version_id)
);

CREATE TABLE assessments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES courses,
    UNIQUE (id, course_id)
);

CREATE TABLE assessment_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id uuid NOT NULL REFERENCES assessments,
    version_number integer NOT NULL CHECK (version_number > 0),
    title text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('quiz', 'homework', 'exam', 'classwork', 'practice')),
    purpose text NOT NULL CHECK (purpose IN ('formative', 'summative')),
    updated_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    UNIQUE (assessment_id, version_number),
    UNIQUE (id, assessment_id)
);

CREATE TABLE question_imports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_version_id uuid NOT NULL REFERENCES assessment_versions,
    asset_id uuid NOT NULL REFERENCES assets,
    extracted_text text,
    review_status text NOT NULL DEFAULT 'pending'
        CHECK (review_status IN ('pending', 'needs_review', 'accepted', 'rejected')),
    UNIQUE (id, assessment_version_id)
);

CREATE TABLE assessment_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_version_id uuid NOT NULL REFERENCES assessment_versions,
    question_import_id uuid,
    position integer NOT NULL CHECK (position > 0),
    kind text NOT NULL CHECK (kind IN ('short_answer', 'show_work', 'multiple_choice', 'true_false')),
    prompt text NOT NULL,
    max_points numeric(8,2) NOT NULL CHECK (max_points >= 0),
    answer_key jsonb,
    FOREIGN KEY (question_import_id, assessment_version_id) REFERENCES question_imports (id, assessment_version_id),
    UNIQUE (assessment_version_id, position),
    UNIQUE (id, assessment_version_id)
);

CREATE TABLE assessment_item_outcomes (
    item_id uuid REFERENCES assessment_items,
    outcome_id uuid REFERENCES learning_outcomes,
    PRIMARY KEY (item_id, outcome_id)
);

CREATE TABLE rubric_criteria (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id uuid NOT NULL REFERENCES assessment_items,
    position integer NOT NULL CHECK (position > 0),
    name text NOT NULL,
    max_points numeric(8,2) NOT NULL CHECK (max_points >= 0),
    UNIQUE (item_id, position),
    UNIQUE (id, item_id)
);

CREATE TABLE rubric_levels (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    criterion_id uuid NOT NULL REFERENCES rubric_criteria,
    name text NOT NULL,
    awarded_points numeric(8,2) NOT NULL CHECK (awarded_points >= 0),
    description text NOT NULL,
    UNIQUE (criterion_id, name),
    UNIQUE (id, criterion_id)
);

CREATE TABLE assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id uuid NOT NULL,
    course_id uuid NOT NULL,
    assessment_id uuid NOT NULL,
    assessment_version_id uuid NOT NULL,
    lesson_session_id uuid,
    opens_at timestamptz,
    due_at timestamptz,
    published_at timestamptz,
    audience text NOT NULL DEFAULT 'class' CHECK (audience IN ('class', 'selected_students')),
    time_limit_seconds integer CHECK (time_limit_seconds > 0),
    max_attempts integer NOT NULL DEFAULT 1 CHECK (max_attempts > 0),
    require_work boolean NOT NULL DEFAULT false,
    accept_paper_photos boolean NOT NULL DEFAULT false,
    allow_ai_hints boolean NOT NULL DEFAULT false,
    shuffle_questions boolean NOT NULL DEFAULT false,
    FOREIGN KEY (offering_id, course_id) REFERENCES course_offerings (id, course_id),
    FOREIGN KEY (assessment_id, course_id) REFERENCES assessments (id, course_id),
    FOREIGN KEY (assessment_version_id, assessment_id) REFERENCES assessment_versions (id, assessment_id),
    FOREIGN KEY (lesson_session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    CHECK (due_at >= opens_at),
    UNIQUE (id, offering_id),
    UNIQUE (id, offering_id, assessment_version_id)
);

CREATE TABLE assignment_recipients (
    assignment_id uuid,
    offering_id uuid NOT NULL,
    student_id uuid,
    due_at_override timestamptz,
    FOREIGN KEY (assignment_id, offering_id) REFERENCES assignments (id, offering_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    PRIMARY KEY (assignment_id, student_id)
);

CREATE TABLE assignment_grading_items (
    assignment_id uuid PRIMARY KEY,
    offering_id uuid NOT NULL,
    course_id uuid NOT NULL,
    syllabus_version_id uuid NOT NULL,
    grading_plan_item_id uuid NOT NULL,
    FOREIGN KEY (assignment_id, offering_id) REFERENCES assignments (id, offering_id),
    FOREIGN KEY (offering_id, course_id) REFERENCES course_offerings (id, course_id),
    FOREIGN KEY (syllabus_version_id, course_id) REFERENCES syllabus_versions (id, course_id),
    FOREIGN KEY (grading_plan_item_id, syllabus_version_id) REFERENCES grading_plan_items (id, syllabus_version_id)
);

CREATE TABLE assessment_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    offering_id uuid NOT NULL,
    course_id uuid NOT NULL,
    syllabus_version_id uuid NOT NULL,
    grading_plan_item_id uuid NOT NULL,
    assignment_id uuid,
    lesson_session_id uuid,
    title text NOT NULL,
    event_kind text NOT NULL CHECK (event_kind IN ('quiz', 'midterm', 'final', 'other')),
    starts_at timestamptz,
    planned_points numeric(6,2) NOT NULL CHECK (planned_points BETWEEN 0 AND 100),
    FOREIGN KEY (offering_id, course_id) REFERENCES course_offerings (id, course_id),
    FOREIGN KEY (syllabus_version_id, course_id) REFERENCES syllabus_versions (id, course_id),
    FOREIGN KEY (grading_plan_item_id, syllabus_version_id) REFERENCES grading_plan_items (id, syllabus_version_id),
    FOREIGN KEY (assignment_id, offering_id) REFERENCES assignments (id, offering_id),
    FOREIGN KEY (lesson_session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    UNIQUE (id, syllabus_version_id)
);

CREATE TABLE assessment_event_units (
    assessment_event_id uuid,
    syllabus_version_id uuid NOT NULL,
    unit_id uuid,
    FOREIGN KEY (assessment_event_id, syllabus_version_id) REFERENCES assessment_events (id, syllabus_version_id),
    FOREIGN KEY (unit_id, syllabus_version_id) REFERENCES syllabus_units (id, syllabus_version_id),
    PRIMARY KEY (assessment_event_id, unit_id)
);

CREATE TABLE attendance_windows (
    session_id uuid PRIMARY KEY,
    offering_id uuid NOT NULL,
    venue_id uuid NOT NULL REFERENCES venues,
    opens_at timestamptz NOT NULL,
    late_after timestamptz NOT NULL,
    closes_at timestamptz NOT NULL,
    radius_meters integer NOT NULL CHECK (radius_meters > 0),
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    CHECK (opens_at <= late_after AND late_after <= closes_at)
);

CREATE TABLE attendance_records (
    session_id uuid,
    offering_id uuid NOT NULL,
    student_id uuid,
    status text NOT NULL CHECK (status IN ('present', 'late', 'absent', 'on_leave')),
    method text NOT NULL CHECK (method IN ('location', 'teacher', 'system')),
    checked_at timestamptz NOT NULL DEFAULT now(),
    changed_by uuid REFERENCES users,
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    PRIMARY KEY (session_id, student_id)
);

CREATE TABLE leave_requests (
    session_id uuid,
    offering_id uuid NOT NULL,
    student_id uuid,
    reason text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at timestamptz NOT NULL DEFAULT now(),
    decided_by uuid REFERENCES users,
    decided_at timestamptz,
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    PRIMARY KEY (session_id, student_id)
);

CREATE TABLE recordings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL REFERENCES lesson_sessions,
    asset_id uuid REFERENCES assets,
    duration_ms integer CHECK (duration_ms > 0),
    UNIQUE (id, session_id)
);

CREATE TABLE transcript_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id uuid NOT NULL REFERENCES recordings,
    version_number integer NOT NULL CHECK (version_number > 0),
    language_code text NOT NULL DEFAULT 'th',
    UNIQUE (recording_id, version_number),
    UNIQUE (id, recording_id)
);

CREATE TABLE transcript_segments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_version_id uuid NOT NULL REFERENCES transcript_versions,
    start_ms integer NOT NULL CHECK (start_ms >= 0),
    end_ms integer NOT NULL CHECK (end_ms > start_ms),
    speaker_role text CHECK (speaker_role IN ('teacher', 'student', 'unknown')),
    body text NOT NULL
);

CREATE TABLE recording_chapters (
    recording_id uuid REFERENCES recordings,
    start_ms integer CHECK (start_ms >= 0),
    title text NOT NULL,
    source text NOT NULL CHECK (source IN ('ai', 'teacher')),
    PRIMARY KEY (recording_id, start_ms)
);

CREATE TABLE item_replay_links (
    item_id uuid REFERENCES assessment_items,
    recording_id uuid REFERENCES recordings,
    start_ms integer CHECK (start_ms >= 0),
    PRIMARY KEY (item_id, recording_id, start_ms)
);

CREATE TABLE lesson_publications (
    session_id uuid PRIMARY KEY,
    offering_id uuid NOT NULL,
    recording_id uuid,
    transcript_version_id uuid,
    homework_assignment_id uuid,
    tutor_enabled boolean NOT NULL DEFAULT false,
    share_with_guardians boolean NOT NULL DEFAULT false,
    published_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (recording_id, session_id) REFERENCES recordings (id, session_id),
    FOREIGN KEY (transcript_version_id, recording_id) REFERENCES transcript_versions (id, recording_id),
    FOREIGN KEY (homework_assignment_id, offering_id) REFERENCES assignments (id, offering_id),
    CHECK (recording_id IS NOT NULL OR
        (transcript_version_id IS NULL AND NOT tutor_enabled AND NOT share_with_guardians)),
    CHECK (recording_id IS NOT NULL OR homework_assignment_id IS NOT NULL)
);

CREATE TABLE guardian_links (
    organization_id uuid NOT NULL,
    guardian_id uuid,
    student_id uuid,
    verified_at timestamptz NOT NULL,
    FOREIGN KEY (organization_id, guardian_id) REFERENCES organization_memberships,
    FOREIGN KEY (organization_id, student_id) REFERENCES organization_memberships,
    CHECK (guardian_id <> student_id),
    PRIMARY KEY (organization_id, guardian_id, student_id)
);

CREATE TABLE replay_progress (
    recording_id uuid,
    session_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    student_id uuid,
    watched_ms int4multirange NOT NULL DEFAULT '{}',
    last_position_ms integer NOT NULL DEFAULT 0 CHECK (last_position_ms >= 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (recording_id, session_id) REFERENCES recordings (id, session_id),
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    PRIMARY KEY (recording_id, student_id)
);

CREATE TABLE session_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    actor_id uuid,
    activity_id uuid REFERENCES lesson_activities,
    kind text NOT NULL CHECK (kind IN ('question', 'answer', 'pin', 'slide_note', 'activity_start', 'activity_end')),
    elapsed_ms integer NOT NULL CHECK (elapsed_ms >= 0),
    body text,
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (offering_id, actor_id) REFERENCES offering_memberships (offering_id, user_id)
);

CREATE INDEX session_events_timeline ON session_events (session_id, elapsed_ms);

CREATE TABLE teacher_reflections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL REFERENCES lesson_sessions,
    generated_summary jsonb,
    teacher_notes text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reflection_suggestions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reflection_id uuid NOT NULL REFERENCES teacher_reflections,
    suggestion text NOT NULL,
    applied_plan_version_id uuid REFERENCES lesson_plan_versions
);

CREATE TABLE submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id uuid NOT NULL,
    offering_id uuid NOT NULL,
    assessment_version_id uuid NOT NULL,
    student_id uuid NOT NULL,
    attempt_number integer NOT NULL CHECK (attempt_number > 0),
    started_at timestamptz NOT NULL DEFAULT now(),
    submitted_at timestamptz CHECK (submitted_at >= started_at),
    FOREIGN KEY (assignment_id, offering_id, assessment_version_id)
        REFERENCES assignments (id, offering_id, assessment_version_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    UNIQUE (assignment_id, student_id, attempt_number),
    UNIQUE (id, assessment_version_id),
    UNIQUE (id, assignment_id, student_id)
);

CREATE TABLE item_responses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id uuid NOT NULL,
    assessment_version_id uuid NOT NULL,
    item_id uuid NOT NULL,
    presented_position integer NOT NULL CHECK (presented_position > 0),
    skipped boolean NOT NULL DEFAULT false,
    FOREIGN KEY (submission_id, assessment_version_id) REFERENCES submissions (id, assessment_version_id),
    FOREIGN KEY (item_id, assessment_version_id) REFERENCES assessment_items (id, assessment_version_id),
    UNIQUE (submission_id, item_id),
    UNIQUE (submission_id, presented_position),
    UNIQUE (id, item_id)
);

CREATE TABLE response_revisions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    response_id uuid NOT NULL,
    item_id uuid NOT NULL,
    revision_number integer NOT NULL CHECK (revision_number > 0),
    answer jsonb,
    work_asset_id uuid REFERENCES assets,
    submitted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (response_id, item_id) REFERENCES item_responses (id, item_id),
    CHECK (answer IS NOT NULL OR work_asset_id IS NOT NULL),
    UNIQUE (response_id, revision_number),
    UNIQUE (id, item_id)
);

CREATE UNIQUE INDEX response_one_final_revision
    ON response_revisions (response_id) WHERE submitted_at IS NOT NULL;

CREATE TABLE response_annotations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id uuid NOT NULL REFERENCES response_revisions,
    page_number integer NOT NULL DEFAULT 1 CHECK (page_number > 0),
    selection jsonb NOT NULL,
    UNIQUE (id, revision_id)
);

CREATE TABLE grading_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id uuid NOT NULL,
    item_id uuid NOT NULL,
    source text NOT NULL CHECK (source IN ('ai', 'teacher', 'auto')),
    reviewer_id uuid REFERENCES users,
    status text NOT NULL CHECK (status IN ('draft', 'needs_review', 'accepted', 'rejected')),
    awarded_points numeric(8,2) CHECK (awarded_points >= 0),
    feedback text,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (revision_id, item_id) REFERENCES response_revisions (id, item_id),
    UNIQUE (id, item_id)
);

CREATE INDEX grading_review_queue ON grading_reviews (item_id, reviewed_at) WHERE status = 'needs_review';

CREATE TABLE criterion_scores (
    grading_review_id uuid,
    criterion_id uuid,
    item_id uuid NOT NULL,
    level_id uuid NOT NULL,
    FOREIGN KEY (grading_review_id, item_id) REFERENCES grading_reviews (id, item_id),
    FOREIGN KEY (criterion_id, item_id) REFERENCES rubric_criteria (id, item_id),
    FOREIGN KEY (level_id, criterion_id) REFERENCES rubric_levels (id, criterion_id),
    PRIMARY KEY (grading_review_id, criterion_id)
);

CREATE TABLE grade_entries (
    assignment_id uuid,
    student_id uuid,
    submission_id uuid NOT NULL,
    points numeric(8,2) NOT NULL CHECK (points >= 0),
    max_points numeric(8,2) NOT NULL CHECK (max_points >= points),
    published_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (submission_id, assignment_id, student_id) REFERENCES submissions (id, assignment_id, student_id),
    PRIMARY KEY (assignment_id, student_id)
);

CREATE TABLE participation_scores (
    session_id uuid,
    offering_id uuid NOT NULL,
    student_id uuid,
    grading_plan_item_id uuid REFERENCES grading_plan_items,
    awarded_points numeric(8,2) NOT NULL CHECK (awarded_points >= 0),
    possible_points numeric(8,2) NOT NULL CHECK (possible_points >= awarded_points),
    published_at timestamptz,
    FOREIGN KEY (session_id, offering_id) REFERENCES lesson_sessions (id, offering_id),
    FOREIGN KEY (offering_id, student_id) REFERENCES offering_memberships (offering_id, user_id),
    PRIMARY KEY (session_id, student_id, grading_plan_item_id)
);

CREATE TABLE misconceptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id uuid NOT NULL REFERENCES courses,
    code text NOT NULL,
    description text NOT NULL,
    UNIQUE (course_id, code)
);

CREATE TABLE learning_feedback (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id uuid NOT NULL REFERENCES response_revisions,
    annotation_id uuid,
    misconception_id uuid REFERENCES misconceptions,
    outcome_id uuid REFERENCES learning_outcomes,
    author_id uuid REFERENCES users,
    source text NOT NULL CHECK (source IN ('ai', 'teacher')),
    body text NOT NULL,
    visible_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (annotation_id, revision_id) REFERENCES response_annotations (id, revision_id)
);

CREATE TABLE practice_set_sources (
    assignment_id uuid,
    student_id uuid,
    feedback_id uuid REFERENCES learning_feedback,
    FOREIGN KEY (assignment_id, student_id) REFERENCES assignment_recipients,
    PRIMARY KEY (assignment_id, student_id, feedback_id)
);

CREATE TABLE ai_threads (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES users,
    mode text NOT NULL CHECK (mode IN ('replay_tutor', 'practice_tutor', 'rubric_design')),
    recording_id uuid REFERENCES recordings,
    revision_id uuid REFERENCES response_revisions,
    assessment_version_id uuid REFERENCES assessment_versions,
    CHECK (
        num_nonnulls(recording_id, revision_id, assessment_version_id) = 1
        AND ((mode = 'replay_tutor' AND recording_id IS NOT NULL)
          OR (mode = 'practice_tutor' AND revision_id IS NOT NULL)
          OR (mode = 'rubric_design' AND assessment_version_id IS NOT NULL))
    )
);

CREATE TABLE ai_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id uuid NOT NULL REFERENCES ai_threads,
    speaker text NOT NULL CHECK (speaker IN ('user', 'assistant')),
    body text NOT NULL,
    revision_id uuid REFERENCES response_revisions,
    annotation_id uuid,
    recording_offset_ms integer CHECK (recording_offset_ms >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (annotation_id IS NULL OR revision_id IS NOT NULL),
    FOREIGN KEY (annotation_id, revision_id) REFERENCES response_annotations (id, revision_id)
);

CREATE TABLE ai_message_citations (
    message_id uuid REFERENCES ai_messages,
    transcript_segment_id uuid REFERENCES transcript_segments,
    PRIMARY KEY (message_id, transcript_segment_id)
);

CREATE TABLE background_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organizations,
    kind text NOT NULL,
    idempotency_key text NOT NULL,
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'running', 'succeeded', 'failed')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    payload jsonb NOT NULL DEFAULT '{}',
    result jsonb,
    available_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organization_id, kind, idempotency_key)
);

CREATE INDEX jobs_ready ON background_jobs (available_at, id) WHERE status = 'queued';
CREATE INDEX grade_entries_student ON grade_entries (student_id, published_at);
CREATE INDEX learning_feedback_misconceptions ON learning_feedback (misconception_id, revision_id);
CREATE INDEX transcript_segments_time ON transcript_segments (transcript_version_id, start_ms);
CREATE INDEX ai_messages_order ON ai_messages (thread_id, created_at, id);

COMMIT;
