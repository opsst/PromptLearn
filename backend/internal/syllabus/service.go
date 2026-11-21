// Package syllabus builds a draft for one term from approved curriculum rows.
package syllabus

import (
	"context"
	"errors"
	"fmt"
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
	Grade             int                   `json:"grade"`
	CourseType        curriculum.CourseType `json:"course_type"`
	Term              int                   `json:"term"`
	TotalSessions     int                   `json:"total_sessions"`
	MinutesPerSession int                   `json:"minutes_per_session"`
	ReferenceIDs      []string              `json:"reference_ids"`
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
	source, references, weights, err := prepare(input)
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
	source, references, weights, err := prepare(input)
	if err != nil {
		return Draft{}, err
	}
	plan.Mode = "manual"
	return buildDraft(input, plan, source, references, weights)
}

func prepare(input Input) (curriculum.Source, []curriculum.Reference, map[string]int, error) {
	weights, err := validateInput(input)
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

func validateInput(input Input) (map[string]int, error) {
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
		if !englishText(weight.Category) || weight.Points < 1 || weight.Points > remaining {
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
	unassigned := make(map[string]bool, len(input.ReferenceIDs))
	for _, id := range input.ReferenceIDs {
		unassigned[id] = true
	}

	sessionCount := 0
	units := make([]Unit, 0, len(plan.Units))
	for _, unit := range plan.Units {
		if !englishText(unit.Title) || len(unit.ReferenceIDs) == 0 ||
			len(unit.SessionTitles) == 0 || len(unit.SessionTitles) > input.TotalSessions-sessionCount {
			return nil, fmt.Errorf("%w: invalid unit or session count", ErrInvalidPlan)
		}

		for _, id := range unit.ReferenceIDs {
			if !unassigned[id] {
				return nil, fmt.Errorf("%w: unexpected or repeated reference %q", ErrInvalidPlan, id)
			}
			delete(unassigned, id)
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
			if !englishText(assessment.Title) || assessment.Session < 1 ||
				assessment.Session > len(sessions) || assessment.Points < 1 || assessment.Points > pointsLeft[assessment.Category] {
				return nil, fmt.Errorf("%w: invalid assessment category, points, title or session", ErrInvalidPlan)
			}
			pointsLeft[assessment.Category] -= assessment.Points
			assessment.Session += sessionCount
			assessments = append(assessments, assessment)
		}

		units = append(units, Unit{Title: unit.Title, ReferenceIDs: unit.ReferenceIDs, Sessions: sessions, Assessments: assessments})
		sessionCount += len(sessions)
	}

	if len(unassigned) != 0 || sessionCount != input.TotalSessions {
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
