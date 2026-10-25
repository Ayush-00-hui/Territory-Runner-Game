package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

var defaultBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0}

type metricKey struct {
	method string
	path   string
	status string
}

// MetricsCollector tracks HTTP and WebSocket runtime telemetry for Prometheus scraping.
type MetricsCollector struct {
	mu                   sync.RWMutex
	buckets              []float64
	requestsTotal        map[metricKey]uint64
	durationCount        map[metricKey]uint64
	durationSum          map[metricKey]float64
	durationBucketCounts map[metricKey][]uint64
}

// NewMetricsCollector constructs a Prometheus metrics registry.
func NewMetricsCollector() *MetricsCollector {
	return &MetricsCollector{
		buckets:              defaultBuckets,
		requestsTotal:        make(map[metricKey]uint64),
		durationCount:        make(map[metricKey]uint64),
		durationSum:          make(map[metricKey]float64),
		durationBucketCounts: make(map[metricKey][]uint64),
	}
}

// Record observes an HTTP request completion.
func (mc *MetricsCollector) Record(method, path string, statusCode int, durationSec float64) {
	key := metricKey{
		method: method,
		path:   path,
		status: strconv.Itoa(statusCode),
	}

	mc.mu.Lock()
	defer mc.mu.Unlock()

	mc.requestsTotal[key]++
	mc.durationCount[key]++
	mc.durationSum[key] += durationSec

	bucketCounts, exists := mc.durationBucketCounts[key]
	if !exists {
		bucketCounts = make([]uint64, len(mc.buckets))
		mc.durationBucketCounts[key] = bucketCounts
	}

	for i, le := range mc.buckets {
		if durationSec <= le {
			bucketCounts[i]++
		}
	}
}

// WritePrometheus serializes telemetry in standard Prometheus text format.
func (mc *MetricsCollector) WritePrometheus(w io.Writer, activeWs int) error {
	mc.mu.RLock()
	defer mc.mu.RUnlock()

	// 1. http_requests_total
	fmt.Fprintln(w, "# HELP http_requests_total Total number of HTTP requests partitioned by method, path, and status code.")
	fmt.Fprintln(w, "# TYPE http_requests_total counter")

	// Sort keys for deterministic scraping output
	keys := make([]metricKey, 0, len(mc.requestsTotal))
	for k := range mc.requestsTotal {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].path != keys[j].path {
			return keys[i].path < keys[j].path
		}
		if keys[i].method != keys[j].method {
			return keys[i].method < keys[j].method
		}
		return keys[i].status < keys[j].status
	})

	for _, k := range keys {
		fmt.Fprintf(w, "http_requests_total{method=\"%s\",path=\"%s\",status=\"%s\"} %d\n",
			k.method, k.path, k.status, mc.requestsTotal[k])
	}

	// 2. http_request_duration_seconds
	fmt.Fprintln(w, "# HELP http_request_duration_seconds HTTP request duration histogram in seconds.")
	fmt.Fprintln(w, "# TYPE http_request_duration_seconds histogram")

	for _, k := range keys {
		bCounts := mc.durationBucketCounts[k]
		for i, le := range mc.buckets {
			fmt.Fprintf(w, "http_request_duration_seconds_bucket{method=\"%s\",path=\"%s\",status=\"%s\",le=\"%g\"} %d\n",
				k.method, k.path, k.status, le, bCounts[i])
		}
		fmt.Fprintf(w, "http_request_duration_seconds_bucket{method=\"%s\",path=\"%s\",status=\"%s\",le=\"+Inf\"} %d\n",
			k.method, k.path, k.status, mc.durationCount[k])
		fmt.Fprintf(w, "http_request_duration_seconds_sum{method=\"%s\",path=\"%s\",status=\"%s\"} %g\n",
			k.method, k.path, k.status, mc.durationSum[k])
		fmt.Fprintf(w, "http_request_duration_seconds_count{method=\"%s\",path=\"%s\",status=\"%s\"} %d\n",
			k.method, k.path, k.status, mc.durationCount[k])
	}

	// 3. ws_active_connections
	fmt.Fprintln(w, "# HELP ws_active_connections Number of active WebSocket runner connections.")
	fmt.Fprintln(w, "# TYPE ws_active_connections gauge")
	fmt.Fprintf(w, "ws_active_connections %d\n", activeWs)

	return nil
}

// MetricsMiddleware records latency and status codes for Prometheus and propagates X-Request-Id.
func (a *API) MetricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if reqID := middleware.GetReqID(r.Context()); reqID != "" {
			w.Header().Set("X-Request-Id", reqID)
		}

		start := time.Now()
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		next.ServeHTTP(ww, r)

		duration := time.Since(start).Seconds()
		path := r.URL.Path
		if routeCtx := chi.RouteContext(r.Context()); routeCtx != nil {
			if pattern := routeCtx.RoutePattern(); pattern != "" {
				path = pattern
			}
		}

		if a.metrics != nil {
			a.metrics.Record(r.Method, path, ww.Status(), duration)
		}
	})
}

// HandleMetrics handles GET /metrics Prometheus scraping requests.
func (a *API) HandleMetrics(w http.ResponseWriter, r *http.Request) {
	token := a.metricsToken
	if token == "" {
		token = os.Getenv("METRICS_TOKEN")
	}

	if token != "" {
		authHeader := r.Header.Get("Authorization")
		expected := "Bearer " + token
		if authHeader != expected {
			w.Header().Set("WWW-Authenticate", `Bearer realm="metrics"`)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"error":  "UNAUTHORIZED",
				"detail": "Missing or invalid bearer token for metrics scraping",
			})
			return
		}
	}

	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	w.WriteHeader(http.StatusOK)

	activeWs := 0
	if a.wsHub != nil {
		activeWs = a.wsHub.ActiveClientCount()
	}

	if a.metrics != nil {
		_ = a.metrics.WritePrometheus(w, activeWs)
	} else {
		collector := NewMetricsCollector()
		_ = collector.WritePrometheus(w, activeWs)
	}
}
