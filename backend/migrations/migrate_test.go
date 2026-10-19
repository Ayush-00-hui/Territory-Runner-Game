package migrations

import (
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEmbeddedMigrationsCompleteness(t *testing.T) {
	files, err := GetEmbeddedMigrationFiles()
	require.NoError(t, err)

	// Ensure all 10 pairs (20 files total) are embedded
	assert.GreaterOrEqual(t, len(files), 20, "expected at least 20 migration files (10 up/down pairs)")

	upFiles := make(map[int]string)
	downFiles := make(map[int]string)

	for _, file := range files {
		if !strings.HasSuffix(file, ".sql") {
			continue
		}

		var seq int
		var direction string
		n, _ := fmt.Sscanf(file, "%06d_%s", &seq, &direction)
		if n >= 1 {
			if strings.HasSuffix(file, ".up.sql") {
				upFiles[seq] = file
			} else if strings.HasSuffix(file, ".down.sql") {
				downFiles[seq] = file
			}
		}

		// Verify file is readable and non-empty
		content, readErr := FS.ReadFile(file)
		require.NoError(t, readErr, "failed to read embedded migration file: %s", file)
		assert.NotEmpty(t, content, "migration file must not be empty: %s", file)
	}

	assert.Equal(t, 10, len(upFiles), "expected exactly 10 up migration files")
	assert.Equal(t, 10, len(downFiles), "expected exactly 10 down migration files")

	// Ensure sequential continuity 1..10
	for i := 1; i <= 10; i++ {
		assert.Contains(t, upFiles, i, "missing up migration for sequence %d", i)
		assert.Contains(t, downFiles, i, "missing down migration for sequence %d", i)
	}
}
