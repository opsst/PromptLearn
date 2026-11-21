package assignmentreview

import (
	"bytes"
	"encoding/base64"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"strings"
)

const maxImageBytes = 3 << 20

func validImage(dataURL string) bool {
	header, data, ok := strings.Cut(dataURL, ",")
	if !ok || len(data) > base64.StdEncoding.EncodedLen(maxImageBytes) {
		return false
	}
	var format string
	switch header {
	case "data:image/jpeg;base64":
		format = "jpeg"
	case "data:image/png;base64":
		format = "png"
	default:
		return false
	}
	content, err := base64.StdEncoding.DecodeString(data)
	if err != nil || len(content) > maxImageBytes {
		return false
	}
	config, detected, err := image.DecodeConfig(bytes.NewReader(content))
	return err == nil && detected == format && config.Width > 0 && config.Height > 0 &&
		config.Width <= 4096 && config.Height <= 4096
}
