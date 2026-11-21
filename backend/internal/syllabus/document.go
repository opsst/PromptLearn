package syllabus

import (
	"bytes"
	_ "embed"
	"html/template"
	"strings"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
)

//go:embed document.html
var documentSource string

var documentTemplate = template.Must(template.New("syllabus").Parse(documentSource))

type DocumentCalendar struct {
	ClassID  string
	Meetings []DocumentMeeting
}

type DocumentMeeting struct {
	Number      int
	Date        string
	StartTime   string
	EndTime     string
	Title       string
	Assessments []Assessment
}

type documentTopic struct {
	Title     string
	Subtopics []string
}

type documentUnit struct {
	Unit
	Topics []documentTopic
}

// RenderDocument formats a draft and its optional dated teaching schedule.
func RenderDocument(draft Draft, calendars []DocumentCalendar) (string, error) {
	data := struct {
		Draft
		CourseTypeLabel  string
		LearningOutcomes []string
		LearningUnits    []documentUnit
		Calendars        []DocumentCalendar
	}{
		Draft: draft, CourseTypeLabel: "Core Mathematics", Calendars: calendars,
	}
	if draft.CourseType == curriculum.Additional {
		data.CourseTypeLabel = "Additional Mathematics"
	}
	topicsByReference := make(map[string][]string, len(draft.References))
	for _, reference := range draft.References {
		topicsByReference[reference.Row.ID] = reference.Row.Content
		for _, outcome := range reference.Row.Outcomes {
			data.LearningOutcomes = append(data.LearningOutcomes, outcome.Text)
		}
	}
	for _, unit := range draft.Units {
		view := documentUnit{Unit: unit}
		for _, id := range unit.ReferenceIDs {
			view.Topics = append(view.Topics, documentTopics(topicsByReference[id])...)
		}
		data.LearningUnits = append(data.LearningUnits, view)
	}
	var buffer bytes.Buffer
	err := documentTemplate.Execute(&buffer, data)
	return buffer.String(), err
}

func documentTopics(lines []string) []documentTopic {
	var topics []documentTopic
	for _, line := range lines {
		subtopic, nested := strings.CutPrefix(line, "o ")
		if nested && len(topics) > 0 {
			last := &topics[len(topics)-1]
			last.Subtopics = append(last.Subtopics, subtopic)
			continue
		}
		title := strings.TrimPrefix(subtopic, "- ")
		topics = append(topics, documentTopic{Title: title})
	}
	return topics
}
