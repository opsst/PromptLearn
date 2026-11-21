# PromptLearn Design System

Flutter ใช้ [AppTheme และ AppColors](lib/ui/core/theme/app_theme.dart) เป็นแหล่งกลางสำหรับตัวอักษรและสี เปิดใช้ธีมผ่าน `MaterialApp`

## ตัวอักษร

ใช้ Inter จากไฟล์ฟอนต์ในแอป ขนาดในตารางเป็นขนาดตั้งต้นก่อนปรับตามการตั้งค่าข้อความของระบบ

| ขนาด | ใช้กับ | ตัวอย่าง TextTheme |
| --- | --- | --- |
| 26 | หัวข้อหน้าและข้อความทักทาย | `titleLarge`, `headlineMedium` |
| 15 | เนื้อหา ข้อความในฟอร์ม และปุ่ม | `bodyMedium`, `labelLarge` |
| 13 | วันที่ คำอธิบายประกอบ และป้ายกำกับขนาดเล็ก | `bodySmall`, `labelSmall` |

## สีหลัก

| สี | บทบาท | ใช้ใน Flutter |
| --- | --- | --- |
| `#32A060` | สีแบรนด์และปุ่มหลัก | `colorScheme.primary` |
| `#52C883` | แสดงรายการที่เลือก เช่น แถบข้างเมนู | `AppColors.accent`, `colorScheme.primaryContainer` |
| `#AFE6A2` | พื้นหลังสีอ่อนสำหรับข้อมูลประกอบ | `colorScheme.secondaryContainer` |
| `#B8E68C` | พื้นหลังสำหรับเน้นข้อมูล เช่น กิจกรรมที่กำลังแสดง | `colorScheme.tertiaryContainer` |
| `#6AC08F` | สีรองสำหรับองค์ประกอบที่มีลำดับความสำคัญถัดจากปุ่มหลัก | `colorScheme.secondary` |

เมื่อวางข้อความหรือไอคอนบนพื้นสีเขียว ให้ใช้สีตัวอักษรคู่กันจาก `ColorScheme` เช่น `onPrimary` หรือ `onSecondaryContainer` สีพื้นหน้าหลัก แถบนำทาง และข้อความรองอยู่ใน `AppColors` เช่นกัน
