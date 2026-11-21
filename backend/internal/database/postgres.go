package database

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// OpenPostgres returns a verified connection pool. The caller must close it.
func OpenPostgres(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	databaseURL = strings.TrimSpace(databaseURL)
	if databaseURL == "" {
		return nil, errors.New("DATABASE_URL is required")
	}

	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, errors.New("invalid PostgreSQL connection configuration")
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		// Driver errors can contain connection details.
		return nil, errors.New("PostgreSQL connection check failed")
	}
	return pool, nil
}
