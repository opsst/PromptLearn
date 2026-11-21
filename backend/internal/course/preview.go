// Package course coordinates term drafts, schedules and published snapshots.
package course

import (
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

type Edit struct {
	Course    syllabus.Input      `json:"course"`
	Plan      syllabus.Plan       `json:"plan"`
	Timetable *teaching.Timetable `json:"timetable"`
}

type Preview struct {
	Syllabus  syllabus.Draft      `json:"syllabus"`
	Timetable *teaching.Timetable `json:"timetable,omitempty"`
	Schedule  *teaching.Schedule  `json:"schedule,omitempty"`
}

// Build validates a teacher-edited syllabus and optionally places it on a calendar.
func Build(edit Edit) (Preview, error) {
	draft, err := syllabus.Compose(edit.Course, edit.Plan)
	if err != nil {
		return Preview{}, err
	}
	preview := Preview{Syllabus: draft, Timetable: edit.Timetable}
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
