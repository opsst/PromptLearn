BEGIN;
SET LOCAL search_path TO promptlearn, public;

-- One completed Check my work result for one immutable response revision.
CREATE TABLE IF NOT EXISTS assignment_work_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id uuid NOT NULL UNIQUE REFERENCES response_revisions,
    status text NOT NULL CHECK (status IN ('correct', 'needs_revision', 'unreadable')),
    engine text NOT NULL CHECK (engine IN ('mock', 'openai')),
    language text NOT NULL CHECK (language IN ('en', 'th')),
    message text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS submissions_student_history ON submissions (student_id, assignment_id);

COMMIT;
