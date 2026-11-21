package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthCheck(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	NewHandler(nil, nil).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if got := response.Header().Get("Content-Type"); got != "application/json" {
		t.Fatalf("Content-Type = %q, want application/json", got)
	}

	var body struct {
		Status string `json:"status"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode health response: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status response = %q, want ok", body.Status)
	}
}

func TestHealthCheckRejectsPost(t *testing.T) {
	request := httptest.NewRequest(http.MethodPost, "/healthz", nil)
	response := httptest.NewRecorder()

	NewHandler(nil, nil).ServeHTTP(response, request)

	if response.Code != http.StatusMethodNotAllowed {
		t.Errorf("status = %d, want %d", response.Code, http.StatusMethodNotAllowed)
	}
}

func TestMathCurriculum(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/v1/curriculum/math?grade=2&course_type=core", nil)
	response := httptest.NewRecorder()
	NewHandler(nil, nil).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", response.Code, response.Body.String())
	}
	var body struct {
		Grade      int    `json:"grade"`
		CourseType string `json:"course_type"`
		Groups     []struct {
			StandardCode string `json:"standard_code"`
		} `json:"groups"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Grade != 2 || body.CourseType != "core" || len(body.Groups) != 5 {
		t.Errorf("wrong curriculum slice: %+v", body)
	}
}

func TestMathCurriculumRejectsUnsupportedCourse(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/v1/curriculum/math?grade=1&course_type=additional", nil)
	response := httptest.NewRecorder()
	NewHandler(nil, nil).ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", response.Code, http.StatusBadRequest)
	}
}
