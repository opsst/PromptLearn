package assignmentreview

import (
	"bytes"
	"encoding/json"
	"fmt"
)

type Box struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

func (box *Box) UnmarshalJSON(data []byte) error {
	var fields struct {
		X      *float64 `json:"x"`
		Y      *float64 `json:"y"`
		Width  *float64 `json:"width"`
		Height *float64 `json:"height"`
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&fields); err != nil {
		return err
	}
	if fields.X == nil || fields.Y == nil || fields.Width == nil || fields.Height == nil {
		return fmt.Errorf("%w: box requires four coordinates", ErrInvalidInput)
	}
	*box = Box{X: *fields.X, Y: *fields.Y, Width: *fields.Width, Height: *fields.Height}
	return nil
}

func validBox(box Box) bool {
	const tolerance = 1e-9
	return box.X >= 0 && box.Y >= 0 && box.Width > 0 && box.Height > 0 &&
		box.X+box.Width <= 1+tolerance && box.Y+box.Height <= 1+tolerance
}
