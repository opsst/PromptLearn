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

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(selection); err != nil {
		log.Printf("write math curriculum: %v", err)
	}
}
