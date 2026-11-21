package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

const maxRequestBytes = 64 << 10

func draftSyllabus(service *syllabus.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if service == nil {
			writeAPIError(w, http.StatusServiceUnavailable, "syllabus_unavailable", "syllabus generation is not configured")
			return
		}

		var input syllabus.Input
		if !readJSON(w, r, &input) {
			return
		}

		draft, err := service.Generate(r.Context(), input)
		if err != nil {
			switch {
			case errors.Is(err, syllabus.ErrInvalidInput):
				writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
			case errors.Is(err, context.DeadlineExceeded):
				writeAPIError(w, http.StatusGatewayTimeout, "model_timeout", "syllabus generation timed out")
			case errors.Is(err, syllabus.ErrInvalidPlan):
				log.Printf("reject syllabus plan: %v", err)
				writeAPIError(w, http.StatusBadGateway, "invalid_plan", "the generated plan did not match the curriculum, sessions or scoring requirements")
			default:
				log.Printf("generate syllabus: %v", err)
				writeAPIError(w, http.StatusBadGateway, "generation_failed", "syllabus generation failed")
			}
			return
		}

		writeJSON(w, http.StatusOK, draft)
	}
}

func readJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	return readJSONWithLimit(w, r, target, maxRequestBytes)
}

func readJSONWithLimit(w http.ResponseWriter, r *http.Request, target any, limit int64) bool {
	reader := http.MaxBytesReader(w, r.Body, limit)
	decoder := json.NewDecoder(reader)
	decoder.DisallowUnknownFields()

	err := decoder.Decode(target)
	if err == nil {
		err = decoder.Decode(new(json.RawMessage))
		if err == io.EOF {
			return true
		}
	}
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		writeAPIError(w, http.StatusRequestEntityTooLarge, "request_too_large", "request body is too large")
	} else {
		writeAPIError(w, http.StatusBadRequest, "invalid_json", "expected one JSON object with known fields")
	}
	return false
}

func writeAPIError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}{Code: code, Message: message})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("write HTTP response: %v", err)
	}
}
