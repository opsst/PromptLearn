package httpapi

import (
	"errors"
	"log"
	"net/http"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

func timetableAvailability(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Timetable         teaching.Timetable `json:"timetable"`
		MinutesPerSession int                `json:"minutes_per_session"`
	}
	if !readJSON(w, r, &request) {
		return
	}
	availability, err := teaching.Count(request.Timetable, request.MinutesPerSession)
	if err != nil {
		writeCourseError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, availability)
}

func coursePreview(w http.ResponseWriter, r *http.Request) {
	if preview, ok := buildPreview(w, r); ok {
		writeJSON(w, http.StatusOK, preview)
	}
}

func registerCourseStoreRoutes(mux *http.ServeMux, store *course.Store) {
	mux.HandleFunc("POST /v1/syllabi", func(w http.ResponseWriter, r *http.Request) {
		preview, ok := buildPreview(w, r)
		if !ok {
			return
		}
		saved, err := store.Create(preview)
		if err != nil {
			writeCourseError(w, err)
			return
		}
		w.Header().Set("Location", "/v1/syllabi/"+saved.ID)
		writeJSON(w, http.StatusCreated, saved)
	})
	mux.HandleFunc("GET /v1/syllabi/{id}", func(w http.ResponseWriter, r *http.Request) {
		saved, err := store.Get(r.PathValue("id"))
		if err != nil {
			writeCourseError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, saved)
	})
	mux.HandleFunc("PUT /v1/syllabi/{id}", func(w http.ResponseWriter, r *http.Request) {
		preview, ok := buildPreview(w, r)
		if !ok {
			return
		}
		saved, err := store.Update(r.PathValue("id"), preview)
		if err != nil {
			writeCourseError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, saved)
	})
	mux.HandleFunc("POST /v1/syllabi/{id}/publish", func(w http.ResponseWriter, r *http.Request) {
		saved, err := store.Publish(r.PathValue("id"))
		if err != nil {
			writeCourseError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, saved)
	})
	mux.HandleFunc("GET /v1/published-syllabi/{id}", func(w http.ResponseWriter, r *http.Request) {
		view, err := store.StudentView(r.PathValue("id"))
		if err != nil {
			writeCourseError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, view)
	})
}

func buildPreview(w http.ResponseWriter, r *http.Request) (course.Preview, bool) {
	var edit course.Edit
	const maxEditBytes = 512 << 10
	if !readJSONWithLimit(w, r, &edit, maxEditBytes) {
		return course.Preview{}, false
	}
	preview, err := course.Build(edit)
	if err != nil {
		writeCourseError(w, err)
		return course.Preview{}, false
	}
	return preview, true
}

func writeCourseError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, syllabus.ErrInvalidInput), errors.Is(err, syllabus.ErrInvalidPlan), errors.Is(err, teaching.ErrInvalidTimetable):
		writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
	case errors.Is(err, course.ErrNotFound):
		writeAPIError(w, http.StatusNotFound, "not_found", err.Error())
	case errors.Is(err, course.ErrNotReady):
		writeAPIError(w, http.StatusConflict, "not_ready", err.Error())
	default:
		log.Printf("process course: %v", err)
		writeAPIError(w, http.StatusInternalServerError, "course_failed", "course operation failed")
	}
}
