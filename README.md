# PromptLearn

PromptLearn supports the Teaching and Learning Cycle for teachers and students. Teachers plan courses, run lessons, and design assessments. Students follow lessons, complete homework, and ask for hints as they work through problems. The Flutter app is designed primarily for tablets.

## Features you can try

- **Course Syllabus.** Teachers use a six-step wizard to build a syllabus from Thailand’s OBEC mathematics standards for Grades 7–12 (Matthayom 1–6). They can organize units, periods, scores, and class schedules. With the Go backend connected, they can download the syllabus as HTML, save drafts, and publish. [Syllabus guide](frontend/README.md)
- **Classroom and replay.** Teachers can start a class and record their screen on Android. The replay demo supports video upload, transcription, and playback from transcript timestamps. [Replay demo guide](backend/README.md)
- **Assessment and homework.** Teachers can author questions and draft scoring rubrics. Students can show their work in a digital notebook, get step-by-step hints, and see their results after submitting. [Homework guide](frontend/HOMEWORK_CHECKER.md)
- **Ask Prompt Learn.** Teachers and students can move the AI button anywhere on screen and open the chat from any signed-in page. The conversation stays available as they navigate. Student replies focus on guiding questions and hints.

The roadmap includes lesson plans for individual periods, teaching materials, attendance, and learning and teaching analytics.

## Run on an Android Emulator

Use Go 1.24 or later and a Flutter SDK compatible with the Dart version specified by the project. [Flutter pubspec](frontend/pubspec.yaml)

1. Start the Go backend from the repository root.

   ```sh
   cd backend
   go run ./cmd/server
   ```

   Check the server with `curl http://127.0.0.1:8080/healthz`. The expected response is `{"status":"ok"}`. To store demo data in PostgreSQL, follow the database setup below before starting the server.

2. Start a tablet emulator, then run these commands from the repository root in another terminal. Replace `emulator-5554` with the device ID shown by `flutter devices`.

   ```sh
   cd frontend
   flutter pub get
   adb -s emulator-5554 reverse tcp:8080 tcp:8080
   flutter run -d emulator-5554 --dart-define=PROMPTLEARN_API_BASE_URL=http://127.0.0.1:8080
   ```

3. Select **Login as Teacher** or **Login as Student**. The app remembers your role on the device. Tap the PromptLearn logo to choose a different role.

### Enable Ask Prompt Learn

Set `OPENAI_API_KEY` in the Go backend environment before starting the server. If you keep it in `backend/.env`, run `set -a`, `. ./.env`, and `set +a` from `backend/` before starting the server. Run Flutter with `PROMPTLEARN_API_BASE_URL` as shown above. [Backend configuration guide](backend/README.md)

## Connect PostgreSQL for local development

1. Start PostgreSQL 14 or later. From the repository root, use `createdb` and `psql` to create a fresh database, apply the migrations, and load the sample data.

   ```sh
   createdb promptlearn_dev
   psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/schema.sql
   psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/course_syllabus.sql
   psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/assignment_review.sql
   psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/demo_seed.sql
   psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/assignment_review_demo_seed.sql
   ```

2. Copy `backend/.env.example` to `backend/.env` if the file does not already exist. Set the following values for a local Unix socket connection.

   ```dotenv
   DATABASE_URL='postgresql:///promptlearn_dev'
   COURSE_SYLLABUS_DATABASE_URL='postgresql:///promptlearn_dev'
   ASSIGNMENT_REVIEW_DATABASE_URL='postgresql:///promptlearn_dev'
   HTTP_ADDR='127.0.0.1:8080'
   ```

   For a local TCP connection without TLS, use a URL such as `postgresql://USER:PASSWORD@127.0.0.1:5432/promptlearn_dev?sslmode=disable` with your PostgreSQL credentials. Use the same host and account for the migration commands by setting `PGHOST`, `PGPORT`, and `PGUSER` as needed. `DATABASE_URL` is used by the connection check. The feature-specific URLs enable PostgreSQL storage for syllabus and assignment review.

3. From the repository root, load the configuration, verify the database connection, and start the backend. If a backend process is already running, stop it first.

   ```sh
   cd backend
   set -a
   . ./.env
   set +a
   go run ./cmd/dbcheck
   go run ./cmd/server
   ```

   The connection check prints `PostgreSQL connection OK`. Flutter continues to connect through the Go API at `PROMPTLEARN_API_BASE_URL`.

For the video replay demo, set `REPLAY_DEMO_DATABASE_URL` and configure FFmpeg and transcription. [Replay setup guide](backend/README.md)

## Repository structure

- `frontend/` — Flutter app for teachers and students. [Frontend guide](frontend/README.md)
- `backend/` — Go HTTP API for curriculum, scheduling, assessment, replay, and AI. [Backend guide](backend/README.md) · [API reference](backend/api-spec/index.html)
- `db_migration/` — PostgreSQL schema, migrations, and demo seed data. [Database guide](db_migration/README.md)
