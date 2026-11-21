package teaching

import (
	"errors"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

func TestPlaceSkipsHolidaysAndPlacesAssessmentPerClass(t *testing.T) {
	timetable := Timetable{
		StartDate: "2026-05-18", EndDate: "2026-06-02", ExcludedDates: []string{"2026-05-25"},
		Classes: []Class{
			{ID: "m2-1", Slots: []Slot{{Weekday: 1, StartTime: "09:00"}}},
			{ID: "m2-2", Slots: []Slot{{Weekday: 2, StartTime: "10:00"}}},
		},
	}
	draft := syllabus.Draft{
		Input: syllabus.Input{TotalSessions: 2, MinutesPerSession: 50},
		Units: []syllabus.Unit{{
			Title:       "พหุนาม",
			Sessions:    []syllabus.Session{{Number: 1, Title: "คาบแรก"}, {Number: 2, Title: "คาบสอง"}},
			Assessments: []syllabus.Assessment{{Title: "Quiz", Session: 2, Points: 5}},
		}},
	}
	result, err := Place(timetable, draft)
	if err != nil {
		t.Fatal(err)
	}
	if result.AvailableSessions != 2 || len(result.Classes) != 2 {
		t.Fatalf("wrong availability: %+v", result)
	}
	if got := result.Classes[0].Meetings[1]; got.Date != "2026-06-01" || got.EndTime != "09:50" || len(got.Assessments) != 1 {
		t.Fatalf("wrong class 1 quiz meeting: %+v", got)
	}
	if got := result.Classes[1].Meetings[1]; got.Date != "2026-05-26" || got.StartTime != "10:00" {
		t.Fatalf("wrong class 2 quiz meeting: %+v", got)
	}
}

func TestAvailabilityRejectsOverlappingSlots(t *testing.T) {
	timetable := Timetable{
		StartDate: "2026-05-18", EndDate: "2026-06-02",
		Classes: []Class{
			{ID: "m2-1", Slots: []Slot{{Weekday: 1, StartTime: "09:00"}}},
			{ID: "m2-2", Slots: []Slot{{Weekday: 1, StartTime: "09:30"}}},
		},
	}
	_, err := Count(timetable, 50)
	if !errors.Is(err, ErrInvalidTimetable) {
		t.Fatalf("wanted timetable validation, got %v", err)
	}
}
