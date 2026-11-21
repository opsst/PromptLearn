package course

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const queryTimeout = 5 * time.Second

type PostgresStore struct {
	pool *pgxpool.Pool
}

func OpenPostgres(ctx context.Context, databaseURL string) (*PostgresStore, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, errors.New("invalid PostgreSQL connection configuration")
	}

	var exists bool
	err = pool.QueryRow(ctx, "SELECT to_regclass('promptlearn.syllabus_api_records') IS NOT NULL").Scan(&exists)
	if err != nil || !exists {
		pool.Close()
		if err != nil {
			return nil, errors.New("could not connect to PostgreSQL and check the syllabus migration")
		}
		return nil, errors.New("apply db_migration/schema.sql and db_migration/002_syllabus_api_records.sql before starting the backend")
	}
	return &PostgresStore{pool: pool}, nil
}

func (s *PostgresStore) Close() {
	s.pool.Close()
}

func (s *PostgresStore) Create(preview Preview) (Saved, error) {
	draft, err := newDraft(preview)
	if err != nil {
		return Saved{}, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err = s.pool.Exec(ctx, "INSERT INTO promptlearn.syllabus_api_records (id, draft) VALUES ($1, $2)", draft.ID, draft)
	if err != nil {
		return Saved{}, fmt.Errorf("insert syllabus draft: %w", err)
	}
	return draft, nil
}

func (s *PostgresStore) Get(id string) (Saved, error) {
	if !validID(id) {
		return Saved{}, ErrNotFound
	}
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	var draft Saved
	err := s.pool.QueryRow(ctx, "SELECT draft FROM promptlearn.syllabus_api_records WHERE id = $1", id).Scan(&draft)
	if errors.Is(err, pgx.ErrNoRows) {
		return Saved{}, ErrNotFound
	}
	return draft, err
}

func (s *PostgresStore) StudentView(id string) (StudentView, error) {
	if !validID(id) {
		return StudentView{}, ErrNotFound
	}
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	var published StudentView
	err := s.pool.QueryRow(ctx, "SELECT published FROM promptlearn.syllabus_api_records WHERE id = $1 AND published IS NOT NULL", id).Scan(&published)
	if errors.Is(err, pgx.ErrNoRows) {
		return StudentView{}, ErrNotFound
	}
	return published, err
}

func (s *PostgresStore) Update(id string, preview Preview) (Saved, error) {
	return s.change(id, updateDraft(preview))
}

func (s *PostgresStore) Publish(id string) (Saved, error) {
	return s.change(id, publishDraft)
}

func (s *PostgresStore) change(id string, update func(*record) error) (Saved, error) {
	if !validID(id) {
		return Saved{}, ErrNotFound
	}
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return Saved{}, err
	}
	defer tx.Rollback(ctx)

	var data record
	err = tx.QueryRow(ctx, "SELECT draft, published FROM promptlearn.syllabus_api_records WHERE id = $1 FOR UPDATE", id).Scan(&data.Draft, &data.Published)
	if errors.Is(err, pgx.ErrNoRows) {
		return Saved{}, ErrNotFound
	}
	if err != nil {
		return Saved{}, err
	}
	if err := update(&data); err != nil {
		return Saved{}, err
	}
	_, err = tx.Exec(ctx, `
		UPDATE promptlearn.syllabus_api_records
		SET draft = $2, published = $3, updated_at = now()
		WHERE id = $1
	`, id, data.Draft, data.Published)
	if err != nil {
		return Saved{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Saved{}, err
	}
	return data.Draft, nil
}

// ImportLocal copies legacy course records and keeps records already present in PostgreSQL.
func (s *PostgresStore) ImportLocal(ctx context.Context, directory string) (int64, error) {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return 0, err
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	var count int64
	for _, entry := range entries {
		id, isJSON := strings.CutSuffix(entry.Name(), ".json")
		if !isJSON || !validID(id) || !entry.Type().IsRegular() {
			continue
		}
		body, err := os.ReadFile(filepath.Join(directory, entry.Name()))
		if err != nil {
			return 0, err
		}
		var data record
		if err := json.Unmarshal(body, &data); err != nil {
			return 0, fmt.Errorf("decode syllabus %s: %w", id, err)
		}
		if data.Draft.ID != id || (data.Published != nil && data.Published.ID != id) {
			return 0, fmt.Errorf("record ID does not match filename %s", entry.Name())
		}
		inserted, err := tx.Exec(ctx, `
			INSERT INTO promptlearn.syllabus_api_records (id, draft, published)
			VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING
		`, id, data.Draft, data.Published)
		if err != nil {
			return 0, fmt.Errorf("import syllabus %s: %w", id, err)
		}
		count += inserted.RowsAffected()
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return count, nil
}
