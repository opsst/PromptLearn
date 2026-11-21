package course

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

func publishCalendar(ctx context.Context, tx pgx.Tx, courseID, versionID string, preview Preview) error {
	var started bool
	err := tx.QueryRow(ctx, `
		WITH current_sessions AS (
			SELECT s.status, s.actual_start
			FROM promptlearn.lesson_sessions s
			JOIN promptlearn.offering_syllabus_publications p
			  ON p.offering_id = s.offering_id AND p.syllabus_version_id = s.syllabus_version_id
			WHERE p.course_id = $1 AND p.superseded_at IS NULL
			ORDER BY s.id
			FOR UPDATE OF s
		)
		SELECT COALESCE(bool_or(actual_start IS NOT NULL OR status IN ('in_progress', 'completed')), false)
		FROM current_sessions
	`, courseID).Scan(&started)
	if err != nil {
		return err
	}
	if started {
		return ErrTeachingStarted
	}

	for _, query := range []string{
		`UPDATE promptlearn.lesson_sessions s SET status = 'cancelled'
		 FROM promptlearn.offering_syllabus_publications p
		 WHERE p.course_id = $1 AND p.superseded_at IS NULL AND s.status = 'scheduled'
		   AND s.offering_id = p.offering_id AND s.syllabus_version_id = p.syllabus_version_id`,
		`DELETE FROM promptlearn.weekly_timetable_slots w USING promptlearn.offering_syllabus_publications p
		 WHERE p.course_id = $1 AND p.superseded_at IS NULL AND w.offering_id = p.offering_id`,
		"UPDATE promptlearn.offering_syllabus_publications SET superseded_at = now() WHERE course_id = $1 AND superseded_at IS NULL",
	} {
		if _, err := tx.Exec(ctx, query, courseID); err != nil {
			return err
		}
	}

	termID, err := findTerm(ctx, tx, preview.Syllabus.Term, *preview.Timetable)
	if err != nil {
		return err
	}
	location, err := time.LoadLocation(preview.Schedule.Timezone)
	if err != nil {
		return err
	}
	timetableClasses := make(map[string]teaching.Class, len(preview.Timetable.Classes))
	for _, class := range preview.Timetable.Classes {
		timetableClasses[class.ID] = class
	}

	classes := slices.Clone(preview.Schedule.Classes)
	slices.SortFunc(classes, func(a, b teaching.ClassSchedule) int { return strings.Compare(a.ClassID, b.ClassID) })
	for _, class := range classes {
		offeringID, err := writeOffering(ctx, tx, courseID, termID, gradeLabel(preview.Syllabus.Grade), class.ClassID, *preview.Timetable)
		if err != nil {
			return err
		}
		if err := writeSlots(ctx, tx, offeringID, timetableClasses[class.ClassID].Slots, preview.Syllabus.MinutesPerSession); err != nil {
			return err
		}
		for _, meeting := range class.Meetings {
			if err := writeMeeting(ctx, tx, location, courseID, versionID, offeringID, meeting); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO promptlearn.offering_syllabus_publications (offering_id, course_id, syllabus_version_id)
			VALUES ($1, $2, $3)
		`, offeringID, courseID, versionID); err != nil {
			return err
		}
	}
	return nil
}

func findTerm(ctx context.Context, tx pgx.Tx, semester int, timetable teaching.Timetable) (string, error) {
	var termID string
	err := tx.QueryRow(ctx, `
		SELECT id::text FROM promptlearn.academic_terms
		WHERE organization_id = $1 AND semester = $2 AND starts_on <= $3::date AND ends_on >= $4::date
		ORDER BY starts_on DESC LIMIT 1
	`, demoOrganization, semester, timetable.StartDate, timetable.EndDate).Scan(&termID)
	if !errors.Is(err, pgx.ErrNoRows) {
		return termID, err
	}

	start, err := time.Parse(time.DateOnly, timetable.StartDate)
	if err != nil {
		return "", err
	}
	year := start.Year() + 543
	if semester == 2 && start.Month() < time.May {
		year--
	}
	err = tx.QueryRow(ctx, `
		INSERT INTO promptlearn.academic_terms (organization_id, academic_year, semester, starts_on, ends_on, syllabus_demo_inferred)
		VALUES ($1, $2, $3, $4::date, $5::date, true)
		ON CONFLICT (organization_id, academic_year, semester) DO UPDATE
		SET starts_on = LEAST(academic_terms.starts_on, EXCLUDED.starts_on),
		    ends_on = GREATEST(academic_terms.ends_on, EXCLUDED.ends_on)
		WHERE academic_terms.syllabus_demo_inferred OR
		      (academic_terms.starts_on <= EXCLUDED.starts_on AND academic_terms.ends_on >= EXCLUDED.ends_on)
		RETURNING id::text
	`, demoOrganization, year, semester, timetable.StartDate, timetable.EndDate).Scan(&termID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", fmt.Errorf("%w: teaching dates are outside the configured academic term", teaching.ErrInvalidTimetable)
	}
	return termID, err
}

func writeOffering(ctx context.Context, tx pgx.Tx, courseID, termID, grade, class string, timetable teaching.Timetable) (string, error) {
	var offeringID string
	err := tx.QueryRow(ctx, `
		WITH section AS (
			INSERT INTO promptlearn.class_sections (term_id, organization_id, grade_level, name)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (term_id, grade_level, name) DO UPDATE SET name = EXCLUDED.name
			RETURNING id
		)
		INSERT INTO promptlearn.course_offerings (organization_id, course_id, class_section_id, first_teaching_day, last_teaching_day)
		SELECT $2, $5, id, $6::date, $7::date FROM section
		ON CONFLICT (course_id, class_section_id) DO UPDATE
		SET first_teaching_day = EXCLUDED.first_teaching_day, last_teaching_day = EXCLUDED.last_teaching_day
		RETURNING id::text
	`, termID, demoOrganization, grade, class, courseID, timetable.StartDate, timetable.EndDate).Scan(&offeringID)
	if err != nil {
		return "", err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO promptlearn.offering_memberships (offering_id, organization_id, user_id, role)
		VALUES ($1, $2, $3, 'teacher') ON CONFLICT (offering_id, user_id) DO NOTHING
	`, offeringID, demoOrganization, demoTeacher)
	return offeringID, err
}

func writeSlots(ctx context.Context, tx pgx.Tx, offeringID string, slots []teaching.Slot, duration int) error {
	type weeklySlot struct {
		weekday int
		start   time.Time
	}
	ordered := make([]weeklySlot, 0, len(slots))
	for _, slot := range slots {
		start, err := time.Parse("15:04", slot.StartTime)
		if err != nil {
			return err
		}
		ordered = append(ordered, weeklySlot{weekday: slot.Weekday, start: start})
	}
	slices.SortFunc(ordered, func(a, b weeklySlot) int {
		if a.weekday != b.weekday {
			return a.weekday - b.weekday
		}
		return a.start.Compare(b.start)
	})
	lastWeekday, period := 0, 0
	for _, slot := range ordered {
		if slot.weekday != lastWeekday {
			lastWeekday, period = slot.weekday, 0
		}
		period++
		end := slot.start.Add(time.Duration(duration) * time.Minute)
		if _, err := tx.Exec(ctx, `
			INSERT INTO promptlearn.weekly_timetable_slots (offering_id, organization_id, weekday, period_number, local_starts_at, local_ends_at)
			VALUES ($1, $2, $3, $4, $5::time, $6::time)
		`, offeringID, demoOrganization, slot.weekday, period, slot.start.Format("15:04"), end.Format("15:04")); err != nil {
			return err
		}
	}
	return nil
}

func writeMeeting(ctx context.Context, tx pgx.Tx, location *time.Location, courseID, versionID, offeringID string, meeting teaching.Meeting) error {
	const format = time.DateOnly + " 15:04"
	start, err := time.ParseInLocation(format, meeting.Date+" "+meeting.StartTime, location)
	if err != nil {
		return err
	}
	end, err := time.ParseInLocation(format, meeting.Date+" "+meeting.EndTime, location)
	if err != nil {
		return err
	}
	var sessionID, unitID string
	err = tx.QueryRow(ctx, `
		WITH session AS (
			INSERT INTO promptlearn.lesson_sessions (offering_id, course_id, syllabus_version_id, planned_period_id, scheduled_start, scheduled_end)
			SELECT $1, $2, $3, p.id, $5, $6 FROM promptlearn.planned_periods p
			WHERE p.syllabus_version_id = $3 AND p.position = $4
			RETURNING id, planned_period_id
		)
		SELECT session.id::text, p.unit_id::text FROM session
		JOIN promptlearn.planned_periods p ON p.id = session.planned_period_id
	`, offeringID, courseID, versionID, meeting.Session, start, end).Scan(&sessionID, &unitID)
	if err != nil {
		return err
	}
	for _, assessment := range meeting.Assessments {
		command, err := tx.Exec(ctx, `
			WITH event AS (
				INSERT INTO promptlearn.assessment_events
					(offering_id, course_id, syllabus_version_id, grading_plan_item_id, lesson_session_id, title, event_kind, starts_at, planned_points)
				SELECT $1, $2, $3, g.id, $4, $5, $6, $7, $8 FROM promptlearn.grading_plan_items g
				WHERE g.syllabus_version_id = $3 AND g.name = $9
				RETURNING id
			)
			INSERT INTO promptlearn.assessment_event_units (assessment_event_id, syllabus_version_id, unit_id)
			SELECT id, $3, $10 FROM event
		`, offeringID, courseID, versionID, sessionID, assessment.Title, assessmentKind(assessment.Category),
			start, assessment.Points, assessment.Category, unitID)
		if err != nil {
			return err
		}
		if command.RowsAffected() != 1 {
			return fmt.Errorf("assessment references a missing grading category %q", assessment.Category)
		}
	}
	return nil
}
