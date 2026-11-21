package assignmentreview

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// DemoRepository stores synthetic student reviews in the local data directory.
type DemoRepository struct {
	dir    string
	engine string
}

type reviewEvidence struct {
	Text           string  `json:"text"`
	Blocks         []Block `json:"blocks"`
	FocusedBlockID string  `json:"focused_block_id,omitempty"`
	ImageSupplied  bool    `json:"image_supplied"`
}

func evidenceFrom(work Submission) reviewEvidence {
	return reviewEvidence{
		Text: work.Text, Blocks: work.Blocks,
		FocusedBlockID: work.FocusedBlockID, ImageSupplied: work.ImageDataURL != "",
	}
}

type demoEvent struct {
	StudentID string         `json:"student_id"`
	Engine    string         `json:"engine"`
	Language  string         `json:"language"`
	CreatedAt time.Time      `json:"created_at"`
	Evidence  reviewEvidence `json:"evidence"`
	Result    Result         `json:"result"`
}

func OpenDemoRepository(dir, engine string) (*DemoRepository, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &DemoRepository{dir: dir, engine: engine}, nil
}

func (r *DemoRepository) SaveReview(ctx context.Context, work Submission, result Result) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	result.ReviewID = rand.Text()
	event := demoEvent{
		StudentID: DemoStudentID, Engine: r.engine, Language: reviewLanguage(work), CreatedAt: time.Now().UTC(),
		Evidence: evidenceFrom(work), Result: result,
	}
	file, err := os.CreateTemp(r.dir, ".review-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if err := json.NewEncoder(file).Encode(event); err != nil {
		return "", err
	}
	if err := file.Sync(); err != nil {
		return "", err
	}
	if err := file.Close(); err != nil {
		return "", err
	}
	if err := os.Rename(file.Name(), filepath.Join(r.dir, result.ReviewID+".json")); err != nil {
		return "", err
	}
	return result.ReviewID, nil
}

func reviewLanguage(work Submission) string {
	if work.Language == "th" {
		return "th"
	}
	return "en"
}
