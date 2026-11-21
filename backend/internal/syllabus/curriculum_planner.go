package syllabus

import (
	"context"
	"strings"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
)

// CurriculumPlanner drafts units directly from the selected source rows.
type CurriculumPlanner struct{}

func (CurriculumPlanner) Plan(_ context.Context, input Input, refs []curriculum.Reference) (Plan, error) {
	unitCount := min(input.TotalSessions, len(refs))
	units := make([]PlannedUnit, 0, unitCount)
	refOffset := 0
	for i := range unitCount {
		refCount := portion(len(refs), unitCount, i)
		rows := refs[refOffset : refOffset+refCount]
		unit := sourceUnit(rows, portion(input.TotalSessions, unitCount, i))
		units = append(units, unit)
		refOffset += refCount
	}
	for i, weight := range input.AssessmentWeights {
		session := max(1, input.TotalSessions-len(input.AssessmentWeights)+i+1)
		for j := range units {
			if session <= len(units[j].SessionTitles) {
				units[j].Assessments = append(units[j].Assessments, Assessment{
					Title: weight.Category, Category: weight.Category, Session: session, Points: weight.Points,
				})
				break
			}
			session -= len(units[j].SessionTitles)
		}
	}
	return Plan{
		Mode: "curriculum", Description: "Study and apply the mathematics topics selected for this semester.",
		Units: units,
	}, nil
}

func sourceUnit(refs []curriculum.Reference, sessionCount int) PlannedUnit {
	var titles, ids, topics []string
	for _, ref := range refs {
		row := ref.Row
		ids = append(ids, row.ID)
		titles = append(titles, strings.Join(strings.Fields(row.Title), " "))
		topics = append(topics, sourceTopics(row.Content)...)
		for _, outcome := range row.Outcomes {
			topics = append(topics, outcome.Text)
		}
	}

	title := strings.Join(titles, " · ")
	if len(topics) == 0 {
		topics = titles
	}
	titlesForSessions := make([]string, 0, sessionCount)
	lessonCount := min(sessionCount, len(topics))
	offset := 0
	for i := range lessonCount {
		count := portion(len(topics), lessonCount, i)
		titlesForSessions = append(titlesForSessions, strings.Join(topics[offset:offset+count], " · "))
		offset += count
	}
	for len(titlesForSessions) < sessionCount {
		titlesForSessions = append(titlesForSessions, "Review and practice: "+title)
	}
	return PlannedUnit{Title: title, ReferenceIDs: ids, SessionTitles: titlesForSessions, Assessments: []Assessment{}}
}

func sourceTopics(lines []string) []string {
	var topics []string
	for _, line := range lines {
		line = strings.TrimPrefix(strings.TrimPrefix(line, "- "), "o ")
		topics = append(topics, strings.TrimSuffix(line, " using"))
	}
	return topics
}

func portion(total, parts, index int) int {
	size := total / parts
	if index < total%parts {
		size++
	}
	return size
}
