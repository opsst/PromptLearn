package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/course"
	"github.com/opsst/PromptLearn/backend/internal/httpapi"
	"github.com/opsst/PromptLearn/backend/internal/openai"
	"github.com/opsst/PromptLearn/backend/internal/replay"
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

	syllabi := syllabus.NewService(planner)
	handler := httpapi.NewHandler(syllabi, store)
	readTimeout := 10 * time.Second
	if databaseURL := os.Getenv("REPLAY_DEMO_DATABASE_URL"); databaseURL != "" {
		host, _, err := net.SplitHostPort(addr)
		if err != nil || !httpapi.IsLoopbackHost(host) {
			log.Fatal("the replay demo requires a loopback HTTP_ADDR")
		}
		if _, err := exec.LookPath("ffprobe"); err != nil {
			log.Fatal("the replay demo requires ffprobe on PATH")
		}
		mediaDir := filepath.Join(dataDir, "replay")
		if err := os.MkdirAll(mediaDir, 0700); err != nil {
			log.Fatal(err)
		}
		webDir := os.Getenv("REPLAY_DEMO_WEB_DIR")
		if webDir != "" {
			if _, err := os.Stat(filepath.Join(webDir, "index.html")); err != nil {
				log.Fatal("REPLAY_DEMO_WEB_DIR must point to a built Flutter web app")
			}
			if err := checkReplayDirectories(mediaDir, webDir); err != nil {
				log.Fatal(err)
			}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		replays, err := replay.Open(ctx, databaseURL)
		cancel()
		if err != nil {
			log.Fatalf("open replay database: %v", err)
		}
		defer replays.Close()
		handler = httpapi.NewDemoHandler(syllabi, store, replays, mediaDir, webDir)
		readTimeout = 90 * time.Second
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       readTimeout,
		WriteTimeout:      modelTimeout + 15*time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("PromptLearn listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}

func checkReplayDirectories(mediaDir, webDir string) error {
	var paths []string
	for _, directory := range []string{mediaDir, webDir} {
		resolved, err := filepath.EvalSymlinks(directory)
		if err != nil {
			return err
		}
		absolute, err := filepath.Abs(resolved)
		if err != nil {
			return err
		}
		paths = append(paths, absolute)
	}
	if paths[0] == paths[1] || strings.HasPrefix(paths[0], paths[1]+string(os.PathSeparator)) || paths[1] == string(os.PathSeparator) {
		return errors.New("replay files must be stored outside the Flutter web directory")
	}
	return nil
}
