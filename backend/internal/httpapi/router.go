package httpapi

import (
	"net/http"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

type RouterOption func(*http.ServeMux)

// NewHandler registers the backend's HTTP routes.
func NewHandler(syllabi *syllabus.Service, store *course.Store, options ...RouterOption) http.Handler {
	return newRouter(syllabi, store, options...)
}

func newRouter(syllabi *syllabus.Service, store *course.Store, options ...RouterOption) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthCheck)
	mux.HandleFunc("GET /v1/curriculum/math", mathCurriculum)
	mux.HandleFunc("POST /v1/syllabi/draft", draftSyllabus(syllabi))
	mux.HandleFunc("POST /v1/timetable/availability", timetableAvailability)
	mux.HandleFunc("POST /v1/syllabi/preview", coursePreview)
	if store != nil {
		registerCourseStoreRoutes(mux, store)
	}
	for _, register := range options {
		register(mux)
	}
	return mux
}

func healthCheck(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write([]byte("{\"status\":\"ok\"}\n"))
}
