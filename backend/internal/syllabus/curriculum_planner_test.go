package syllabus

import (
	"context"
	"strings"
	"testing"
)

func TestCurriculumPlannerIncludesEveryFactoringTopic(t *testing.T) {
	draft, err := NewService(CurriculumPlanner{}).Generate(context.Background(), termInput())
	if err != nil {
		t.Fatal(err)
	}
	if draft.PlanningMode != "curriculum" || len(draft.Units) != 1 {
		t.Fatalf("wrong draft: %+v", draft.Units)
	}
	var titles strings.Builder
	for _, session := range draft.Units[0].Sessions {
		titles.WriteString(session.Title)
	}
	for _, want := range []string{"distributive", "perfect square", "difference of squares"} {
		if !strings.Contains(strings.ToLower(titles.String()), want) {
			t.Errorf("session topics omit %q", want)
		}
	}
}
