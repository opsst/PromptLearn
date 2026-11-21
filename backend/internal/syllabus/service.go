// Package syllabus builds a draft for one term from approved curriculum rows.
package syllabus

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"
	"unicode"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
)

var (
	ErrInvalidInput = errors.New("invalid syllabus input")
	ErrInvalidPlan  = errors.New("plan does not satisfy the syllabus requirements")
)

const maxTermSessions = 1000

type Weight struct {
	Category string `json:"category"`
	Points   int    `json:"points"`
}

type Input struct {
	CourseName        string                `json:"course_name"`
	CourseCode        string                `json:"course_code"`
	Credits           *float64              `json:"credits,omitempty"`
	AcademicYear      int                   `json:"academic_year,omitempty"`
	Grade             int                   `json:"grade"`
	CourseType        curriculum.CourseType `json:"course_type"`
	Term              int                   `json:"term"`
	TotalSessions     int                   `json:"total_sessions"`
	MinutesPerSession int                   `json:"minutes_per_session"`
	ReferenceIDs      []string              `json:"reference_ids"`
	CustomReferences  []string              `json:"custom_references,omitempty"`
	AssessmentWeights []Weight              `json:"assessment_weights"`
}

type Assessment struct {
	Title    string `json:"title"`
	Category string `json:"category"`
	Session  int    `json:"session"`
	Points   int    `json:"points"`
}

type PlannedUnit struct {
	Title         string       `json:"title"`
	ReferenceIDs  []string     `json:"reference_ids"`
	SessionTitles []string     `json:"session_titles"`
	Assessments   []Assessment `json:"assessments"`
}

type Plan struct {
	Mode        string        `json:"-"`
	Description string        `json:"description"`
	Units       []PlannedUnit `json:"units"`
}

type Session struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
}

type Unit struct {
	Title        string       `json:"title"`
	ReferenceIDs []string     `json:"reference_ids"`
	Sessions     []Session    `json:"sessions"`
	Assessments  []Assessment `json:"assessments"`
}

type Draft struct {
	Input
	PlanningMode string                 `json:"planning_mode,omitempty"`
	Source       curriculum.Source      `json:"source"`
	References   []curriculum.Reference `json:"references"`
	Description  string                 `json:"description"`
	Units        []Unit                 `json:"units"`
	DocumentHTML string                 `json:"document_html"`
}

type Planner interface {
	Plan(context.Context, Input, []curriculum.Reference) (Plan, error)
}

type Service struct {
	planner Planner
}

func NewService(planner Planner) *Service {
	return &Service{planner: planner}
}

func (s *Service) Generate(ctx context.Context, input Input) (Draft, error) {
	if len(input.CustomReferences) != 0 {
		return Draft{}, fmt.Errorf("%w: custom references require an edited plan", ErrInvalidInput)
	}
	source, references, weights, err := prepare(input, false)
	if err != nil {
		return Draft{}, err
	}

	plan, err := s.planner.Plan(ctx, input, references)
	if err != nil {
		return Draft{}, fmt.Errorf("plan syllabus: %w", err)
	}
	return buildDraft(input, plan, source, references, weights)
}

// Compose validates a teacher-edited plan and attaches its source references.
func Compose(input Input, plan Plan) (Draft, error) {
	source, references, weights, err := prepare(input, true)
	if err != nil {
		return Draft{}, err
	}
	plan.Mode = "manual"
	return buildDraft(input, plan, source, references, weights)
}

func prepare(input Input, manual bool) (curriculum.Source, []curriculum.Reference, map[string]int, error) {
	weights, err := validateInput(input, manual)
	if err != nil {
		return curriculum.Source{}, nil, nil, err
	}
	selection, err := curriculum.Math(input.Grade, input.CourseType)
	if errors.Is(err, curriculum.ErrUnsupportedCourse) {
		return curriculum.Source{}, nil, nil, fmt.Errorf("%w: %s", ErrInvalidInput, err)
	}
	if err != nil {
		return curriculum.Source{}, nil, nil, err
	}
	if len(input.CustomReferences) != 0 {
		references, err := teacherReferences(input)
		return curriculum.Source{Title: "Teacher-provided learning standards"}, references, weights, err
	}
	references, err := selectReferences(selection, input.ReferenceIDs)
	return curriculum.EnglishSource(selection.Source), references, weights, err
}

func buildDraft(input Input, plan Plan, source curriculum.Source, references []curriculum.Reference, weights map[string]int) (Draft, error) {
	units, err := validatePlan(plan, input, weights)
	if err != nil {
		return Draft{}, err
	}

	draft := Draft{
		Input: input, PlanningMode: plan.Mode, Source: source, References: references,
		Description: plan.Description, Units: units,
	}
	draft.DocumentHTML, err = RenderDocument(draft, nil)
	return draft, err
}

func validateInput(input Input, manual bool) (map[string]int, error) {
	if input.Credits != nil {
		credits := *input.Credits
		if math.IsNaN(credits) || credits < 0 || credits > 999.99 || math.Abs(math.Round(credits*100)-credits*100) > 1e-7 {
			return nil, fmt.Errorf("%w: credits must be between 0 and 999.99 with at most two decimals", ErrInvalidInput)
		}
	}
	if input.AcademicYear != 0 && (input.AcademicYear < 2000 || input.AcademicYear > 2100) {
		return nil, fmt.Errorf("%w: academic_year must be a Gregorian year from 2000 to 2100", ErrInvalidInput)
	}
	if input.Term != 1 && input.Term != 2 {
		return nil, fmt.Errorf("%w: term must be 1 or 2", ErrInvalidInput)
	}
	if !englishText(input.CourseName) || input.TotalSessions < 1 || input.MinutesPerSession < 1 || input.MinutesPerSession >= 24*60 {
		return nil, fmt.Errorf("%w: provide course_name in English, positive total_sessions, and minutes_per_session from 1 to 1439", ErrInvalidInput)
	}
	if input.TotalSessions > maxTermSessions {
		return nil, fmt.Errorf("%w: total_sessions must be at most %d", ErrInvalidInput, maxTermSessions)
	}
	if len(input.ReferenceIDs) == 0 {
		return nil, fmt.Errorf("%w: select at least one curriculum reference", ErrInvalidInput)
	}

	weights := make(map[string]int, len(input.AssessmentWeights))
	if len(input.AssessmentWeights) == 0 {
		return weights, nil
	}
	remaining := 100
	for _, weight := range input.AssessmentWeights {
		if !englishText(weight.Category) || weight.Points < 0 || (!manual && weight.Points == 0) || weight.Points > remaining {
			return nil, fmt.Errorf("%w: assessment weights must have English names and sum to 100", ErrInvalidInput)
		}
		if _, duplicate := weights[weight.Category]; duplicate {
			return nil, fmt.Errorf("%w: duplicate assessment category %q", ErrInvalidInput, weight.Category)
		}
		weights[weight.Category] = weight.Points
		remaining -= weight.Points
	}
	if remaining != 0 {
		return nil, fmt.Errorf("%w: assessment weights must sum to 100", ErrInvalidInput)
	}
	return weights, nil
}

func teacherReferences(input Input) ([]curriculum.Reference, error) {
	if len(input.CustomReferences) != len(input.ReferenceIDs) {
		return nil, fmt.Errorf("%w: select each custom reference using its custom/N ID", ErrInvalidInput)
	}
	refs := make([]curriculum.Reference, 0, len(input.CustomReferences))
	for i, description := range input.CustomReferences {
		id := fmt.Sprintf("custom/%d", i+1)
		if input.ReferenceIDs[i] != id || !englishText(description) {
			return nil, fmt.Errorf("%w: custom references need English text and sequential custom/N IDs", ErrInvalidInput)
		}
		refs = append(refs, curriculum.Reference{Strand: "Custom standards", Row: curriculum.Row{
			ID: id, Grade: input.Grade, Title: description, Content: []string{description},
			Outcomes: []curriculum.Outcome{{Number: 1, Text: description}},
		}})
	}
	return refs, nil
}

func selectReferences(source curriculum.Selection, ids []string) ([]curriculum.Reference, error) {
	available := make(map[string]curriculum.Reference)
	for _, group := range source.Groups {
		for _, row := range group.Rows {
			available[row.ID] = curriculum.Reference{
				Strand: group.Strand, StandardCode: group.StandardCode,
				ObjectiveNumber: group.ObjectiveNumber, Statement: group.Statement, Row: row,
			}
		}
	}

	selected := make([]curriculum.Reference, 0, len(ids))
	for _, id := range ids {
		reference, exists := available[id]
		if !exists {
			return nil, fmt.Errorf("%w: unknown or repeated reference %q for this grade and course type", ErrInvalidInput, id)
		}
		delete(available, id)
		translated, err := curriculum.EnglishReference(reference)
		if err != nil {
			return nil, err
		}
		selected = append(selected, translated)
	}
	return selected, nil
}

func validatePlan(plan Plan, input Input, pointsLeft map[string]int) ([]Unit, error) {
	if !englishText(plan.Description) || len(plan.Units) == 0 {
		return nil, fmt.Errorf("%w: missing English course description or units", ErrInvalidPlan)
	}
	claimed := make(map[string]bool, len(input.ReferenceIDs))
	for _, id := range input.ReferenceIDs {
		claimed[id] = false
	}
	manual := plan.Mode == "manual"

	sessionCount := 0
	units := make([]Unit, 0, len(plan.Units))
	for _, unit := range plan.Units {
		if !englishText(unit.Title) || len(unit.ReferenceIDs) == 0 ||
			len(unit.SessionTitles) == 0 || len(unit.SessionTitles) > input.TotalSessions-sessionCount {
			return nil, fmt.Errorf("%w: invalid unit or session count", ErrInvalidPlan)
		}

		unitReferences := make(map[string]bool, len(unit.ReferenceIDs))
		for _, id := range unit.ReferenceIDs {
			used, exists := claimed[id]
			if !exists || unitReferences[id] || (used && !manual) {
				return nil, fmt.Errorf("%w: unexpected or repeated reference %q", ErrInvalidPlan, id)
			}
			unitReferences[id] = true
			claimed[id] = true
		}

		sessions := make([]Session, len(unit.SessionTitles))
		for i, title := range unit.SessionTitles {
			if !englishText(title) {
				return nil, fmt.Errorf("%w: each period needs an English title", ErrInvalidPlan)
			}
			sessions[i] = Session{Number: sessionCount + i + 1, Title: title}
		}

		assessments := make([]Assessment, 0, len(unit.Assessments))
		for _, assessment := range unit.Assessments {
			unscheduled := manual && assessment.Session == 0
			if !englishText(assessment.Title) || (assessment.Session < 1 && !unscheduled) ||
				assessment.Session > len(sessions) || assessment.Points < 1 || assessment.Points > pointsLeft[assessment.Category] {
				return nil, fmt.Errorf("%w: invalid assessment category, points, title or session", ErrInvalidPlan)
			}
			pointsLeft[assessment.Category] -= assessment.Points
			if !unscheduled {
				assessment.Session += sessionCount
			}
			assessments = append(assessments, assessment)
		}

		units = append(units, Unit{Title: unit.Title, ReferenceIDs: unit.ReferenceIDs, Sessions: sessions, Assessments: assessments})
		sessionCount += len(sessions)
	}

	for _, assigned := range claimed {
		if !assigned {
			return nil, fmt.Errorf("%w: some references or sessions are unassigned", ErrInvalidPlan)
		}
	}
	if sessionCount != input.TotalSessions {
		return nil, fmt.Errorf("%w: some references or sessions are unassigned", ErrInvalidPlan)
	}
	for _, remaining := range pointsLeft {
		if remaining != 0 {
			return nil, fmt.Errorf("%w: points are missing from an assessment category", ErrInvalidPlan)
		}
	}
	return units, nil
}

func englishText(value string) bool {
	return strings.TrimSpace(value) != "" && !strings.ContainsFunc(value, func(r rune) bool {
		return unicode.Is(unicode.Thai, r)
	})
}
