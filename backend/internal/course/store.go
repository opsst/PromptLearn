package course

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

var (
	ErrNotFound = errors.New("course not found")
	ErrNotReady = errors.New("publishing requires a complete teaching schedule and 100 assessment points")
)

type Repository interface {
	Create(context.Context, Preview) (Saved, error)
	Get(context.Context, string) (Saved, error)
	Update(context.Context, string, Preview) (Saved, error)
	Publish(context.Context, string) (Saved, error)
	StudentView(context.Context, string) (StudentView, error)
}

type Saved struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Preview
}

type StudentView struct {
	ID                string            `json:"id"`
	CourseName        string            `json:"course_name"`
	CourseCode        string            `json:"course_code,omitempty"`
	Grade             int               `json:"grade"`
	Term              int               `json:"term"`
	AssessmentWeights []syllabus.Weight `json:"assessment_weights"`
	Schedule          teaching.Schedule `json:"schedule"`
}

type record struct {
	Draft     Saved        `json:"draft"`
	Published *StudentView `json:"published,omitempty"`
}

// Store keeps local course records and serializes changes within one server.
type Store struct {
	dir string
	mu  sync.Mutex
}

func OpenStore(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("create course data directory: %w", err)
	}
	return &Store{dir: dir}, nil
}

func (s *Store) Create(_ context.Context, preview Preview) (Saved, error) {
	var random [16]byte
	if _, err := rand.Read(random[:]); err != nil {
		return Saved{}, fmt.Errorf("generate course id: %w", err)
	}
	saved := Saved{ID: hex.EncodeToString(random[:]), Status: "draft", Preview: preview}
	if err := s.write(record{Draft: saved}); err != nil {
		return Saved{}, err
	}
	return saved, nil
}

func (s *Store) Get(_ context.Context, id string) (Saved, error) {
	data, err := s.read(id)
	if err == nil {
		err = restoreHTML(&data.Draft.Preview)
	}
	return data.Draft, err
}

func (s *Store) Update(_ context.Context, id string, preview Preview) (Saved, error) {
	return s.change(id, func(data *record) error {
		data.Draft.Preview = preview
		if data.Published != nil {
			data.Draft.Status = "unpublished_changes"
		}
		return nil
	})
}

func (s *Store) Publish(_ context.Context, id string) (Saved, error) {
	saved, err := s.change(id, func(data *record) error {
		draft := data.Draft
		if draft.Schedule == nil || len(draft.Syllabus.AssessmentWeights) == 0 {
			return ErrNotReady
		}
		studentView := publishedView(draft)
		data.Published = &studentView
		data.Draft.Status = "published"
		return nil
	})
	if err == nil {
		err = restoreHTML(&saved.Preview)
	}
	return saved, err
}

func (s *Store) StudentView(_ context.Context, id string) (StudentView, error) {
	data, err := s.read(id)
	if err != nil {
		return StudentView{}, err
	}
	if data.Published == nil {
		return StudentView{}, ErrNotFound
	}
	return *data.Published, nil
}

func (s *Store) change(id string, update func(*record) error) (Saved, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := s.read(id)
	if err != nil {
		return Saved{}, err
	}
	if err := update(&data); err != nil {
		return Saved{}, err
	}
	if err := s.write(data); err != nil {
		return Saved{}, err
	}
	return data.Draft, nil
}

func (s *Store) read(id string) (record, error) {
	if len(id) != 32 {
		return record{}, ErrNotFound
	}
	if _, err := hex.DecodeString(id); err != nil {
		return record{}, ErrNotFound
	}
	data, err := os.ReadFile(s.path(id))
	if errors.Is(err, os.ErrNotExist) {
		return record{}, ErrNotFound
	}
	if err != nil {
		return record{}, err
	}
	var stored record
	err = json.Unmarshal(data, &stored)
	return stored, err
}

func (s *Store) write(data record) error {
	data.Draft.Syllabus.DocumentHTML = ""
	file, err := os.CreateTemp(s.dir, ".draft-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if err := json.NewEncoder(file).Encode(data); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), s.path(data.Draft.ID))
}

func (s *Store) path(id string) string {
	return filepath.Join(s.dir, id+".json")
}

func publishedView(draft Saved) StudentView {
	return StudentView{
		ID: draft.ID, CourseName: draft.Syllabus.CourseName, CourseCode: draft.Syllabus.CourseCode,
		Grade: draft.Syllabus.Grade, Term: draft.Syllabus.Term,
		AssessmentWeights: draft.Syllabus.AssessmentWeights, Schedule: *draft.Schedule,
	}
}
