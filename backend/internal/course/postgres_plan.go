package course

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

func writeVersion(ctx context.Context, tx pgx.Tx, courseID, versionID string, preview Preview) error {
	// Preserve API-specific metadata, including source references and the edited
	// timetable. Documents can be rendered from the snapshot on demand.
	preview.Syllabus.DocumentHTML = ""
	payload, err := json.Marshal(preview)
	if err != nil {
		return err
	}
	if versionID == "" {
		err = tx.QueryRow(ctx, `
			INSERT INTO promptlearn.syllabus_versions (course_id, version_number, api_preview)
			SELECT $1::uuid, COALESCE(MAX(version_number), 0) + 1, $2::jsonb
			FROM promptlearn.syllabus_versions WHERE course_id = $1
			RETURNING id::text
		`, courseID, payload).Scan(&versionID)
		if err != nil {
			return err
		}
	} else {
		if _, err := tx.Exec(ctx, `
			UPDATE promptlearn.syllabus_versions SET api_preview = $2::jsonb, updated_at = now() WHERE id = $1
		`, versionID, payload); err != nil {
			return err
		}
		if err := clearDraftPlan(ctx, tx, versionID); err != nil {
			return err
		}
	}
	return insertPlan(ctx, tx, versionID, preview.Syllabus)
}

func clearDraftPlan(ctx context.Context, tx pgx.Tx, versionID string) error {
	for _, query := range []string{
		"DELETE FROM promptlearn.syllabus_unit_outcomes WHERE syllabus_version_id = $1",
		"DELETE FROM promptlearn.planned_periods WHERE syllabus_version_id = $1",
		"DELETE FROM promptlearn.syllabus_lessons l USING promptlearn.syllabus_units u WHERE l.unit_id = u.id AND u.syllabus_version_id = $1",
		"DELETE FROM promptlearn.syllabus_units WHERE syllabus_version_id = $1",
		"DELETE FROM promptlearn.learning_outcomes WHERE syllabus_version_id = $1",
		"DELETE FROM promptlearn.grading_plan_items WHERE syllabus_version_id = $1",
	} {
		if _, err := tx.Exec(ctx, query, versionID); err != nil {
			return err
		}
	}
	return nil
}

func insertPlan(ctx context.Context, tx pgx.Tx, versionID string, draft syllabus.Draft) error {
	outcomes, err := insertOutcomes(ctx, tx, versionID, draft)
	if err != nil {
		return err
	}

	for position, unit := range draft.Units {
		var unitID string
		err := tx.QueryRow(ctx, `
			INSERT INTO promptlearn.syllabus_units (syllabus_version_id, position, title, target_periods)
			VALUES ($1, $2, $3, $4) RETURNING id::text
		`, versionID, position+1, unit.Title, len(unit.Sessions)).Scan(&unitID)
		if err != nil {
			return err
		}
		for _, referenceID := range unit.ReferenceIDs {
			for _, outcomeID := range outcomes[referenceID] {
				if _, err := tx.Exec(ctx, `
					INSERT INTO promptlearn.syllabus_unit_outcomes (syllabus_version_id, unit_id, outcome_id)
					VALUES ($1, $2, $3)
				`, versionID, unitID, outcomeID); err != nil {
					return err
				}
			}
		}
		for index, session := range unit.Sessions {
			if _, err := tx.Exec(ctx, `
				WITH lesson AS (
					INSERT INTO promptlearn.syllabus_lessons (unit_id, position, title)
					VALUES ($2, $3, $4) RETURNING id
				)
				INSERT INTO promptlearn.planned_periods (syllabus_version_id, unit_id, lesson_id, position, kind)
				SELECT $1, $2, lesson.id, $5, 'instruction' FROM lesson
			`, versionID, unitID, index+1, session.Title, session.Number); err != nil {
				return err
			}
		}
	}

	for _, weight := range draft.AssessmentWeights {
		bucket := "during_term"
		if assessmentKind(weight.Category) == "final" {
			bucket = "final"
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO promptlearn.grading_plan_items (syllabus_version_id, name, bucket, allocated_points)
			VALUES ($1, $2, $3, $4)
		`, versionID, weight.Category, bucket, weight.Points); err != nil {
			return err
		}
	}
	return nil
}

func insertOutcomes(ctx context.Context, tx pgx.Tx, versionID string, draft syllabus.Draft) (map[string][]string, error) {
	original, err := curriculum.Math(draft.Grade, draft.CourseType)
	if err != nil {
		return nil, err
	}
	sourceText := make(map[string]string)
	for _, group := range original.Groups {
		for _, row := range group.Rows {
			for _, outcome := range row.Outcomes {
				sourceText[outcome.Code] = outcome.Text
			}
		}
	}

	byReference := make(map[string][]string, len(draft.References))
	for _, reference := range draft.References {
		for _, outcome := range reference.Row.Outcomes {
			var indicatorID string
			if outcome.Code != "" {
				err := tx.QueryRow(ctx, `
					INSERT INTO promptlearn.curriculum_indicators (curriculum_edition, code, description)
					VALUES ('OBEC Mathematics 2560', $1, $2)
					ON CONFLICT (curriculum_edition, code) DO UPDATE SET code = EXCLUDED.code
					RETURNING id::text
				`, outcome.Code, sourceText[outcome.Code]).Scan(&indicatorID)
				if err != nil {
					return nil, err
				}
			}
			var outcomeID string
			err := tx.QueryRow(ctx, `
				INSERT INTO promptlearn.learning_outcomes (syllabus_version_id, indicator_id, description)
				VALUES ($1, NULLIF($2, '')::uuid, $3) RETURNING id::text
			`, versionID, indicatorID, outcome.Text).Scan(&outcomeID)
			if err != nil {
				return nil, err
			}
			byReference[reference.Row.ID] = append(byReference[reference.Row.ID], outcomeID)
		}
	}
	return byReference, nil
}

func assessmentKind(category string) string {
	for _, word := range strings.Fields(strings.ToLower(category)) {
		switch word {
		case "final":
			return "final"
		case "midterm":
			return "midterm"
		case "quiz", "quizzes":
			return "quiz"
		}
	}
	return "other"
}
