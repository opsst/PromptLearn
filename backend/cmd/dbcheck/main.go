package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/opsst/PromptLearn/backend/internal/database"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	pool, err := database.OpenPostgres(ctx, os.Getenv("DATABASE_URL"))
	cancel()
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	log.Print("PostgreSQL connection OK")
}
