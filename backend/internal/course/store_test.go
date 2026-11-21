package course

import (
	"errors"
	"testing"

	"github.com/opsst/PromptLearn/backend/internal/syllabus"
	"github.com/opsst/PromptLearn/backend/internal/teaching"
)

func TestPublishedViewOnlyChangesAfterPublishing(t *testing.T) {
	directory := t.TempDir()
	store, err := OpenStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	preview := Preview{
		Syllabus: syllabus.Draft{
			Input: syllabus.Input{CourseName: "คณิตศาสตร์", AssessmentWeights: []syllabus.Weight{{Category: "Quiz", Points: 100}}},
		},
		Schedule: &teaching.Schedule{Timezone: "Asia/Bangkok"},
	}

	saved, err := store.Create(preview)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.StudentView(saved.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unpublished view should be absent: %v", err)
	}
	if _, err := store.Publish(saved.ID); err != nil {
		t.Fatal(err)
	}

	preview.Syllabus.CourseName = "คณิตศาสตร์ ฉบับปรับปรุง"
	updated, err := store.Update(saved.ID, preview)
	if err != nil || updated.Status != "unpublished_changes" {
		t.Fatalf("could not save draft revision: %+v, %v", updated, err)
	}
	reopened, err := OpenStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	view, err := reopened.StudentView(saved.ID)
	if err != nil || view.CourseName != "คณิตศาสตร์" {
		t.Fatalf("draft leaked into published view: %+v, %v", view, err)
	}
	if _, err := reopened.Publish(saved.ID); err != nil {
		t.Fatal(err)
	}
	view, err = reopened.StudentView(saved.ID)
	if err != nil || view.CourseName != "คณิตศาสตร์ ฉบับปรับปรุง" {
		t.Fatalf("new published snapshot was not saved: %+v, %v", view, err)
	}
}
