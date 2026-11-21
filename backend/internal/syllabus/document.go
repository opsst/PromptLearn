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

var documentTemplate = template.Must(template.New("syllabus").Funcs(template.FuncMap{
	"contentClass": func(line string) string {
		if strings.HasPrefix(line, "o ") {
			return "source-subitem"
		}
		if strings.HasPrefix(line, "- ") {
			return "source-item"
		}
		return "source-continuation"
	},
}).Parse(documentSource))

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

// RenderDocument formats a draft and its optional dated teaching schedule.
func RenderDocument(draft Draft, calendars []DocumentCalendar) (string, error) {
	data := struct {
		Draft
		CourseTypeLabel string
		ReferenceTitles map[string]string
		Calendars       []DocumentCalendar
	}{
		Draft: draft, CourseTypeLabel: "Core Mathematics", Calendars: calendars,
		ReferenceTitles: make(map[string]string, len(draft.References)),
	}
	if draft.CourseType == curriculum.Additional {
		data.CourseTypeLabel = "Additional Mathematics"
	}
	for _, reference := range draft.References {
		data.ReferenceTitles[reference.Row.ID] = strings.ReplaceAll(reference.Row.Title, "\n", " ")
	}
	var buffer bytes.Buffer
	err := documentTemplate.Execute(&buffer, data)
	return buffer.String(), err
}
