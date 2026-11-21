package main

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/httpapi"
	"github.com/opsst/PromptLearn/backend/internal/openai"
	"github.com/opsst/PromptLearn/backend/internal/syllabus"
)

const modelTimeout = 60 * time.Second

func main() {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	var planner syllabus.Planner = syllabus.CurriculumPlanner{}
	mode := strings.TrimSpace(os.Getenv("SYLLABUS_PLANNER"))
	key := strings.TrimSpace(os.Getenv("OPENAI_API_KEY"))
	switch mode {
	case "", "auto", "mock", "openai":
	default:
		log.Fatal("SYLLABUS_PLANNER must be auto, mock or openai")
	}
	if mode == "openai" && key == "" {
		log.Fatal("OPENAI_API_KEY is required when SYLLABUS_PLANNER=openai")
	}
	if mode != "mock" && key != "" {
		model := strings.TrimSpace(os.Getenv("OPENAI_MODEL"))
		if model == "" {
			model = "gpt-4.1-mini"
		}
		client := openai.NewClient(key, model, &http.Client{Timeout: modelTimeout})
		planner = syllabus.OpenAIPlanner{Client: client}
	}

	dataDir := os.Getenv("PROMPTLEARN_DATA_DIR")
	if dataDir == "" {
		dataDir = ".promptlearn-data"
	}
	store, err := course.OpenStore(dataDir)
	if err != nil {
		log.Fatal(err)
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           httpapi.NewHandler(syllabus.NewService(planner), store),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      modelTimeout + 15*time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("PromptLearn listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}
