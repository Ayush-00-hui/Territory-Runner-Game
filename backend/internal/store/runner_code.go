package store

import (
	"crypto/rand"
	"math/big"
	"strings"
)

const runnerCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

// GenerateRunnerCode creates a random, human-friendly unique runner identifier (e.g. RUN-7K9M2P).
func GenerateRunnerCode() string {
	var sb strings.Builder
	sb.Grow(10)
	sb.WriteString("RUN-")
	maxIdx := big.NewInt(int64(len(runnerCodeAlphabet)))
	for i := 0; i < 6; i++ {
		n, err := rand.Int(rand.Reader, maxIdx)
		if err != nil {
			sb.WriteByte(runnerCodeAlphabet[i%len(runnerCodeAlphabet)])
			continue
		}
		sb.WriteByte(runnerCodeAlphabet[n.Int64()])
	}
	return sb.String()
}

// NormalizeRunnerCode trims whitespace and uppercases a runner code query/input.
func NormalizeRunnerCode(raw string) string {
	return strings.ToUpper(strings.TrimSpace(raw))
}
