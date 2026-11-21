package syllabus

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
)

const factoringID = "core/2/1.2/2"

type plannerFunc func(context.Context, Input, []curriculum.Reference) (Plan, error)

func (f plannerFunc) Plan(ctx context.Context, input Input, references []curriculum.Reference) (Plan, error) {
	return f(ctx, input, references)
}

func termInput() Input {
	return Input{
		CourseName: "Core Mathematics", CourseCode: "ค22102", Grade: 2, CourseType: curriculum.Core,
		Term: 2, TotalSessions: 2, MinutesPerSession: 50, ReferenceIDs: []string{factoringID},
		AssessmentWeights: []Weight{{Category: "Quiz", Points: 100}},
	}
}

func factoringPlan() Plan {
	return Plan{Description: "Learn to factor polynomials.", Units: []PlannedUnit{{
		Title: "Quadratic Polynomials", ReferenceIDs: []string{factoringID},
		SessionTitles: []string{"Perfect Squares", "Difference of Squares"},
		Assessments:   []Assessment{{Title: "End-of-unit quiz", Category: "Quiz", Session: 2, Points: 100}},
	}}}
}

func TestGenerateOneTermWithExactSource(t *testing.T) {
	service := NewService(plannerFunc(func(_ context.Context, input Input, refs []curriculum.Reference) (Plan, error) {
		if input.Term != 2 || len(refs) != 1 || refs[0].Row.Outcomes[0].Code != "ค 1.2 ม.2/2" {
			t.Fatalf("unexpected curriculum sent to model: %+v", refs)
		}
		return factoringPlan(), nil
	}))
	draft, err := service.Generate(context.Background(), termInput())
	if err != nil {
		t.Fatal(err)
	}
	if draft.Term != 2 || len(draft.References) != 1 || draft.References[0].Row.PDFPage != 23 {
		t.Fatalf("unexpected draft scope: %+v", draft)
	}
	if got := draft.Units[0].Sessions[1]; got.Number != 2 || got.Title != "Difference of Squares" {
		t.Fatalf("wrong second session: %+v", got)
	}
	for _, want := range []string{"Semester 2", "Learning Outcomes", "Perfect Squares", "distributive"} {
		if !strings.Contains(strings.ToLower(draft.DocumentHTML), strings.ToLower(want)) {
			t.Errorf("document missing %q", want)
		}
	}
	for _, hidden := range []string{"Draft Course Syllabus", "Curriculum References", "PDF p.", "p. 15", "ค 1.2 ม.2/2", factoringID} {
		if strings.Contains(draft.DocumentHTML, hidden) {
			t.Errorf("document shows internal reference %q", hidden)
		}
	}
}

func TestGenerateRejectsIncompleteOrInventedPlan(t *testing.T) {
	for name, change := range map[string]func(*Plan){
		"missing reference":  func(plan *Plan) { plan.Units[0].ReferenceIDs = nil },
		"invented reference": func(plan *Plan) { plan.Units[0].ReferenceIDs[0] = "core/1/1.2/99" },
		"duplicate reference": func(plan *Plan) {
			plan.Units[0].ReferenceIDs = append(plan.Units[0].ReferenceIDs, factoringID)
		},
		"missing session":  func(plan *Plan) { plan.Units[0].SessionTitles = plan.Units[0].SessionTitles[:1] },
		"incorrect points": func(plan *Plan) { plan.Units[0].Assessments[0].Points = 99 },
	} {
		t.Run(name, func(t *testing.T) {
			service := NewService(plannerFunc(func(context.Context, Input, []curriculum.Reference) (Plan, error) {
				plan := factoringPlan()
				change(&plan)
				return plan, nil
			}))
			if _, err := service.Generate(context.Background(), termInput()); !errors.Is(err, ErrInvalidPlan) {
				t.Errorf("got %v, want invalid model plan", err)
			}
		})
	}
}

func TestGenerateRejectsOtherGradeBeforeCallingModel(t *testing.T) {
	input := termInput()
	input.ReferenceIDs = []string{"core/3/1.2/1"}
	service := NewService(plannerFunc(func(context.Context, Input, []curriculum.Reference) (Plan, error) {
		t.Fatal("invalid request reached model")
		return Plan{}, nil
	}))
	if _, err := service.Generate(context.Background(), input); !errors.Is(err, ErrInvalidInput) {
		t.Errorf("got %v, want invalid input", err)
	}
}

func TestGenerateUnitsBeforeAssessmentSetup(t *testing.T) {
	input := termInput()
	input.AssessmentWeights = nil
	service := NewService(plannerFunc(func(context.Context, Input, []curriculum.Reference) (Plan, error) {
		plan := factoringPlan()
		plan.Units[0].Assessments = nil
		return plan, nil
	}))
	draft, err := service.Generate(context.Background(), input)
	if err != nil {
		t.Fatal(err)
	}
	if len(draft.Units[0].Assessments) != 0 || strings.Contains(draft.DocumentHTML, "Assessment Weights") {
		t.Fatal("unconfigured assessment appeared in the draft")
	}
}
