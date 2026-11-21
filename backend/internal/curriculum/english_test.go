package curriculum

import (
	"slices"
	"strings"
	"testing"
)

func TestEnglishTranslationsMatchCanonicalRows(t *testing.T) {
	data, err := loadMath()
	if err != nil {
		t.Fatal(err)
	}
	translated, err := englishRows()
	if err != nil {
		t.Fatal(err)
	}

	count := 0
	for _, groups := range data.Courses {
		for _, group := range groups {
			for _, row := range group.Rows {
				count++
				english, err := EnglishReference(Reference{
					Strand: group.Strand, StandardCode: group.StandardCode,
					ObjectiveNumber: group.ObjectiveNumber, Statement: group.Statement, Row: row,
				})
				if err != nil {
					t.Errorf("row %s: %v", row.ID, err)
					continue
				}
				if english.Row.ID != row.ID || english.Row.PDFPage != row.PDFPage || english.Row.PrintedPage != row.PrintedPage ||
					!slices.Equal(topicMarkers(row.Content), topicMarkers(english.Row.Content)) {
					t.Errorf("English reference changed scope or topics for %s", row.ID)
				}
				for i, text := range english.Row.Outcomes {
					if text.Number != row.Outcomes[i].Number || text.Code != row.Outcomes[i].Code || strings.TrimSpace(text.Text) == "" {
						t.Errorf("English reference changed or omitted outcome %d for %s", i+1, row.ID)
					}
				}
			}
		}
	}
	if count != len(translated) {
		t.Errorf("translations = %d, source rows = %d", len(translated), count)
	}
}

func topicMarkers(lines []string) []byte {
	var markers []byte
	for _, line := range lines {
		if strings.HasPrefix(line, "- ") || strings.HasPrefix(line, "o ") {
			markers = append(markers, line[0])
		}
	}
	return markers
}
