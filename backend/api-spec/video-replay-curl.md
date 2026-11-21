# ทดลอง Video Replay API ด้วย curl

ใช้คำสั่งจาก root ของ repo โดยเปิด Go backend ที่ `127.0.0.1:8080` และลง schema กับ demo seed ตาม [วิธีรันเดโมคลิปย้อนหลัง](../README.md#รันเดโมคลิปย้อนหลัง) ต้องมี `curl` กับ `jq` สำหรับตัวอย่างนี้ ทดสอบ API ได้โดยเปิดเฉพาะ Go backend แล้วกำหนด `REPLAY_DEMO_DATABASE_URL` คำสั่งใช้คลิปและ transcript ตัวอย่างใน `backend/examples/`

## 1. ครูอัปโหลดคลิปและ transcript

```bash
set -o pipefail
promptlearn_url=${PROMPTLEARN_URL:-http://127.0.0.1:8080}

recording_id=$(curl --fail-with-body --silent --show-error \
  "$promptlearn_url/api/demo/recordings" \
  -H 'X-Demo-Role: teacher' \
  -F 'video=@backend/examples/thai-lesson.mp4;type=video/mp4' \
  -F 'transcript=@backend/examples/thai-lesson.transcript.json;type=application/json' \
  | jq -er '.recordingId')

printf 'recordingId=%s\n' "$recording_id"
```

เมื่อรับไฟล์และตรวจ transcript สำเร็จ API ตอบ `201 Created` พร้อม `recordingId` ของฉบับร่าง URL ของไฟล์ฉบับร่างตอบ `404` จนกว่าจะเผยแพร่

## 2. ครูเผยแพร่คลิป

```bash
jq -n --arg id "$recording_id" '{recordingId: $id}' \
  | curl --fail-with-body --silent --show-error \
      -X PUT "$promptlearn_url/api/demo/publication" \
      -H 'X-Demo-Role: teacher' \
      -H 'Content-Type: application/json' \
      --data-binary @- \
  | jq .
```

API ตอบ `200 OK` พร้อม `recordingId` ของคลิปที่เผยแพร่ ใช้ `X-Demo-Role: teacher` สำหรับการอัปโหลดและเผยแพร่ในโหมดเดโม

## 3. นักเรียนเรียกข้อมูลย้อนหลังและดาวน์โหลด MP4

```bash
replay_json=$(curl --fail-with-body --silent --show-error \
  "$promptlearn_url/api/demo/replay")

printf '%s\n' "$replay_json" \
  | jq '{published, recordingId, durationMs, videoUrl, transcript}'

video_path=$(printf '%s\n' "$replay_json" | jq -er '.videoUrl')
curl --fail-with-body --silent --show-error \
  "$promptlearn_url$video_path" -o replay.mp4
```

เมื่อมีคลิปที่เผยแพร่แล้ว API คืน `published: true` พร้อม URL แบบ relative และ transcript ที่ใช้หน่วยมิลลิวินาที ถ้าคาบยังไม่เคยเผยแพร่ API ตอบ `200 OK` พร้อม `{"published":false}` ฝั่งนักเรียนเรียกดูได้โดยไม่ต้องส่ง header บทบาท

## 4. ตรวจ HTTP Range สำหรับการเลื่อนวิดีโอ

```bash
curl --fail-with-body --silent --show-error \
  -H 'Range: bytes=0-1023' \
  -D - -o /dev/null \
  "$promptlearn_url$video_path"
```

ควรได้ `206 Partial Content` พร้อม `Content-Range` ของช่วงไบต์ที่ขอ ดู [OpenAPI](openapi.yaml) หรือ [HTML API Reference](index.html#uploadReplayRecording) สำหรับรายละเอียดแต่ละ endpoint
