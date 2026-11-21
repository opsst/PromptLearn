# PromptLearn Frontend

โฟลเดอร์สำหรับแอป **Flutter** ฝั่งครูและนักเรียน

ขอบเขต: syllabus/lesson planning, classroom sessions และ recordings, assessments, AI tutoring และ analytics

[สถาปัตยกรรม Flutter และแนวทางวางไฟล์](ARCHITECTURE.md)

[Design System ของ PromptLearn](DESIGN_SYSTEM.md)

## แนวทางการออกแบบ

ช่วงแรกให้พัฒนาและทดสอบบนแท็บเล็ต Android เป็นหลัก โดยรองรับ iPad ด้วย ออกแบบหน้าจอ ทั้งแนวตั้งและแนวนอน ให้หน้าจอปรับตามพื้นที่หน้าต่างที่มี รวมถึงเมื่อแบ่งหน้าจอหรือใช้งานบนโทรศัพท์

## บทบาทของผู้ใช้

PromptLearn มีสองบทบาทคือครูและนักเรียน ครั้งแรกที่เปิดแอปให้เลือก **Login as Teacher** หรือ **Login as Student** แอปจะจำบทบาทที่เลือกในเครื่องและเข้า Home ด้วยบทบาทเดิมเมื่อเปิดอีกครั้ง กดโลโก้ PromptLearn เพื่อล้างบทบาทและกลับไปหน้าเลือก ทั้งสองบทบาทใช้โครงนำทางร่วมกัน และส่งบทบาทปัจจุบันให้หน้าที่ต้องใช้ปรับการทำงานตามผู้ใช้

## เริ่มใช้งาน

จากโฟลเดอร์ `frontend/` ให้เปิด simulator หรือ emulator แล้วรัน

```sh
flutter pub get
flutter run
```

ตกลง API contract กับฝั่ง backend ก่อนเชื่อมต่อ
