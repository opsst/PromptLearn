# PromptLearn Frontend

โฟลเดอร์สำหรับแอป **Flutter** ฝั่งครูและนักเรียน

ขอบเขต: syllabus/lesson planning, classroom sessions และ recordings, assessments, AI tutoring และ analytics

[สถาปัตยกรรม Flutter และแนวทางวางไฟล์](ARCHITECTURE.md)

[Design System ของ PromptLearn](DESIGN_SYSTEM.md)

[หน้าทำการบ้านและสัญญากับ backend](HOMEWORK_CHECKER.md)

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

## ตรวจ HTTP บน Android

ใน Android debug build ให้กดอนุญาตแจ้งเตือนตอนเปิดแอปครั้งแรก จากนั้นเปิดแถบแจ้งเตือนของ Android แล้วแตะ **Chucker HTTP inspector** เพื่อดู request และ response ที่บันทึกในเครื่อง

ให้ API ฝั่ง Flutter ที่ต้องการตรวจใช้ `createApiHttpClient()` จาก [api_http_client.dart](lib/data/services/api_http_client.dart) ระบบใช้ HTTP client ปกติใน release และแพลตฟอร์มอื่น

หากต้องการลองตรวจด้วย `GET /healthz` ให้รัน Go backend แล้วเปิดแอปบน Android Emulator ด้วยคำสั่งนี้จาก `frontend/`

```sh
adb -s emulator-5554 reverse tcp:8080 tcp:8080
flutter run -d emulator-5554 --dart-define=PROMPTLEARN_API_BASE_URL=http://127.0.0.1:8080
```

แอป debug ส่ง health check หนึ่งครั้งตอนเริ่มเมื่อระบุ URL รายละเอียด HTTP อยู่ใน Chucker และตัวแจ้งเตือนใช้ข้อความสำหรับเปิดหน้าตรวจ

รายการตรวจการบ้านใน Chucker บน Android debug แสดงเมธอด, endpoint, HTTP status, เวลา และ JSON ของ request/response ใน request แสดง Base64 ของรูปเพียง 24 ตัวแรกแล้วต่อด้วย `...` ส่วน API ยังได้รับรูปเต็ม [วิธีทดสอบ HW 3.1 กับ Go](HOMEWORK_CHECKER.md)
