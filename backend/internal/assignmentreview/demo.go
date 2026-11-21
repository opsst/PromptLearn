package assignmentreview

import (
	"context"
	"strconv"
	"strings"
)

const (
	DemoAssignmentID     = "hw-3-2"
	DemoItemID           = "q4"
	DemoStudentID        = "a1000000-0000-4000-8000-000000000003"
	HomeworkAssignmentID = "hw-3-1"
)

const exponentRubric = "Show valid intermediate reasoning using properties of exponents, then give the simplified expression."

var homeworkQuestions = [...]Question{
	{Prompt: "Simplify x² · x³.", Rubric: exponentRubric, AnswerKey: "x^5; expand both factors or show x^(2+3)."},
	{Prompt: "Simplify (a³)².", Rubric: exponentRubric, AnswerKey: "a^6; expand as a^3*a^3 or show a^(3*2)."},
	{Prompt: "Simplify y⁶ ÷ y², where y ≠ 0.", Rubric: exponentRubric, AnswerKey: "y^4; cancel two factors, or show y^(6-2)."},
	{Prompt: "Simplify (x²)(x⁵).", Rubric: exponentRubric, AnswerKey: "x^7; expand both factors or show x^(2+5)."},
	{
		Prompt:    "Solve for x: x + 7 = 22.",
		Rubric:    "Show how x was isolated by keeping both sides of the equation equal, or justify the value by substitution.",
		AnswerKey: "x = 15; subtract 7 from both sides and simplify, or verify that 15 + 7 = 22.",
	},
	{Prompt: "Simplify (2x²)(3x³).", Rubric: exponentRubric, AnswerKey: "6x^5; multiply the coefficients and show x^(2+3) or equivalent reasoning."},
	{Prompt: "Simplify (p²)⁴.", Rubric: exponentRubric, AnswerKey: "p^8; show p^(2*4) or expand four groups of p^2."},
	{Prompt: "Simplify (x³)² ÷ x⁴, where x ≠ 0.", Rubric: exponentRubric, AnswerKey: "x^2; simplify the numerator to x^6, then cancel four factors or show x^(6-4)."},
}

func demoPosition(assignmentID, itemID string) int {
	if assignmentID == DemoAssignmentID && itemID == DemoItemID {
		return 4
	}
	if assignmentID != HomeworkAssignmentID || len(itemID) != 2 || itemID[0] != 'q' {
		return 0
	}
	position, _ := strconv.Atoi(itemID[1:])
	if position < 1 || position > len(homeworkQuestions) {
		return 0
	}
	return position
}

func (*DemoRepository) FindQuestion(_ context.Context, assignmentID, itemID string) (Question, error) {
	if assignmentID == DemoAssignmentID && itemID == DemoItemID {
		return Question{
			Prompt: "Simplify (x^2)(x^5). Show how you combine the powers.",
			Rubric: exponentRubric, AnswerKey: homeworkQuestions[3].AnswerKey,
		}, nil
	}
	position := demoPosition(assignmentID, itemID)
	if position == 0 {
		return Question{}, ErrNotFound
	}
	return homeworkQuestions[position-1], nil
}

// DemoReviewer recognizes synthetic transcripts for the two example products.
type DemoReviewer struct{}

func (DemoReviewer) Review(_ context.Context, question Question, work Submission) (Decision, error) {
	var second, product, sum string
	switch question.Prompt {
	case homeworkQuestions[0].Prompt:
		second, product, sum = "3", "6", "5"
	case homeworkQuestions[3].Prompt, "Simplify (x^2)(x^5). Show how you combine the powers.":
		second, product, sum = "5", "10", "7"
	default:
		return Decision{Status: Unreadable}, nil
	}
	expansion := strings.TrimSuffix(strings.Repeat("x*", int(sum[0]-'0')), "*")
	var methodSeen bool
	for i, block := range work.Blocks {
		step, result, _ := strings.Cut(plainMath(block.Text), "=")
		switch step {
		case "(x^2)(x^" + second + ")", "x^2*x^" + second:
			// Original expression.
		case "x^(2*" + second + ")", "x^2*" + second, "x^2x" + second:
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^" + product:
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^(2+" + second + ")", expansion:
			methodSeen = true
			if result == "x^"+sum && i == len(work.Blocks)-1 {
				return Decision{Status: Correct}, nil
			}
		case "x^" + sum:
			if methodSeen && i == len(work.Blocks)-1 {
				return Decision{Status: Correct}, nil
			}
			if !methodSeen && i == len(work.Blocks)-1 {
				return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: MissingStep}}}, nil
			}
		default:
			return Decision{Status: Unreadable}, nil
		}
	}
	return Decision{Status: Unreadable}, nil
}

func plainMath(text string) string {
	text = strings.Join(strings.Fields(strings.ToLower(text)), "")
	return strings.NewReplacer("×", "*", "·", "*", "¹⁰", "^10", "²", "^2", "³", "^3", "⁵", "^5", "⁶", "^6", "⁷", "^7").Replace(strings.TrimPrefix(text, "="))
}
