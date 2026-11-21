BEGIN;
SET LOCAL search_path TO promptlearn, public;

-- Preserve the API's versioned draft, timetable and display metadata.
ALTER TABLE syllabus_versions ADD COLUMN IF NOT EXISTS api_preview jsonb;

-- Inferred dates can expand as more demo courses are published.
ALTER TABLE academic_terms ADD COLUMN IF NOT EXISTS syllabus_demo_inferred boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS learning_outcomes_id_version
    ON learning_outcomes (id, syllabus_version_id);

CREATE TABLE IF NOT EXISTS syllabus_unit_outcomes (
    syllabus_version_id uuid NOT NULL,
    unit_id uuid NOT NULL,
    outcome_id uuid NOT NULL,
    FOREIGN KEY (unit_id, syllabus_version_id) REFERENCES syllabus_units (id, syllabus_version_id),
    FOREIGN KEY (outcome_id, syllabus_version_id) REFERENCES learning_outcomes (id, syllabus_version_id),
    PRIMARY KEY (unit_id, outcome_id)
);
COMMIT;
