package migrations

import "embed"

// FS holds all embedded PostgreSQL/PostGIS migration SQL files.
//
//go:embed *.sql
var FS embed.FS
