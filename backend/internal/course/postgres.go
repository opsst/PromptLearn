package course

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/opsst/PromptLearn/backend/internal/database"
)

const (
	demoOrganization = "a1000000-0000-4000-8000-000000000001"
	demoTeacher      = "a1000000-0000-4000-8000-000000000002"
)

var ErrTeachingStarted = errors.New("an earlier syllabus version already has a started teaching session")

// PostgresStore stores syllabus revisions for the configured demo organization.
type PostgresStore struct {
	db *pgxpool.Pool
}

type rowQuery interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

type storedVersion struct {
	id    string
	saved Saved
}

func OpenPostgresDemo(ctx context.Context, databaseURL string) (*PostgresStore, error) {
	db, err := database.OpenPostgres(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	var ready bool
	err = db.QueryRow(ctx, `
		SELECT to_regclass('promptlearn.syllabus_unit_outcomes') IS NOT NULL
		  AND EXISTS (SELECT 1 FROM promptlearn.organization_memberships WHERE organization_id = $1 AND user_id = $2)
	`, demoOrganization, demoTeacher).Scan(&ready)
	if err != nil || !ready {
		db.Close()
		return nil, errors.New("apply db_migration/course_syllabus.sql and demo_seed.sql before enabling PostgreSQL syllabus storage")
	}
	return &PostgresStore{db: db}, nil
}

func (s *PostgresStore) Close() { s.db.Close() }

func (s *PostgresStore) Create(ctx context.Context, preview Preview) (Saved, error) {
	var saved Saved
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		draft := preview.Syllabus
		var courseID string
		err := tx.QueryRow(ctx, `
			INSERT INTO promptlearn.courses (organization_id, subject_code, title, grade_level, credits)
			VALUES ($1, $2, $3, $4, 0) RETURNING id::text
		`, demoOrganization, draft.CourseCode, draft.CourseName, gradeLabel(draft.Grade)).Scan(&courseID)
		if err != nil {
			return err
		}
		if err := writeVersion(ctx, tx, courseID, "", preview); err != nil {
			return err
		}
		saved = Saved{ID: strings.ReplaceAll(courseID, "-", ""), Status: "draft", Preview: preview}
		return nil
	})
	return saved, err
}

func (s *PostgresStore) Get(ctx context.Context, id string) (Saved, error) {
	current, err := readVersion(ctx, s.db, id, false)
	if err != nil {
		return Saved{}, err
	}
	err = restoreHTML(&current.saved.Preview)
	return current.saved, err
}

func (s *PostgresStore) Update(ctx context.Context, id string, preview Preview) (Saved, error) {
	var saved Saved
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if err := lockCourse(ctx, tx, id); err != nil {
			return err
		}
		current, err := readVersion(ctx, tx, id, false)
		if err != nil {
			return err
		}
		target, status := current.id, current.saved.Status
		if status == "published" {
			target, status = "", "unpublished_changes"
		}
		if err := writeVersion(ctx, tx, id, target, preview); err != nil {
			return err
		}
		saved = Saved{ID: id, Status: status, Preview: preview}
		return nil
	})
	return saved, err
}

func (s *PostgresStore) Publish(ctx context.Context, id string) (Saved, error) {
	var saved Saved
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if err := lockCourse(ctx, tx, id); err != nil {
			return err
		}
		current, err := readVersion(ctx, tx, id, false)
		if err != nil {
			return err
		}
		saved = current.saved
		if saved.Status == "published" {
			return nil
		}
		if saved.Schedule == nil || saved.Timetable == nil || len(saved.Syllabus.AssessmentWeights) == 0 {
			return ErrNotReady
		}
		if err := publishCalendar(ctx, tx, id, current.id, saved.Preview); err != nil {
			return err
		}
		draft := saved.Syllabus
		if _, err := tx.Exec(ctx, `
			UPDATE promptlearn.courses SET subject_code = $2, title = $3, grade_level = $4 WHERE id = $1
		`, id, draft.CourseCode, draft.CourseName, gradeLabel(draft.Grade)); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `
			UPDATE promptlearn.syllabus_versions SET published_at = now(), updated_at = now() WHERE id = $1
		`, current.id); err != nil {
			return err
		}
		saved.Status = "published"
		return nil
	})
	if err == nil {
		err = restoreHTML(&saved.Preview)
	}
	return saved, err
}

func (s *PostgresStore) StudentView(ctx context.Context, id string) (StudentView, error) {
	current, err := readVersion(ctx, s.db, id, true)
	if err != nil {
		return StudentView{}, err
	}
	return publishedView(current.saved), nil
}

func readVersion(ctx context.Context, db rowQuery, id string, publishedOnly bool) (storedVersion, error) {
	if !validCourseID(id) {
		return storedVersion{}, ErrNotFound
	}
	var version storedVersion
	var preview []byte
	var published, hasPublication bool
	err := db.QueryRow(ctx, `
		SELECT v.id::text, v.api_preview, v.published_at IS NOT NULL, EXISTS (
			SELECT 1 FROM promptlearn.syllabus_versions p
			WHERE p.course_id = v.course_id AND p.api_preview IS NOT NULL AND p.published_at IS NOT NULL
		)
		FROM promptlearn.syllabus_versions v
		JOIN promptlearn.courses c ON c.id = v.course_id
		WHERE c.id = $1 AND c.organization_id = $2 AND v.api_preview IS NOT NULL
		  AND (NOT $3 OR EXISTS (
			SELECT 1 FROM promptlearn.offering_syllabus_publications p
			WHERE p.syllabus_version_id = v.id AND p.superseded_at IS NULL
		  ))
		ORDER BY v.version_number DESC LIMIT 1
	`, id, demoOrganization, publishedOnly).Scan(&version.id, &preview, &published, &hasPublication)
	if errors.Is(err, pgx.ErrNoRows) {
		return storedVersion{}, ErrNotFound
	}
	if err != nil {
		return storedVersion{}, err
	}
	version.saved.ID = id
	version.saved.Status = "draft"
	if published {
		version.saved.Status = "published"
	} else if hasPublication {
		version.saved.Status = "unpublished_changes"
	}
	err = json.Unmarshal(preview, &version.saved.Preview)
	return version, err
}

func lockCourse(ctx context.Context, tx pgx.Tx, id string) error {
	if !validCourseID(id) {
		return ErrNotFound
	}
	var locked string
	err := tx.QueryRow(ctx, `
		SELECT id::text FROM promptlearn.courses WHERE id = $1 AND organization_id = $2 FOR UPDATE
	`, id, demoOrganization).Scan(&locked)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

func validCourseID(id string) bool {
	_, err := hex.DecodeString(id)
	return len(id) == 32 && err == nil
}

func gradeLabel(grade int) string { return fmt.Sprintf("ม.%d", grade) }
