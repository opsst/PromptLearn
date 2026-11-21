// Package openai implements the Responses API transport for structured generation.
package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const maxResponseBytes = 2 << 20

type Client struct {
	key      string
	model    string
	http     *http.Client
	endpoint string
}

func NewClient(key, model string, client *http.Client) *Client {
	return &Client{key: key, model: model, http: client, endpoint: "https://api.openai.com/v1/responses"}
}

type JSONRequest struct {
	Input        string
	Instructions string
	SchemaName   string
	Schema       json.RawMessage
}

type responseFormat struct {
	Type   string          `json:"type"`
	Name   string          `json:"name"`
	Strict bool            `json:"strict"`
	Schema json.RawMessage `json:"schema"`
}

type responseRequest struct {
	Model        string `json:"model"`
	Input        string `json:"input"`
	Instructions string `json:"instructions"`
	Store        bool   `json:"store"`
	Text         struct {
		Format responseFormat `json:"format"`
	} `json:"text"`
}

type response struct {
	Status string `json:"status"`
	Output []struct {
		Type    string `json:"type"`
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	} `json:"output"`
}

func (c *Client) GenerateJSON(ctx context.Context, input JSONRequest) (json.RawMessage, error) {
	payload := responseRequest{Model: c.model, Input: input.Input, Instructions: input.Instructions}
	payload.Text.Format = responseFormat{Type: "json_schema", Name: input.SchemaName, Strict: true, Schema: input.Schema}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.key)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OpenAI returned HTTP %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return nil, err
	}
	if len(raw) > maxResponseBytes {
		return nil, errors.New("OpenAI response too large")
	}
	var result response
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, fmt.Errorf("decode OpenAI response: %w", err)
	}
	if result.Status != "completed" {
		return nil, fmt.Errorf("OpenAI response status %q", result.Status)
	}
	return result.structuredOutput()
}

func (r response) structuredOutput() (json.RawMessage, error) {
	var output strings.Builder
	for _, item := range r.Output {
		if item.Type != "message" {
			continue
		}
		for _, content := range item.Content {
			switch content.Type {
			case "refusal":
				return nil, errors.New("OpenAI refused to generate a syllabus")
			case "output_text":
				output.WriteString(content.Text)
			}
		}
	}
	raw := json.RawMessage(output.String())
	if !json.Valid(raw) {
		return nil, errors.New("OpenAI returned no valid JSON")
	}
	return raw, nil
}
