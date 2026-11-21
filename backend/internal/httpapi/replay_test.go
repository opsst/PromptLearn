package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/replay"
)

func TestReplayPublication(t *testing.T) {
	databaseURL := os.Getenv("REPLAY_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("set REPLAY_TEST_DATABASE_URL to a fresh database with schema.sql and demo_seed.sql applied")
	}
	store, err := replay.Open(t.Context(), databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	dir := t.TempDir()
	handler := NewDemoHandler(nil, nil, store, dir, "")
	do := func(method, path, role, contentType string, body io.Reader) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, "http://localhost"+path, body)
		req.Header.Set("X-Demo-Role", role)
		req.Header.Set("Content-Type", contentType)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}
	check := func(rec *httptest.ResponseRecorder, status int) {
		t.Helper()
		if rec.Code != status {
			t.Fatalf("status = %d, want %d: %s", rec.Code, status, rec.Body)
		}
	}
	upload := func(transcript []byte) *httptest.ResponseRecorder {
		t.Helper()
		video, err := os.ReadFile("../../examples/thai-lesson.mp4")
		if err != nil {
			t.Fatal(err)
		}
		var body bytes.Buffer
		form := multipart.NewWriter(&body)
		for _, file := range []struct {
			field, name string
			content     []byte
		}{
			{"video", "lesson.mp4", video},
			{"transcript", "transcript.json", transcript},
		} {
			part, err := form.CreateFormFile(file.field, file.name)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := part.Write(file.content); err != nil {
				t.Fatal(err)
			}
		}
		if err := form.Close(); err != nil {
			t.Fatal(err)
		}
		return do("POST", "/api/demo/recordings", "teacher", form.FormDataContentType(), &body)
	}
	decode := func(rec *httptest.ResponseRecorder, dst any) {
		t.Helper()
		if err := json.Unmarshal(rec.Body.Bytes(), dst); err != nil {
			t.Fatal(err)
		}
	}

	status := do("GET", "/api/demo/replay", "student", "", nil)
	check(status, http.StatusOK)
	if !strings.Contains(status.Body.String(), `"published":false`) {
		t.Fatal("test database must start with an unpublished lesson")
	}
	check(do("POST", "/api/demo/recordings", "student", "", nil), http.StatusForbidden)
	check(upload([]byte(`[{"startMs":0,"endMs":9999999,"text":"เกินคลิป"}]`)), http.StatusBadRequest)
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 0 {
		t.Fatalf("invalid upload left files: %v, %v", entries, err)
	}

	transcript, err := os.ReadFile("../../examples/thai-lesson.transcript.json")
	if err != nil {
		t.Fatal(err)
	}
	create := func() string {
		t.Helper()
		rec := upload(transcript)
		check(rec, http.StatusCreated)
		var recording replay.Recording
		decode(rec, &recording)
		if recording.ID == "" {
			t.Fatal("missing recordingId")
		}
		return recording.ID
	}
	videoPath := func(id string) string { return "/api/demo/recordings/" + id + "/video" }
	publish := func(id string) {
		t.Helper()
		check(do("PUT", "/api/demo/publication", "teacher", "application/json",
			strings.NewReader(`{"recordingId":"`+id+`"}`)), http.StatusOK)
	}
	first := create()
	check(do("GET", videoPath(first), "student", "", nil), http.StatusNotFound)
	publish(first)
	publish(first)

	rec := do("GET", "/api/demo/replay", "student", "", nil)
	check(rec, http.StatusOK)
	var published struct {
		Published bool   `json:"published"`
		VideoURL  string `json:"videoUrl"`
		replay.Recording
	}
	decode(rec, &published)
	if !published.Published || published.VideoURL != videoPath(first) ||
		published.ID != first || len(published.Transcript) < 3 {
		t.Fatalf("unexpected published lesson: %+v", published)
	}

	second := create()
	check(do("GET", videoPath(second), "student", "", nil), http.StatusNotFound)
	rangeReq := httptest.NewRequest("GET", "http://localhost"+videoPath(first), nil)
	rangeReq.Header.Set("Range", "bytes=50-89")
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, rangeReq)
	check(rec, http.StatusPartialContent)
	if rec.Body.Len() != 40 || rec.Header().Get("Content-Type") != "video/mp4" {
		t.Fatalf("unexpected video range: %d (%s)", rec.Body.Len(), rec.Header().Get("Content-Type"))
	}
	publish(second)
	check(do("GET", videoPath(first), "student", "", nil), http.StatusNotFound)
	check(do("HEAD", videoPath(second), "student", "", nil), http.StatusOK)

}
