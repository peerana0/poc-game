# TriCore Arena (ชื่อชั่วคราว)

POC เกม MOBA 3 ทีม ทีมละ 5 คน สร้างด้วย Godot 4.7 สำหรับเล่นบน iPhone
เอกสารออกแบบเกมอยู่ใน Claude Docs: "TriCore Arena เอกสารออกแบบเกม (ร่าง)"

## ตอนนี้มีอะไรแล้ว

เฟส 2 (ฉากหลัก `scenes/main.tscn`):
- แมพสามเหลี่ยม 3 ทีม (ฟ้า แดง ม่วง) มี 3 เลน แต่ละเลนเชื่อม Core ของสองทีม ตรงกลางเป็นลานของ World Boss (มาในเฟส 3)
- แต่ละทีมมี Core 1 อันกับป้อม 2 ป้อม Core จะโดนตีได้เมื่อป้อมของทีมนั้นพังไปอย่างน้อย 1 ป้อม
- มินเนียนออกทุก 26 วินาที เดินตามเลนไปตีฐานศัตรู
- ผู้เล่น 1 คน (ทีมฟ้า วงสีฟ้าใต้เท้า) กับบอท 14 ตัว บอทเดินเลน ตีมินเนียน ใช้สกิล หลบป้อม และกลับไปเติมเลือดที่น้ำพุ
- ตายแล้วเกิดใหม่ที่ฐาน Core แตกแล้วทีมนั้นตกรอบ ทีมสุดท้ายที่เหลือชนะ
- มินิแมพ คะแนนฆ่าของ 3 ทีม เวลาแมตช์ และหน้าจอชนะ/แพ้พร้อมปุ่มเล่นใหม่
- ตอนนี้ฮีโร่ทุกตัวใช้ชุดสกิลของ Pyrelle ไปก่อน ฮีโร่อีก 9 ตัวจะมาในเฟส 4

เฟส 1 (ฉากทดสอบสกิล `scenes/test_arena.tscn` เปิดไฟล์นี้ใน Godot แล้วกด F6):
- Pyrelle กับหุ่นซ้อม 7 ตัว และปุ่ม "คูลดาวน์เร็ว"

การควบคุมแบบเกมมือถือ: จอยสติ๊กลอยด้านซ้าย ปุ่มโจมตีและสกิล 3 ปุ่มด้านขวา
- แตะปุ่มสกิล = ยิงใส่ศัตรูที่ใกล้ที่สุด
- ลากปุ่มสกิล = เล็งเอง (มีเส้นหรือวงบอกบนพื้น) ปล่อยนิ้วเพื่อใช้
- ลากไปปล่อยที่วง "ยกเลิก" มุมขวาบน = ไม่ใช้สกิล

ทดสอบบน Mac ได้ด้วยคีย์บอร์ด: WASD เดิน, Space โจมตี, Q/E/R ใช้สกิลไปทางเมาส์

## เปิดโปรเจกต์

1. เปิด Godot 4.7 แล้วกด Import เลือกไฟล์ `project.godot` ในโฟลเดอร์นี้
2. กด F5 (หรือปุ่ม Play) เพื่อเล่นฉากทดสอบบน Mac

## ลงเครื่อง iPhone

ต้องมี Xcode (ฟรีจาก App Store) และ Apple ID

1. ใน Godot: Editor > Manage Export Templates ถ้าขึ้นว่า Offline mode ให้กด Go Online ก่อน
   แล้วเลือกที่ดาวน์โหลดในช่อง Download from ติ๊ก iOS แล้วกด Install Selected Templates (ครั้งเดียว)
2. เปิด Xcode ครั้งแรกให้ติดตั้ง iOS ให้เสร็จ แล้วไปที่ Xcode > Settings > Accounts กด + ใส่ Apple ID
3. หา Team ID: ใน Accounts กด Manage Certificates กด + เลือก Apple Development
   แล้วเปิดแอป Keychain Access ค้น "Apple Development" ดับเบิลคลิก ช่อง Organizational Unit คือ Team ID
4. Project > Export > เลือก preset "iOS"
   - ใส่ App Store Team ID
   - เปลี่ยน Bundle Identifier ให้ไม่ซ้ำ เช่น `com.<ชื่อคุณ>.tricorearena`
   - preset ตั้ง Export Project Only ไว้แล้ว (Godot จะสร้างโปรเจกต์ Xcode ให้ ไม่สร้าง .ipa เอง)
5. กด Export Project เลือกโฟลเดอร์ `build/ios` (ติ๊ก Export With Debug)
6. เปิดไฟล์ `.xcodeproj` ที่ได้ใน Xcode เสียบสาย iPhone เลือกเครื่องที่แถบด้านบน แล้วกด Run
7. บน iPhone: Settings > Privacy & Security > Developer Mode เปิดไว้
   และครั้งแรกต้องไปที่ Settings > General > VPN & Device Management กดเชื่อถือแอป

Apple ID ฟรีใช้ได้ แต่แอปจะหมดอายุใน 7 วัน ต้องกด Run จาก Xcode ใหม่

## โครงสร้าง

```
project.godot
scenes/main.tscn            แมตช์ 3 ทีม (สร้างทุกอย่างจากโค้ด)
scenes/test_arena.tscn      ฉากทดสอบสกิลกับหุ่นซ้อม
scripts/
  core/                     ตั้งค่าปุ่มคีย์บอร์ด
  combat/                   Unit (มีเลือดและทีม), กระสุน, หุ่นซ้อม
  heroes/                   Hero, Skill, Passive, โมเดลชั่วคราว
    pyrelle/                สกิลและเอฟเฟกต์ของ Pyrelle
  game/                     กล้อง, ตัวบอกการเล็ง, ตัวควบคุม, ฉากทดสอบ
  match/                    แมพ 3 ทีม, ป้อมและ Core, มินเนียน, บอท, กติกาแมตช์
  ui/                       จอยสติ๊ก, ปุ่มสกิล, แถบเลือด, HUD
  vfx/                      ตัวสร้างเอฟเฟกต์และโมเดลจากรูปทรงพื้นฐาน
shaders/ground_marker.gdshader   วง เส้น และพื้นที่เตือนบนพื้น
shaders/lane_path.gdshader       ถนนดินของเลน
data/heroes/pyrelle.tres    ตัวเลขทั้งหมดของ Pyrelle (แก้ใน Inspector ได้)
```

ฮีโร่ทุกตัวใช้คลาส `Hero` เดียวกัน ตัวเลขอยู่ในไฟล์ `.tres` และสกิลแต่ละอันเป็นคลาสที่สืบจาก `Skill`
การเพิ่มฮีโร่ใหม่คือเพิ่มไฟล์ข้อมูล 1 ไฟล์กับสคริปต์สกิล ไม่ต้องแก้ระบบหลัก

โมเดลตอนนี้เป็นรูปทรงชั่วคราวที่สร้างจากโค้ด เมื่อมีโมเดลจริงให้ใส่ไว้ที่ `HeroStats.model_scene`
