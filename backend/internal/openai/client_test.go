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
