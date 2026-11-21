# PromptLearn

แพลตฟอร์มสนับสนุน Teaching and Learning Cycle สำหรับครูและนักเรียน

## โครงสร้าง repository

- `frontend/` — แอป Flutter สำหรับครูและนักเรียน
- `backend/` — Go HTTP service พร้อม endpoint สำหรับทดสอบการเชื่อมต่อ

## ขอบเขตแอป

- ออกแบบ Course Syllabus และ Lesson Plan จากมาตรฐานการเรียนรู้หรือ textbook
- จัดการคาบเรียน การเช็คชื่อ และ recordings/transcripts
- Formative และ summative assessments
- Student AI tutoring ที่อ้างอิงเนื้อหาการเรียน
- Analytics และข้อเสนอแนะเพื่อปรับปรุงการสอน

เริ่มรันแอป Flutter สำหรับ iOS และ Android ได้ตาม [คู่มือ frontend](frontend/README.md) โดยออกแบบสำหรับแท็บเล็ตเป็นหลัก

ดูวิธีรันและทดสอบ `GET /healthz` ใน [README ของ backend](backend/README.md)
