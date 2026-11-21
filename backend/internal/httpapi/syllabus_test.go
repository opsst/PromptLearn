package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/curriculum"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

func TestTeacherWizardPreservesEditedSyllabus(t *testing.T) {
	store, err := course.OpenStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	handler := NewHandler(syllabus.NewService(termPlanner{}), store)
	request := `{
		"course":{"course_name":"Core Mathematics","course_code":"ค21101","grade":1,"course_type":"core","term":1,"credits":1.5,"academic_year":2026,
		"total_sessions":2,"minutes_per_session":50,"reference_ids":["core/1/1.1/1"],"assessment_weights":[{"category":"Unit quizzes","points":25},{"category":"Final exam","points":75}]},
		"plan":{"description":"Compare integers and fractions.","units":[
		{"title":"Integers","reference_ids":["core/1/1.1/1"],"session_titles":["Compare integers"],"assessments":[{"title":"Unit 1 quiz","category":"Unit quizzes","session":1,"points":25}]},
		{"title":"Fractions","reference_ids":["core/1/1.1/1"],"session_titles":["Compare fractions"],"assessments":[{"title":"Final exam","category":"Final exam","session":0,"points":75}]}]},
		"timetable":{"start_date":"2026-05-18","end_date":"2026-06-01","classes":[{"id":"M.1/1","student_count":32,"slots":[{"weekday":1,"start_time":"09:00","period_number":2}],"session_order":[2,0,1]}]},
		"settings":{"teaching_approaches":["inquiry"],"student_details":["topics"],"teaching_notes":"Private teacher notes","textbook":{"title":"Math M.1 Book 1","pages":214,"chapters":["Integers","Fractions"]}}
	}`
	do := func(method, path, body string, want int) []byte {
		t.Helper()
		res := httptest.NewRecorder()
		handler.ServeHTTP(res, httptest.NewRequest(method, path, strings.NewReader(body)))
		if res.Code != want {
			t.Fatalf("%s %s = %d: %s", method, path, res.Code, res.Body.String())
		}
		return res.Body.Bytes()
	}
	var saved course.Saved
	if err := json.Unmarshal(do(http.MethodPost, "/v1/syllabi", request, 201), &saved); err != nil {
		t.Fatal(err)
	}
	body := string(do(http.MethodGet, "/v1/syllabi/"+saved.ID, "", 200))
	for _, want := range []string{`"credits":1.5`, `"academic_year":2026`, `"student_count":32`, `"period_number":2`, `"session_order":[2,0,1]`, `"teaching_approaches":["inquiry"]`, "Math M.1 Book 1", "Private teacher notes"} {
		if !strings.Contains(body, want) {
			t.Errorf("saved response lost %s", want)
		}
	}
	meetings := saved.Schedule.Classes[0].Meetings
	if len(meetings) != 2 || meetings[0].Session != 2 || meetings[1].Date != "2026-06-01" || len(meetings[0].Assessments) != 0 {
		t.Fatalf("edited schedule or assessment dates were lost: %+v", meetings)
	}
	do(http.MethodPost, "/v1/syllabi/"+saved.ID+"/publish", "", 200)
	published := string(do(http.MethodGet, "/v1/published-syllabi/"+saved.ID, "", 200))
	if strings.Contains(published, "Private teacher notes") || strings.Contains(published, "Unit 1 quiz") || !strings.Contains(published, "Compare fractions") {
		t.Fatalf("student visibility was not applied: %s", published)
	}
}

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
	second := draft.References[0].Row.Outcomes[1]
	if second.Code != "ค 1.1 ม.1/2" || !strings.Contains(draft.DocumentHTML, second.Text) {
		t.Error("second learning outcome or its API reference is missing")
	}
	if strings.Contains(draft.DocumentHTML, second.Code) {
		t.Error("indicator code should stay in the JSON references")
	}
}
