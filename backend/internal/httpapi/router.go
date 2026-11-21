package httpapi

import (
	"net/http"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

// NewHandler registers the backend's HTTP routes.
func NewHandler(syllabi *syllabus.Service, store *course.Store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthCheck)
	mux.HandleFunc("GET /v1/curriculum/math", mathCurriculum)
	mux.HandleFunc("POST /v1/syllabi/draft", draftSyllabus(syllabi))
	mux.HandleFunc("POST /v1/timetable/availability", timetableAvailability)
	mux.HandleFunc("POST /v1/syllabi/preview", coursePreview)
	if store != nil {
		registerCourseStoreRoutes(mux, store)
	}
	return mux
}

func healthCheck(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write([]byte("{\"status\":\"ok\"}\n"))
}
