package openai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestStructuredResponseReadsAssistantTextAfterReasoning(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/v1/responses" || r.Header.Get("Authorization") != "Bearer test-key" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		var payload struct {
			Store *bool `json:"store"`
			Text  struct {
				Format struct {
					Strict bool   `json:"strict"`
					Type   string `json:"type"`
				} `json:"format"`
			} `json:"text"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || payload.Store == nil ||
			*payload.Store || !payload.Text.Format.Strict || payload.Text.Format.Type != "json_schema" {
			t.Errorf("wrong request payload: %+v, error %v", payload, err)
		}
		_, _ = w.Write([]byte(`{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"{\"ok\":true}"}]}]}`))
	}))
	defer server.Close()

	client := NewClient("test-key", "test-model", server.Client())
	client.endpoint = server.URL + "/v1/responses"
	raw, err := client.GenerateJSON(context.Background(), JSONRequest{
		SchemaName: "sample", Schema: json.RawMessage(`{"type":"object"}`), Input: "sample",
	})
	if err != nil || string(raw) != `{"ok":true}` {
		t.Fatalf("result = %s, error = %v", raw, err)
	}
}

func TestStructuredRequestCanSendAnImage(t *testing.T) {
	const dataURL = "data:image/png;base64,cGhvdG8="
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var payload struct {
			Input []struct {
				Role    string `json:"role"`
				Content []struct {
					Type     string `json:"type"`
					Text     string `json:"text"`
					ImageURL string `json:"image_url"`
				} `json:"content"`
			} `json:"input"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || len(payload.Input) != 1 ||
			payload.Input[0].Role != "user" || len(payload.Input[0].Content) != 2 {
			t.Errorf("unexpected multimodal input: %+v, error %v", payload, err)
		} else if text, photo := payload.Input[0].Content[0], payload.Input[0].Content[1]; text.Text != "OCR" ||
			text.Type != "input_text" || photo.Type != "input_image" || photo.ImageURL != dataURL {
			t.Errorf("input did not preserve the text and image: %+v", payload.Input[0].Content)
		}
		_, _ = w.Write([]byte(`{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"{}"}]}]}`))
	}))
	defer server.Close()

	client := NewClient("test-key", "test-model", server.Client())
	client.endpoint = server.URL + "/v1/responses"
	if _, err := client.GenerateJSON(context.Background(), JSONRequest{
		Input: "OCR", ImageDataURL: dataURL, SchemaName: "example", Schema: json.RawMessage(`{"type":"object"}`),
	}); err != nil {
		t.Fatal(err)
	}
}
