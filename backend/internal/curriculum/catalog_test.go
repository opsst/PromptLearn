package curriculum

import (
	"strings"
	"testing"
)

func TestMathCoverage(t *testing.T) {
	counts := []struct {
		grade int
		kind  CourseType
		want  int
	}{
		{1, Core, 9}, {2, Core, 12}, {3, Core, 12},
		{4, Core, 3}, {5, Core, 4}, {6, Core, 1},
		{4, Additional, 11}, {5, Additional, 13}, {6, Additional, 8},
	}

	for _, tc := range counts {
		result, err := Math(tc.grade, tc.kind)
		if err != nil {
			t.Fatalf("grade %d %s: %v", tc.grade, tc.kind, err)
		}
		n := 0
		seen := map[string]bool{}
		for _, group := range result.Groups {
			for _, row := range group.Rows {
				n += len(row.Outcomes)
				if row.Title == "" || len(row.Content) == 0 || row.PrintedPage != row.PDFPage-8 {
					t.Fatalf("invalid source row: %+v", row)
				}
				for _, outcome := range row.Outcomes {
					if tc.kind == Core && (outcome.Code == "" || seen[outcome.Code]) {
						t.Fatalf("missing or duplicate code: %+v", outcome)
					}
					if tc.kind == Additional && outcome.Code != "" {
						t.Fatalf("unexpected core code for additional outcome: %+v", outcome)
					}
					seen[outcome.Code] = true
				}
			}
		}
		if n != tc.want {
			t.Errorf("grade %d %s outcomes = %d, want %d", tc.grade, tc.kind, n, tc.want)
		}
	}
}

func TestMathQuadraticFactoring(t *testing.T) {
	result, err := Math(2, Core)
	if err != nil {
		t.Fatal(err)
	}
	for _, group := range result.Groups {
		for _, row := range group.Rows {
			if row.Outcomes[0].Code == "ค 1.2 ม.2/2" {
				body := strings.Join(row.Content, "\n")
				if row.PDFPage != 23 || row.Title != "การแยกตัวประกอบของพหุนาม" {
					t.Fatalf("wrong source row: %+v", row)
				}
				for _, topic := range []string{"สมบัติการแจกแจง", "กำลังสองสมบูรณ์", "ผลต่างของกำลังสอง"} {
					if !strings.Contains(body, topic) {
						t.Errorf("missing source topic %q", topic)
					}
				}
				return
			}
		}
	}
	t.Fatal("indicator ค 1.2 ม.2/2 missing")
}
