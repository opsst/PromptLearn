// Package curriculum serves source-backed curriculum references.
package curriculum

import (
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"sync"
)

type CourseType string

const (
	Core       CourseType = "core"
	Additional CourseType = "additional"
)

var ErrUnsupportedCourse = errors.New("core supports grades 1–6 and additional supports grades 4–6")

type Source struct {
	Title  string `json:"title"`
	File   string `json:"file"`
	SHA256 string `json:"sha256"`
}

type Outcome struct {
	Number int    `json:"number"`
	Text   string `json:"text"`
	Code   string `json:"code,omitempty"`
}

// Row is one nonempty grade-and-topic row from the original PDF table.
// Outcomes and content belong to the row as a group, as in the source.
type Row struct {
	ID          string    `json:"id"`
	Grade       int       `json:"grade"`
	PDFPage     int       `json:"pdf_page"`
	PrintedPage int       `json:"printed_page"`
	Title       string    `json:"title"`
	Outcomes    []Outcome `json:"outcomes"`
	Content     []string  `json:"content"`
}

type Group struct {
	Strand          string `json:"strand"`
	StandardCode    string `json:"standard_code,omitempty"`
	ObjectiveNumber int    `json:"objective_number,omitempty"`
	Statement       string `json:"statement"`
	Rows            []Row  `json:"rows"`
}

// Reference associates a source row with the standard or objective above it.
type Reference struct {
	Strand          string `json:"strand"`
	StandardCode    string `json:"standard_code,omitempty"`
	ObjectiveNumber int    `json:"objective_number,omitempty"`
	Statement       string `json:"statement"`
	Row             Row    `json:"row"`
}

type Selection struct {
	Source     Source     `json:"source"`
	Grade      int        `json:"grade"`
	CourseType CourseType `json:"course_type"`
	Groups     []Group    `json:"groups"`
}

type catalog struct {
	Source  Source                 `json:"source"`
	Courses map[CourseType][]Group `json:"courses"`
}

//go:embed math_2560.json
var mathJSON []byte

var loadMath = sync.OnceValues(func() (catalog, error) {
	var data catalog
	err := json.Unmarshal(mathJSON, &data)
	return data, err
})

// Math returns the reference rows for a single secondary grade and course type.
func Math(grade int, courseType CourseType) (Selection, error) {
	if grade < 1 || grade > 6 || (courseType != Core && (courseType != Additional || grade < 4)) {
		return Selection{}, ErrUnsupportedCourse
	}
	data, err := loadMath()
	if err != nil {
		return Selection{}, fmt.Errorf("decode math curriculum: %w", err)
	}
	selection := Selection{Source: data.Source, Grade: grade, CourseType: courseType}
	for _, group := range data.Courses[courseType] {
		matching := group
		matching.Rows = nil
		for _, row := range group.Rows {
			if row.Grade == grade {
				row.Outcomes = slices.Clone(row.Outcomes)
				row.Content = slices.Clone(row.Content)
				matching.Rows = append(matching.Rows, row)
			}
		}
		if len(matching.Rows) > 0 {
			selection.Groups = append(selection.Groups, matching)
		}
	}
	return selection, nil
}
