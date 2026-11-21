// Package course coordinates term drafts, schedules and published snapshots.
package course

import (
	"fmt"
	"slices"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

type Edit struct {
	Course    syllabus.Input      `json:"course"`
	Plan      syllabus.Plan       `json:"plan"`
	Timetable *teaching.Timetable `json:"timetable"`
	Settings  *EditorSettings     `json:"settings,omitempty"`
}

type EditorSettings struct {
	Textbook           *Textbook       `json:"textbook,omitempty"`
	TeachingApproaches []string        `json:"teaching_approaches"`
	StudentDetails     []string        `json:"student_details"`
	TeachingNotes      string          `json:"teaching_notes"`
	LessonGroups       [][]LessonGroup `json:"lesson_groups,omitempty"`
	CalendarEvents     []CalendarEvent `json:"calendar_events,omitempty"`
}

type Textbook struct {
	Title    string   `json:"title"`
	Pages    int      `json:"pages"`
	Chapters []string `json:"chapters"`
}

type LessonGroup struct {
	Title   string `json:"title"`
	Periods int    `json:"periods"`
}

type CalendarEvent struct {
	Date string `json:"date"`
	Name string `json:"name"`
}

type Preview struct {
	Syllabus  syllabus.Draft      `json:"syllabus"`
	Timetable *teaching.Timetable `json:"timetable,omitempty"`
	Schedule  *teaching.Schedule  `json:"schedule,omitempty"`
	Settings  *EditorSettings     `json:"settings,omitempty"`
}

// Build validates a teacher-edited syllabus and optionally places it on a calendar.
func Build(edit Edit) (Preview, error) {
	draft, err := syllabus.Compose(edit.Course, edit.Plan)
	if err != nil {
		return Preview{}, err
	}
	if settings := edit.Settings; settings != nil {
		if !validChoices(settings.TeachingApproaches, []string{"inquiry", "fiveE", "cpa", "flipped"}) ||
			!validChoices(settings.StudentDetails, []string{"topics", "assessmentDates", "scores", "indicators", "notes"}) {
			return Preview{}, fmt.Errorf("%w: unknown or repeated syllabus setting", syllabus.ErrInvalidInput)
		}
	}
	preview := Preview{Syllabus: draft, Timetable: edit.Timetable, Settings: edit.Settings}
	if edit.Timetable != nil {
		schedule, err := teaching.Place(*edit.Timetable, draft)
		if err != nil {
			return Preview{}, err
		}
		preview.Schedule = &schedule
		preview.Syllabus.DocumentHTML, err = syllabus.RenderDocument(draft, documentCalendars(schedule))
		if err != nil {
			return Preview{}, err
		}
	}
	return preview, nil
}

func validChoices(values, allowed []string) bool {
	for i, value := range values {
		if !slices.Contains(allowed, value) || slices.Contains(values[:i], value) {
			return false
		}
	}
	return true
}

func restoreHTML(preview *Preview) error {
	var calendars []syllabus.DocumentCalendar
	if preview.Schedule != nil {
		calendars = documentCalendars(*preview.Schedule)
	}
	html, err := syllabus.RenderDocument(preview.Syllabus, calendars)
	preview.Syllabus.DocumentHTML = html
	return err
}

func documentCalendars(schedule teaching.Schedule) []syllabus.DocumentCalendar {
	calendars := make([]syllabus.DocumentCalendar, 0, len(schedule.Classes))
	for _, class := range schedule.Classes {
		calendar := syllabus.DocumentCalendar{ClassID: class.ClassID}
		for _, meeting := range class.Meetings {
			calendar.Meetings = append(calendar.Meetings, syllabus.DocumentMeeting{
				Number: meeting.Session, Date: meeting.Date, StartTime: meeting.StartTime,
				EndTime: meeting.EndTime, Title: meeting.Title, Assessments: meeting.Assessments,
			})
		}
		calendars = append(calendars, calendar)
	}
	return calendars
}
