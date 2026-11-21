package httpapi

import "net/http"

// NewHandler registers the backend's HTTP routes.
func NewHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthCheck)
	return mux
}

func healthCheck(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write([]byte("{\"status\":\"ok\"}\n"))
}
