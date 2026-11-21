# PromptLearn Frontend

โฟลเดอร์สำหรับแอป **Flutter** ฝั่งครูและนักเรียน

ขอบเขต: syllabus/lesson planning, classroom sessions และ recordings, assessments, AI tutoring และ analytics

[สถาปัตยกรรม Flutter และแนวทางวางไฟล์](ARCHITECTURE.md)

[Design System ของ PromptLearn](DESIGN_SYSTEM.md)

## แนวทางการออกแบบ

ช่วงแรกให้พัฒนาและทดสอบบนแท็บเล็ต Android เป็นหลัก โดยรองรับ iPad ด้วย ออกแบบหน้าจอ ทั้งแนวตั้งและแนวนอน ให้หน้าจอปรับตามพื้นที่หน้าต่างที่มี รวมถึงเมื่อแบ่งหน้าจอหรือใช้งานบนโทรศัพท์

## ทำ UI ของครูและนักเรียนต่อ

หน้าล็อกอินให้เลือก **Login as Teacher** หรือ **Login as Student** แอปบันทึกบทบาทไว้ในเครื่องเพื่อเปิด Home ของบทบาทเดิมเมื่อกลับมา กดโลโก้ PromptLearn เพื่อล้างบทบาทแล้วกลับไปหน้าเลือก

| ส่วนที่จะแก้ | ไฟล์ |
| --- | --- |
| หน้า Home สำหรับครู | [teacher_home_view.dart](lib/ui/features/home/views/teacher_home_view.dart) |
| หน้า Home สำหรับนักเรียน | [student_home_view.dart](lib/ui/features/home/views/student_home_view.dart) |
| ส่วนหัว Home ที่ใช้ร่วมกัน | [home_header.dart](lib/ui/features/home/widgets/home_header.dart) |
| เลือกหน้า Home ตามบทบาทที่ล็อกอิน | [prompt_learn_app.dart](lib/app/prompt_learn_app.dart) |

ตอนนี้ทั้งสองหน้าประกอบ Home Header เดิมไว้พร้อมรับดีไซน์ ใส่ส่วนที่ต่างตามบทบาทใน View ของบทบาทนั้น เก็บส่วนที่ใช้ร่วมกันไว้ใน `widgets/` ของฟีเจอร์ และใช้ธีมกลางจาก [Design System](DESIGN_SYSTEM.md)

## เริ่มใช้งาน

เปิด Android Emulator แบบแท็บเล็ต แล้วรันจากโฟลเดอร์ `frontend/` ตัวอย่างนี้ใช้ ID `emulator-5554` ให้ดู ID ของ Emulator ที่เปิดอยู่จาก `flutter devices`

```sh
flutter pub get
flutter devices
flutter run -d emulator-5554
```

### ทดสอบการสลับบทบาท

1. เลือก **Login as Teacher** แล้วเปิดแอปใหม่ แอปควรกลับเข้า Home ของครูโดยอัตโนมัติ
2. กดโลโก้ PromptLearn แล้วเลือก **Login as Student** จากนั้นเปิดแอปใหม่เพื่อตรวจว่าแอปจำบทบาทนักเรียน
3. รัน `flutter analyze` และ `flutter test` เพื่อเช็กทั้งการเลือก View ตามบทบาทและการนำทางเมื่อเปลี่ยนขนาดหน้าต่าง

ตกลง API contract กับฝั่ง backend ก่อนเชื่อมต่อ
