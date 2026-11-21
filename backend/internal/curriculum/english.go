package curriculum

import (
	"embed"
	"encoding/json"
	"fmt"
	"slices"
	"sync"
)

//go:embed math_core_en.json math_additional_en.json
var translations embed.FS

type englishRow struct {
	Title    string   `json:"title"`
	Outcomes []string `json:"outcomes"`
	Content  []string `json:"content"`
}

var englishRows = sync.OnceValues(func() (map[string]englishRow, error) {
	all := make(map[string]englishRow)
	for _, name := range []string{"math_core_en.json", "math_additional_en.json"} {
		raw, err := translations.ReadFile(name)
		if err != nil {
			return nil, err
		}
		var rows map[string]englishRow
		if err := json.Unmarshal(raw, &rows); err != nil {
			return nil, fmt.Errorf("decode %s: %w", name, err)
		}
		for id, row := range rows {
			if _, exists := all[id]; exists {
				return nil, fmt.Errorf("duplicate English curriculum row %q", id)
			}
			all[id] = row
		}
	}
	return all, nil
})

type groupKey struct {
	standardCode string
	strand       string
	objective    int
}

var englishStatements = map[groupKey]string{
	{standardCode: "ค 1.1"}: "Understand the variety of number representations, number systems, operations and their results and properties, and apply that knowledge.",
	{standardCode: "ค 1.2"}: "Understand and analyse patterns, relations, functions, sequences and series, and apply that knowledge.",
	{standardCode: "ค 1.3"}: "Use expressions, equations and inequalities to describe relationships or help solve given problems.",
	{standardCode: "ค 2.1"}: "Understand the foundations of measurement, measure and estimate sizes, and apply that knowledge.",
	{standardCode: "ค 2.2"}: "Understand and analyse geometric figures, their properties and relationships, and geometric theorems, and apply that knowledge.",
	{standardCode: "ค 3.1"}: "Understand statistical processes and use statistical knowledge to solve problems.",
	{standardCode: "ค 3.2"}: "Understand fundamental counting principles and probability, and apply that knowledge.",
	{strand: "จำนวนและพีชคณิต", objective: 1}:       "Understand the variety of number representations, number systems, operations and their results and properties, and apply that knowledge.",
	{strand: "จำนวนและพีชคณิต", objective: 2}:       "Understand and analyse patterns, relations, functions, sequences and series, and apply that knowledge.",
	{strand: "จำนวนและพีชคณิต", objective: 3}:       "Use expressions, equations, inequalities and matrices to describe relationships or help solve given problems.",
	{strand: "การวัดและเรขาคณิต", objective: 1}:     "Understand analytic geometry and apply that knowledge.",
	{strand: "การวัดและเรขาคณิต", objective: 2}:     "Understand vectors and vector operations, and apply that knowledge.",
	{strand: "สถิติและความน่าจะเป็น", objective: 1}: "Understand fundamental counting principles and probability, and apply that knowledge.",
	{strand: "แคลคูลัส", objective: 1}:              "Understand limits and continuity of functions, derivatives and integrals of functions, and apply that knowledge.",
}

var englishStrands = map[string]string{
	"จำนวนและพีชคณิต":       "Number and Algebra",
	"การวัดและเรขาคณิต":     "Measurement and Geometry",
	"สถิติและความน่าจะเป็น": "Statistics and Probability",
	"แคลคูลัส":              "Calculus",
}

// EnglishReference translates the display text while preserving the original ID,
// indicator codes, order, source pages and grade.
func EnglishReference(ref Reference) (Reference, error) {
	rows, err := englishRows()
	if err != nil {
		return Reference{}, err
	}
	translated, ok := rows[ref.Row.ID]
	if !ok || len(translated.Outcomes) != len(ref.Row.Outcomes) || translated.Title == "" || len(translated.Content) == 0 {
		return Reference{}, fmt.Errorf("missing or incomplete English translation of %q", ref.Row.ID)
	}
	key := groupKey{standardCode: ref.StandardCode}
	if ref.StandardCode == "" {
		key = groupKey{strand: ref.Strand, objective: ref.ObjectiveNumber}
	}
	statement, strand := englishStatements[key], englishStrands[ref.Strand]
	if statement == "" || strand == "" {
		return Reference{}, fmt.Errorf("missing English standard or strand for %q", ref.Row.ID)
	}

	ref.Strand, ref.Statement = strand, statement
	ref.Row.Title = translated.Title
	ref.Row.Content = slices.Clone(translated.Content)
	ref.Row.Outcomes = slices.Clone(ref.Row.Outcomes)
	for i, outcome := range translated.Outcomes {
		ref.Row.Outcomes[i].Text = outcome
	}
	return ref, nil
}

// EnglishSource gives the English display title of the same verified PDF.
func EnglishSource(source Source) Source {
	source.Title = "Indicators and Core Learning Content for Mathematics (2017 Revision), Basic Education Core Curriculum B.E. 2551 (2008), Thailand"
	return source
}
