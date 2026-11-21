# PromptLearn

แพลตฟอร์มสนับสนุน Teaching and Learning Cycle สำหรับครูและนักเรียน ครูวางแผนการสอน จัดคาบเรียน และออกแบบการวัดผล นักเรียนติดตามบทเรียน ทำการบ้าน และขอคำใบ้ระหว่างฝึกทำโจทย์ แอป Flutter ออกแบบสำหรับแท็บเล็ตเป็นหลัก

## ฟีเจอร์ที่ทดลองได้

- **Course Syllabus** — ครูสร้างโครงรายวิชา 6 ขั้นตอนจากตัวชี้วัดคณิตศาสตร์ สพฐ. ระดับ ม.1–ม.6 จัดหน่วย คาบเรียน คะแนน และตารางรายห้อง เมื่อเชื่อมต่อ Go backend ครูดาวน์โหลด HTML บันทึกร่าง และเผยแพร่ได้ [คู่มือสร้าง syllabus](frontend/README.md)
- **การสอนและคลิปย้อนหลัง** — ครูเริ่มคาบและบันทึกหน้าจอบน Android ได้ เดโมคลิปย้อนหลังรองรับการอัปโหลด ถอดเสียง และเปิดคลิปจากตำแหน่งเวลาใน transcript [คู่มือเดโม](backend/README.md)
- **การวัดผลและการบ้าน** — ครูสร้างโจทย์และร่างเกณฑ์ให้คะแนน นักเรียนเขียนวิธีทำในสมุดดิจิทัล รับคำใบ้ทีละขั้น และดูผลหลังส่งงาน [คู่มือหน้าการบ้าน](frontend/HOMEWORK_CHECKER.md)
- **Ask Prompt Learn** — ครูและนักเรียนลากปุ่ม AI ไปวางบนหน้าจอและเปิดแชตได้จากทุกหน้าหลังเลือกบทบาท บทสนทนาคงอยู่เมื่อเปลี่ยนหน้า คำตอบสำหรับนักเรียนเน้นคำถามชี้แนะและคำใบ้

แผนต่อยอดครอบคลุมแผนการสอนรายคาบ สื่อการสอน การเช็กชื่อ และการวิเคราะห์ผลการเรียนกับการสอน

## เริ่มใช้งานบน Android Emulator

เตรียม Go 1.24 ขึ้นไปและ Flutter SDK ที่รองรับเวอร์ชัน Dart ที่โปรเจกต์กำหนด [Flutter pubspec](frontend/pubspec.yaml)

1. เปิด Go backend จากโฟลเดอร์หลักของ repo

   ```sh
   cd backend
   go run ./cmd/server
   ```

   ตรวจว่า backend พร้อมรับคำขอด้วย `curl http://127.0.0.1:8080/healthz` ผลที่คาดไว้คือ `{"status":"ok"}`

2. เปิด Android Emulator แบบแท็บเล็ต แล้วรันคำสั่งจากโฟลเดอร์หลักของ repo ในอีก terminal ตัวอย่างใช้ `emulator-5554` ซึ่งตรวจสอบได้ด้วย `flutter devices`

   ```sh
   cd frontend
   flutter pub get
   adb -s emulator-5554 reverse tcp:8080 tcp:8080
   flutter run -d emulator-5554 --dart-define=PROMPTLEARN_API_BASE_URL=http://127.0.0.1:8080
   ```

3. เลือก **Login as Teacher** หรือ **Login as Student** แอปจะจำบทบาทไว้ในเครื่อง กดโลโก้ PromptLearn เพื่อกลับไปหน้าเลือกบทบาท

### เปิดใช้งาน Ask Prompt Learn

ตั้ง `OPENAI_API_KEY` ใน environment ของ Go backend ก่อนรัน server หากเก็บค่าไว้ใน `backend/.env` ให้โหลดตัวแปรจากไฟล์ตามคู่มือก่อนเริ่ม server จากนั้นเปิดแอปด้วย `PROMPTLEARN_API_BASE_URL` ตามขั้นตอนด้านบน [คู่มือตั้งค่า backend](backend/README.md)

## โครงสร้าง repository

- `frontend/` — แอป Flutter สำหรับครูและนักเรียน [คู่มือ frontend](frontend/README.md)
- `backend/` — Go HTTP API สำหรับหลักสูตร ตารางสอน การวัดผล คลิปย้อนหลัง และ AI [คู่มือ backend](backend/README.md) · [API Reference](backend/api-spec/index.html)
- `db_migration/` — schema และข้อมูลตั้งต้นของ PostgreSQL สำหรับเดโม [คู่มือฐานข้อมูล](db_migration/README.md)
