# PromptLearn database

[schema.sql](./schema.sql) เป็น initial migration สำหรับ PostgreSQL 14 ขึ้นไป และ [ERD.md](./ERD.md) แสดงความสัมพันธ์ตาม frontend flow ทั้งสามส่วน

## สร้างฐานข้อมูล

รันจาก root ของ PromptLearn บนฐานข้อมูลที่ยังไม่มี schema `promptlearn` โดยใช้การตั้งค่าการเชื่อมต่อของ PostgreSQL ในเครื่อง

```sh
createdb promptlearn_dev
psql -X -v ON_ERROR_STOP=1 -d promptlearn_dev -f db_migration/schema.sql
```

Migration ทำงานใน transaction เดียว ตัวอย่าง query ใช้ชื่อแบบ `promptlearn.course_offerings` ตั้งค่าการเชื่อมต่อของ backend ให้เข้าถึง schema นี้ตามสิทธิ์ของบริการ

## การตัดสินใจตาม frontend flow

| Flow | วิธีเก็บข้อมูล |
|---|---|
| Basics & timetable | `course_offerings` เชื่อมวิชากับห้องประจำเทอม `weekly_timetable_slots` เก็บคาบประจำรายห้อง ส่วน `school_calendar_events` ใช้ตัดวันหยุดหรือกันช่วงสอบ ช่องเวลาใช้เวลาท้องถิ่นของโรงเรียนและคาบจริงใช้ `timestamptz` |
| Standards & sources | ตารางกลางเก็บตัวชี้วัดพร้อมฉบับหลักสูตร `learning_outcomes` ใช้ได้กับตัวชี้วัดมาตรฐานและเกณฑ์ที่ครูเขียนเอง `outcome_chapter_matches` เก็บคู่ที่ AI เสนอหรือครูยืนยัน |
| Units & periods | ลำดับคือ unit → lesson → planned period → session หัวข้อหนึ่งมีได้หลายคาบตามแผน คาบปฐมนิเทศหรือคาบสำรองอยู่ในลำดับเดียวกันได้ การเลื่อนเวลาคาบจริงแก้เวลาโดยรักษา session ID เดิม |
| Review & publish | ร่าง syllabus กับฉบับที่แต่ละห้องเห็นแยกกันผ่าน `offering_syllabus_publications` มี active publication ได้หนึ่งฉบับต่อห้อง แผนรายคาบมีฉบับและเก็บ IBL, 5E, CPA, Flipped หรือแบบที่ครูเขียนเอง |
| Score split & schedule | `grading_plan_items` เก็บน้ำหนักรวม 100 และแบ่งระหว่างเทอมกับปลายภาค `assessment_events` วางวันสอบและขอบเขตหน่วยได้ก่อนมีโจทย์ งานคิดเกรดโยงหมวดผ่าน `assignment_grading_items` |
| สอนและเช็กชื่อ | `lesson_sessions` เก็บตัวเลือกบันทึก สตรีม และติดตามการตอบ `attendance_windows` เก็บช่วงเปิด เกณฑ์สาย และรัศมี `attendance_records` เก็บผลและผู้แก้รายการ โดยไม่มีคอลัมน์พิกัดนักเรียน |
| Replay & reflection | `lesson_publications` คุมสิ่งที่ห้องเห็น แยกจากสถานะใน `background_jobs` บทคลิปและโจทย์อ้าง offset หน่วยมิลลิวินาที `replay_progress.watched_ms` เก็บ union ของช่วงที่ดู AI อ้างถึง transcript segment ฉบับที่ใช้จริง และ `session_events` ใช้สรุปจังหวะคาบ |
| สร้างและตรวจแบบประเมิน | `assessment_versions` ตรึงโจทย์และ rubric ให้กับงานแต่ละห้อง `question_imports` เก็บรูปโจทย์และผล OCR รอตรวจ เกณฑ์ให้คะแนนรองรับระดับ Full / Partial / None และเก็บผลตรวจ AI แยกจากคะแนนที่เผยแพร่ |
| Guided practice & analytics | คำตอบที่ตรวจหลายครั้งเก็บเป็น `response_revisions` การวงวิธีทำอ้างฉบับและหน้าผ่าน `response_annotations` ใช้รหัส `misconceptions` เดียวกันสรุปข้อผิดข้าม quiz และ homework สำหรับโจทย์เฉพาะบุคคลให้สร้าง assessment version ของชุดโจทย์นั้นและมอบหมายแบบ `selected_students` พร้อมอ้างถึง feedback ต้นทาง |

ภาพรวมคะแนนรายข้อ สัดส่วนเวลาเรียน ความคืบหน้ารายหัวข้อ และ practice streak คำนวณจากคาบจริง การส่งงาน ผลตรวจ และเหตุการณ์ที่บันทึกไว้ หน้า analytics สามารถเพิ่ม query หรือ view เมื่อสูตรของแต่ละ metric ตกลงแล้ว

## กติกาที่ backend ต้องบังคับ

- **สิทธิ์** ตรวจโรงเรียน ห้อง บทบาท และเจ้าของคำตอบก่อนอ่านหรือแก้ไขทุกครั้ง รวมถึง foreign key ไปยัง asset หรือแหล่งอ้างอิงข้ามส่วน แจก signed URL หลังตรวจสิทธิ์เท่านั้น ผู้ปกครองเข้าถึงได้เมื่อมี verified link และครูเปิดการแชร์ Schema นี้ยังไม่มี RLS หรือการตั้ง role สำหรับ production
- **ฉบับและการเผยแพร่** autosave ใช้ร่างเดิม และการแก้เนื้อหาที่เผยแพร่แล้วให้สร้างฉบับใหม่ ใน transaction เดียวให้ตรวจความครบถ้วน ปิด publication เดิม และเปิดฉบับใหม่สำหรับห้องที่เลือก คาบที่เริ่มแล้วเก็บฉบับเดิมไว้ ตรวจว่าคลิปและ transcript พร้อมก่อนเผยแพร่และแจ้งเตือนเมื่อวันในตารางที่เผยแพร่เปลี่ยน
- **ตารางและคะแนน** ตรวจช่วงวันเทอม ความขัดแย้งของคาบ จำนวนคาบ และคะแนนรวม 100 ก่อน publish ตรวจคะแนน rubric แต่ละระดับและคะแนนรวมเทียบเพดานโจทย์ กรณี assessment event มีคาบจริงให้อ่านวันจากคาบนั้น ส่วนวันสอบนอกคาบอ่านจาก event คิดคะแนนรวมหมวดจากคะแนนที่เผยแพร่และแยกสถานะยังไม่ตรวจออกจากคะแนนศูนย์
- **การสอบและการตรวจ** ตรวจเวลาส่ง จำนวนครั้ง บทบาทผู้เรียน และสิทธิ์ผู้รับงาน เก็บลำดับสลับข้อเมื่อเริ่มทำ ส่งงานพร้อมตรึง revision ที่ส่งใน transaction เดียว แสดงคำใบ้เฉพาะงานที่อนุญาต เก็บ answer key และ rubric ฝั่งครู และเผยแพร่คะแนนจากผลตรวจที่ยอมรับแล้ว
- **คลิปและความเป็นส่วนตัว** ตรวจช่วงเวลาว่าอยู่ในคลิป เก็บช่วงที่ดูด้วย union อะตอมมิกเพื่อกันการนับซ้ำ ใช้พิกัดนักเรียนชั่วคราวตอนตรวจเช็กชื่อ รวมถึงงดบันทึกใน payload ของคิวหรือ request log ส่วนไฟล์สื่อและภาพคำตอบใช้ object storage และเก็บ metadata ใน `assets`
- **งานเบื้องหลัง** ให้ worker claim งานและรองรับ retry โดยใช้ `idempotency_key` กันการสร้างงานซ้ำ `payload` เก็บรหัสแถวที่เกี่ยวข้อง เช่น ไฟล์นำเข้าตาราง คาบ หรือคลิป ส่วนผลลัพธ์ถาวรเขียนลงตารางของ flow นั้น

## Migration สำหรับ syllabus API

หลังใช้ `schema.sql` ให้ใช้ [002_syllabus_api_records.sql](./002_syllabus_api_records.sql)
เพื่อเพิ่ม persistence สำหรับ API syllabus ปัจจุบัน ตารางนี้เก็บร่างและ snapshot ที่เผยแพร่
ตาม contract ของ API ดูวิธีเปิดใช้ PostgreSQL และนำเข้าไฟล์เดิมใน [Backend README](../backend/README.md)
