package main

import (
	"context"
	"flag"
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
	importDirectory := flag.String("import-syllabi", "", "import legacy syllabus JSON records from a directory and exit")
	flag.Parse()
	if flag.NArg() != 0 {
		log.Fatal("unexpected command arguments")
	}

	databaseURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	var store httpapi.CourseStore
	if databaseURL != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		postgres, err := course.OpenPostgres(ctx, databaseURL)
		cancel()
		if err != nil {
			log.Fatal(err)
		}
		defer postgres.Close()

		if *importDirectory != "" {
			ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
			count, err := postgres.ImportLocal(ctx, *importDirectory)
			cancel()
			if err != nil {
				log.Fatal(err)
			}
			log.Printf("Imported %d syllabus records", count)
			return
		}
		store = postgres
		log.Print("Using PostgreSQL syllabus storage")
	} else {
		if *importDirectory != "" {
			log.Fatal("DATABASE_URL is required to import syllabus records")
		}
		dataDir := os.Getenv("PROMPTLEARN_DATA_DIR")
		if dataDir == "" {
			dataDir = ".promptlearn-data"
		}
		local, err := course.OpenStore(dataDir)
		if err != nil {
			log.Fatal(err)
		}
		store = local
	}

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
