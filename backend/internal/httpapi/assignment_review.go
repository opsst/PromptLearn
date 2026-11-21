package httpapi

import (
	"context"
	"errors"
	"log"
	"mime"
	"net"
	"net/http"

	"github.com/opsst/PromptLearn/backend/internal/assignmentreview"
)

const maxReviewRequestBytes = 5 << 20

func WithAssignmentReview(service *assignmentreview.Service) RouterOption {
	return func(mux *http.ServeMux) {
		mux.HandleFunc("POST /v1/assignments/{assignment_id}/items/{item_id}/reviews", func(w http.ResponseWriter, r *http.Request) {
			host, _, err := net.SplitHostPort(r.Host)
			if err != nil {
				host = r.Host
			}
			peer, _, err := net.SplitHostPort(r.RemoteAddr)
			if err != nil || !net.ParseIP(peer).IsLoopback() || !IsLoopbackHost(host) {
				writeAPIError(w, http.StatusForbidden, "forbidden", "the review demo is available on this machine only")
				return
			}
			mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
			if err != nil || mediaType != "application/json" {
				writeAPIError(w, http.StatusUnsupportedMediaType, "unsupported_media_type", "send application/json")
				return
			}
			var work assignmentreview.Submission
			if !readJSONWithLimit(w, r, &work, maxReviewRequestBytes) {
				return
			}
			result, err := service.Review(r.Context(), r.PathValue("assignment_id"), r.PathValue("item_id"), work)
			if err != nil {
				writeReviewError(w, err)
				return
			}
			writeJSON(w, http.StatusOK, result)
		})
	}
}

func writeReviewError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, assignmentreview.ErrInvalidInput):
		writeAPIError(w, http.StatusBadRequest, "invalid_input", err.Error())
	case errors.Is(err, assignmentreview.ErrNotFound):
		writeAPIError(w, http.StatusNotFound, "item_not_found", "assignment item not found")
	case errors.Is(err, assignmentreview.ErrAttemptClosed):
		writeAPIError(w, http.StatusConflict, "attempt_closed", "this assignment attempt has already been submitted")
	case errors.Is(err, context.DeadlineExceeded):
		writeAPIError(w, http.StatusGatewayTimeout, "review_timeout", "assignment review timed out")
	case errors.Is(err, assignmentreview.ErrInvalidDecision):
		writeAPIError(w, http.StatusBadGateway, "invalid_review", "review could not be matched to the submitted work")
	case errors.Is(err, assignmentreview.ErrFeedbackStore):
		log.Print("assignment review feedback write failed")
		writeAPIError(w, http.StatusServiceUnavailable, "feedback_unavailable", "review feedback could not be saved")
	default:
		log.Printf("review assignment: %v", err)
		writeAPIError(w, http.StatusBadGateway, "review_failed", "assignment review failed")
	}
}
