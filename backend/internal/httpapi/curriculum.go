package httpapi

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/opsst/PromptLearn/backend/internal/curriculum"
)

func mathCurriculum(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	grade, err := strconv.Atoi(query.Get("grade"))
	if err != nil {
		http.Error(w, "grade must be an integer from 1 to 6", http.StatusBadRequest)
		return
	}

	selection, err := curriculum.Math(grade, curriculum.CourseType(query.Get("course_type")))
	if errors.Is(err, curriculum.ErrUnsupportedCourse) {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err != nil {
		log.Printf("load math curriculum: %v", err)
		http.Error(w, "curriculum unavailable", http.StatusInternalServerError)
		return
	}
	if query.Get("language") == "en" {
		// Math returns filtered copies of the grade's groups and rows.
		selection.Source = curriculum.EnglishSource(selection.Source)
		for i, group := range selection.Groups {
			for j, row := range group.Rows {
				translated, err := curriculum.EnglishReference(curriculum.Reference{
					Strand: group.Strand, StandardCode: group.StandardCode,
					ObjectiveNumber: group.ObjectiveNumber, Statement: group.Statement, Row: row,
				})
				if err != nil {
					log.Printf("translate math curriculum: %v", err)
					http.Error(w, "curriculum unavailable", http.StatusInternalServerError)
					return
				}
				selection.Groups[i].Rows[j] = translated.Row
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(selection); err != nil {
		log.Printf("write math curriculum: %v", err)
	}
}
