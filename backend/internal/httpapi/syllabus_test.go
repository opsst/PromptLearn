package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

type termPlanner struct{}

func (termPlanner) Plan(context.Context, syllabus.Input, []curriculum.Reference) (syllabus.Plan, error) {
	return syllabus.Plan{
		Description: "Learn the properties of rational numbers.",
		Units: []syllabus.PlannedUnit{{
			Title: "Rational Numbers", ReferenceIDs: []string{"core/1/1.1/1"}, SessionTitles: []string{"Integers and Fractions"},
			Assessments: []syllabus.Assessment{{Title: "Understanding Check", Category: "Classwork", Session: 1, Points: 100}},
		}},
	}, nil
}

func TestCreateSyllabusDraft(t *testing.T) {
	request := httptest.NewRequest(http.MethodPost, "/v1/syllabi/draft", strings.NewReader(`{
		"course_name":"Core Mathematics", "grade":1, "course_type":"core", "term":1,
		"total_sessions":1, "minutes_per_session":50,
		"reference_ids":["core/1/1.1/1"], "assessment_weights":[{"category":"Classwork","points":100}]
	}`))
	response := httptest.NewRecorder()
	NewHandler(syllabus.NewService(termPlanner{}), nil).ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", response.Code, response.Body.String())
	}
	var draft syllabus.Draft
	if err := json.Unmarshal(response.Body.Bytes(), &draft); err != nil {
		t.Fatal(err)
	}
	if draft.Term != 1 || len(draft.References) != 1 || len(draft.References[0].Row.Outcomes) != 2 {
		t.Fatalf("grouped indicators were lost: %+v", draft.References)
	}
	if !strings.Contains(draft.DocumentHTML, "ค 1.1 ม.1/2") {
		t.Error("second indicator missing in document")
	}
}
