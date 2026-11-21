package assignmentreview

import (
	"context"
	"strings"
)

const (
	DemoAssignmentID = "hw-3-2"
	DemoItemID       = "q4"
	DemoStudentID    = "a1000000-0000-4000-8000-000000000003"
)

func (*DemoRepository) FindQuestion(_ context.Context, assignmentID, itemID string) (Question, error) {
	if !isDemoItem(assignmentID, itemID) {
		return Question{}, ErrNotFound
	}
	return Question{
		Prompt:    "Simplify (x^2)(x^5). Show how you combine the powers.",
		Rubric:    "Shows valid reasoning for a product of powers with the same base and gives the simplified power.",
		AnswerKey: "x^7; either expand both factors or show x^(2+5) before simplifying.",
	}, nil
}

func isDemoItem(assignmentID, itemID string) bool {
	return assignmentID == DemoAssignmentID && itemID == DemoItemID
}

// DemoReviewer recognizes known synthetic work for the demo item.
type DemoReviewer struct{}

func (DemoReviewer) Review(_ context.Context, _ Question, work Submission) (Decision, error) {
	var methodSeen bool
	for i, block := range work.Blocks {
		step := plainMath(block.Text)
		switch step {
		case "(x^2)(x^5)", "x^2*x^5":
			// Original expression.
		case "x^(2*5)", "x^2*5", "x^2x5":
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^10":
			return Decision{Status: NeedsRevision, Findings: []Finding{{BlockID: block.ID, Kind: SameBasePowers}}}, nil
		case "x^(2+5)", "x*x*x*x*x*x*x":
			methodSeen = true
		case "x^7":
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
	return strings.NewReplacer("×", "*", "·", "*", "¹⁰", "^10", "²", "^2", "⁵", "^5", "⁷", "^7").Replace(strings.TrimPrefix(text, "="))
}
