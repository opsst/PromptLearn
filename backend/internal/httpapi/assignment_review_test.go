package httpapi

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/assignmentreview"
)

func TestAssignmentReviewAcceptsPaperImageAndReturnsOCRBox(t *testing.T) {
	var imageBytes bytes.Buffer
	if err := png.Encode(&imageBytes, image.NewGray(image.Rect(0, 0, 32, 32))); err != nil {
		t.Fatal(err)
	}
	box := assignmentreview.Box{X: 0.1, Y: 0.2, Width: 0.45, Height: 0.09}
	work := assignmentreview.Submission{
		Text:           "(x^2)(x^5)\n=x^(2*5)\n=x^10",
		Blocks:         []assignmentreview.Block{{ID: "b2", Text: "=x^(2*5)", Box: box}},
		ImageDataURL:   "data:image/png;base64," + base64.StdEncoding.EncodeToString(imageBytes.Bytes()),
		FocusedBlockID: "b2",
	}
	body, err := json.Marshal(work)
	if err != nil {
		t.Fatal(err)
	}

	service := assignmentreview.NewService(openTestReviewRepo(t), assignmentreview.DemoReviewer{})
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews", bytes.NewReader(body))
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}

	var review assignmentreview.Result
	if err := json.NewDecoder(res.Body).Decode(&review); err != nil {
		t.Fatal(err)
	}
	if review.Status != assignmentreview.NeedsRevision || len(review.Issues) != 1 ||
		review.Issues[0].BlockID != "b2" || review.Issues[0].Box != box {
		t.Fatalf("unexpected data: %+v", review)
	}
}

func TestAssignmentReviewRejectsMissingOCRCoordinates(t *testing.T) {
	service := assignmentreview.NewService(openTestReviewRepo(t), assignmentreview.DemoReviewer{})
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews",
		strings.NewReader(`{"text":"=x^(2*5)","blocks":[{"id":"b2","text":"=x^(2*5)","box":{"y":0.2,"width":0.45,"height":0.09}}]}`))
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
}

func openTestReviewRepo(t *testing.T) *assignmentreview.DemoRepository {
	t.Helper()
	repo, err := assignmentreview.OpenDemoRepository(t.TempDir(), "mock")
	if err != nil {
		t.Fatal(err)
	}
	return repo
}

func TestAssignmentReviewDemoRejectsNonLoopbackPeer(t *testing.T) {
	repo := openTestReviewRepo(t)
	service := assignmentreview.NewService(repo, assignmentreview.DemoReviewer{})
	handler := NewHandler(nil, nil, WithAssignmentReview(service))
	req := httptest.NewRequest(http.MethodPost, "http://localhost/v1/assignments/hw-3-2/items/q4/reviews",
		strings.NewReader(`{"text":"?"}`))
	req.RemoteAddr = "192.0.2.1:1234"
	req.Header.Set("Content-Type", "application/json")
	res := httptest.NewRecorder()
	handler.ServeHTTP(res, req)
	if res.Code != http.StatusForbidden {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
}
