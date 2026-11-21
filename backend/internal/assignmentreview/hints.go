package assignmentreview

type HintKind string

const (
	SameBasePowers HintKind = "same_base_powers"
	Sign           HintKind = "sign"
	Distribution   HintKind = "distribution"
	Arithmetic     HintKind = "arithmetic"
	Equivalence    HintKind = "equivalence"
	MissingStep    HintKind = "missing_step"
	Units          HintKind = "units"
	Incomplete     HintKind = "incomplete"
)

type localized struct {
	English string
	Thai    string
}

func (s localized) in(language string) string {
	if language == "th" {
		return s.Thai
	}
	return s.English
}

var statusMessages = map[Status]localized{
	Correct:       {"Your work is correct.", "วิธีทำและคำตอบถูกต้องแล้ว"},
	NeedsRevision: {"Take another look at the highlighted step.", "ลองกลับไปดูขั้นที่ไฮไลต์ไว้อีกครั้ง"},
	Unreadable:    {"I couldn't check the steps with confidence. Try a clearer photo or rewrite the steps.", "ยังอ่านวิธีทำได้ไม่ชัดพอ ลองถ่ายให้ชัดขึ้นหรือเขียนวิธีทำอีกครั้ง"},
}

// Learner-facing wording is selected from these prompts. Model text never goes to the student.
var prompts = map[HintKind]struct {
	Observation localized
	Question    localized
}{
	SameBasePowers: {
		localized{"Look at how you combined powers with the same base.", "ลองดูวิธีที่ใช้รวมเลขยกกำลังที่มีฐานเดียวกัน"},
		localized{"If you write each power out as repeated multiplication, how many copies of the base are there altogether?", "ลองเขียนเลขยกกำลังแต่ละตัวเป็นการคูณซ้ำกัน แล้วนับว่ามีตัวฐานทั้งหมดกี่ตัว"},
	},
	Sign: {
		localized{"Check the sign in this step.", "ลองตรวจเครื่องหมายในขั้นนี้"},
		localized{"What sign would you expect if you tried the same operation with simpler numbers?", "ถ้าลองทำแบบเดียวกันกับตัวเลขที่ง่ายขึ้น ผลควรมีเครื่องหมายอะไร"},
	},
	Distribution: {
		localized{"Check how you used the parentheses.", "ลองดูวิธีจัดการวงเล็บในขั้นนี้"},
		localized{"Which terms inside the parentheses does the operation apply to?", "การดำเนินการนี้ต้องใช้กับพจน์ไหนบ้างในวงเล็บ"},
	},
	Arithmetic: {
		localized{"This calculation is worth checking again.", "ลองตรวจการคำนวณตรงนี้อีกครั้ง"},
		localized{"Can you redo this small calculation and check it using the inverse operation?", "ลองคำนวณส่วนนี้ใหม่ แล้วใช้การดำเนินการย้อนกลับตรวจได้ไหม"},
	},
	Equivalence: {
		localized{"Compare this line with the one before it.", "ลองเปรียบเทียบบรรทัดนี้กับบรรทัดก่อนหน้า"},
		localized{"How could you check whether the expression still has the same value after this change?", "จะตรวจได้อย่างไรว่าหลังเปลี่ยนรูปแล้วนิพจน์ยังมีค่าเท่าเดิม"},
	},
	MissingStep: {
		localized{"There is a gap in the reasoning at this line.", "ยังมีช่วงที่วิธีทำข้ามขั้นตรงบรรทัดนี้"},
		localized{"What rule or intermediate step connects this line to the one before it?", "มีกฎหรือขั้นตอนย่อยอะไรที่เชื่อมบรรทัดนี้กับบรรทัดก่อนหน้า"},
	},
	Units: {
		localized{"Check the units used in this step.", "ลองตรวจหน่วยที่ใช้ในขั้นนี้"},
		localized{"What units does each quantity use, and what unit would you expect after the operation?", "ปริมาณแต่ละตัวใช้หน่วยอะไร และหลังคำนวณแล้วควรได้หน่วยอะไร"},
	},
	Incomplete: {
		localized{"This line does not yet finish the required work.", "บรรทัดนี้ยังทำสิ่งที่โจทย์ขอไม่ครบ"},
		localized{"Which part of the question still needs a calculation or explanation?", "โจทย์ส่วนไหนที่ยังต้องคำนวณหรืออธิบายเพิ่มเติม"},
	},
}
