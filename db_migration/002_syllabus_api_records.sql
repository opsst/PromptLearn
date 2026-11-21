BEGIN;

CREATE TABLE promptlearn.syllabus_api_records (
    id text PRIMARY KEY CHECK (id ~ '^[0-9a-fA-F]{32}$'),
    draft jsonb NOT NULL CHECK (
        jsonb_typeof(draft) = 'object' AND coalesce(draft->>'id' = id, false)
    ),
    published jsonb CHECK (
        published IS NULL OR (
            jsonb_typeof(published) = 'object' AND coalesce(published->>'id' = id, false)
        )
    ),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMIT;
