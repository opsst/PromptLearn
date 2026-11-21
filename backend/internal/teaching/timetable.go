// Package teaching maps term sessions to classroom dates.
package teaching

import (
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

var ErrInvalidTimetable = errors.New("invalid timetable")

type Timetable struct {
	StartDate     string   `json:"start_date"`
	EndDate       string   `json:"end_date"`
	ExcludedDates []string `json:"excluded_dates"`
	Classes       []Class  `json:"classes"`
}

type Class struct {
	ID           string `json:"id"`
	StudentCount *int   `json:"student_count,omitempty"`
	Slots        []Slot `json:"slots"`
	SessionOrder []int  `json:"session_order,omitempty"`
}

// Slot uses an ISO weekday (1 is Monday, 7 is Sunday) and Bangkok local time.
type Slot struct {
	Weekday      int    `json:"weekday"`
	StartTime    string `json:"start_time"`
	PeriodNumber int    `json:"period_number,omitempty"`
}

type ClassAvailability struct {
	ClassID           string `json:"class_id"`
	AvailableSessions int    `json:"available_sessions"`
}

type Availability struct {
	AvailableSessions int                 `json:"available_sessions"`
	Classes           []ClassAvailability `json:"classes"`
}

type Meeting struct {
	Session     int                   `json:"session"`
	Unit        string                `json:"unit"`
	Title       string                `json:"title"`
	Date        string                `json:"date"`
	StartTime   string                `json:"start_time"`
	EndTime     string                `json:"end_time"`
	Assessments []syllabus.Assessment `json:"assessments"`
}

type ClassSchedule struct {
	ClassAvailability
	Meetings []Meeting `json:"meetings"`
}

type Schedule struct {
	Timezone          string          `json:"timezone"`
	AvailableSessions int             `json:"available_sessions"`
	Classes           []ClassSchedule `json:"classes"`
}

type interval struct {
	classID string
	start   int
	end     int
}

type window struct {
	date string
	interval
}

func Count(timetable Timetable, minutes int) (Availability, error) {
	windows, err := availableWindows(timetable, minutes)
	if err != nil {
		return Availability{}, err
	}
	return summarize(timetable, windows), nil
}

func Place(timetable Timetable, draft syllabus.Draft) (Schedule, error) {
	windows, err := availableWindows(timetable, draft.MinutesPerSession)
	if err != nil {
		return Schedule{}, err
	}
	availability := summarize(timetable, windows)
	if availability.AvailableSessions < draft.TotalSessions {
		return Schedule{}, fmt.Errorf("%w: at least one class has only %d slots for %d sessions",
			ErrInvalidTimetable, availability.AvailableSessions, draft.TotalSessions)
	}

	scored := make(map[int][]syllabus.Assessment)
	for _, unit := range draft.Units {
		for _, assessment := range unit.Assessments {
			scored[assessment.Session] = append(scored[assessment.Session], assessment)
		}
	}
	sessions := make([]Meeting, 0, draft.TotalSessions)
	for _, unit := range draft.Units {
		for _, session := range unit.Sessions {
			assessments := scored[session.Number]
			if assessments == nil {
				assessments = []syllabus.Assessment{}
			}
			sessions = append(sessions, Meeting{
				Session: session.Number, Unit: unit.Title, Title: session.Title, Assessments: assessments,
			})
		}
	}
	result := Schedule{Timezone: "Asia/Bangkok", AvailableSessions: availability.AvailableSessions}
	for i, class := range availability.Classes {
		meetings, err := placeClass(timetable.Classes[i], windows[class.ClassID], sessions)
		if err != nil {
			return Schedule{}, err
		}
		result.Classes = append(result.Classes, ClassSchedule{ClassAvailability: class, Meetings: meetings})
	}
	return result, nil
}

func placeClass(class Class, windows []window, sessions []Meeting) ([]Meeting, error) {
	order := class.SessionOrder
	if len(order) == 0 {
		order = make([]int, len(sessions))
		for i := range order {
			order[i] = i + 1
		}
	}
	if len(order) > len(windows) {
		return nil, fmt.Errorf("%w: session order for %q exceeds its available slots", ErrInvalidTimetable, class.ID)
	}
	seen := make([]bool, len(sessions))
	meetings := make([]Meeting, 0, len(sessions))
	for index, position := range order {
		if position == 0 {
			continue
		}
		if position < 1 || position > len(sessions) || seen[position-1] {
			return nil, fmt.Errorf("%w: %q must place each course session once", ErrInvalidTimetable, class.ID)
		}
		seen[position-1] = true
		slot, meeting := windows[index], sessions[position-1]
		meeting.Date, meeting.StartTime, meeting.EndTime = slot.date, clockTime(slot.start), clockTime(slot.end)
		meetings = append(meetings, meeting)
	}
	if len(meetings) != len(sessions) {
		return nil, fmt.Errorf("%w: %q must place each course session once", ErrInvalidTimetable, class.ID)
	}
	return meetings, nil
}

func summarize(timetable Timetable, windows map[string][]window) Availability {
	out := Availability{AvailableSessions: len(windows[timetable.Classes[0].ID])}
	for _, class := range timetable.Classes {
		count := len(windows[class.ID])
		out.Classes = append(out.Classes, ClassAvailability{ClassID: class.ID, AvailableSessions: count})
		out.AvailableSessions = min(out.AvailableSessions, count)
	}
	return out
}

func availableWindows(timetable Timetable, minutes int) (map[string][]window, error) {
	start, err1 := time.Parse(time.DateOnly, timetable.StartDate)
	end, err2 := time.Parse(time.DateOnly, timetable.EndDate)
	if err1 != nil || err2 != nil || end.Before(start) || !end.Before(start.AddDate(1, 0, 0)) {
		return nil, fmt.Errorf("%w: use a date range shorter than one year", ErrInvalidTimetable)
	}
	if minutes < 1 || minutes >= 24*60 || len(timetable.Classes) == 0 {
		return nil, fmt.Errorf("%w: at least one class and a valid session duration are required", ErrInvalidTimetable)
	}

	excluded := make(map[time.Time]bool)
	for _, value := range timetable.ExcludedDates {
		day, err := time.Parse(time.DateOnly, value)
		if err != nil {
			return nil, fmt.Errorf("%w: invalid excluded date %q", ErrInvalidTimetable, value)
		}
		excluded[day] = true
	}

	slots, err := weeklyIntervals(timetable.Classes, minutes)
	if err != nil {
		return nil, err
	}

	result := make(map[string][]window)
	for day := start; !day.After(end); day = day.AddDate(0, 0, 1) {
		if excluded[day] {
			continue
		}
		weekday := (int(day.Weekday())+6)%7 + 1
		for _, slot := range slots[weekday] {
			result[slot.classID] = append(result[slot.classID], window{date: day.Format(time.DateOnly), interval: slot})
		}
	}
	return result, nil
}

func weeklyIntervals(classes []Class, minutes int) ([8][]interval, error) {
	var slots [8][]interval
	classIDs := make(map[string]bool)
	for _, class := range classes {
		if strings.TrimSpace(class.ID) == "" || classIDs[class.ID] || len(class.Slots) == 0 {
			return slots, fmt.Errorf("%w: each class requires a unique id and weekly slots", ErrInvalidTimetable)
		}
		classIDs[class.ID] = true
		if class.StudentCount != nil && *class.StudentCount < 0 {
			return slots, fmt.Errorf("%w: student_count cannot be negative", ErrInvalidTimetable)
		}
		periods := make(map[[2]int]bool)
		for _, slot := range class.Slots {
			clock, err := time.Parse("15:04", slot.StartTime)
			if err != nil || slot.Weekday < 1 || slot.Weekday > 7 {
				return slots, fmt.Errorf("%w: invalid weekly slot for class %q", ErrInvalidTimetable, class.ID)
			}
			period := [2]int{slot.Weekday, slot.PeriodNumber}
			if slot.PeriodNumber < 0 || slot.PeriodNumber > 32 || periods[period] {
				return slots, fmt.Errorf("%w: invalid or repeated period number for %q", ErrInvalidTimetable, class.ID)
			}
			if slot.PeriodNumber != 0 {
				periods[period] = true
			}
			start := clock.Hour()*60 + clock.Minute()
			end := start + minutes
			if end >= 24*60 {
				return slots, fmt.Errorf("%w: class %q has a slot ending at or after midnight", ErrInvalidTimetable, class.ID)
			}
			slots[slot.Weekday] = append(slots[slot.Weekday], interval{classID: class.ID, start: start, end: end})
		}
	}
	for day, intervals := range slots {
		slices.SortFunc(intervals, func(a, b interval) int { return a.start - b.start })
		for i := 1; i < len(intervals); i++ {
			if intervals[i].start < intervals[i-1].end {
				return slots, fmt.Errorf("%w: overlapping teaching slots on weekday %d", ErrInvalidTimetable, day)
			}
		}
	}
	return slots, nil
}

func clockTime(minutes int) string {
	return fmt.Sprintf("%02d:%02d", minutes/60, minutes%60)
}
