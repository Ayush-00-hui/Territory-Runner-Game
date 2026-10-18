# Security Policy

## 1. Supported Versions

| Version / Branch | Supported |
| :--- | :--- |
| `industry-level` (Current Active) | :white_check_mark: |
| `main` (Production) | :white_check_mark: |
| `< 1.0.0` releases | :x: |

---

## 2. Reporting a Vulnerability

We take the competitive integrity, privacy, and security of Territory Runner athletes seriously. If you discover a vulnerability—including GPS spoofing bypasses, PostGIS spatial injection, authentication flaws, or private telemetry exposure—please disclose it responsibly.

### 2.1 Disclosure Process
- **Do NOT** open a public GitHub issue for security vulnerabilities.
- Report vulnerabilities privately via GitHub Security Advisories or by emailing `security@territoryrunner.app`.
- Provide detailed reproduction steps, sample GPX tracks (for anti-cheat bypasses), or API payload examples.

### 2.2 Response SLA
- **Initial Acknowledgment**: Within 48 hours.
- **Triage & Severity Assessment**: Within 5 business days.
- **Mitigation & Patch Release**: High-severity vulnerabilities are patched within 7 business days with synchronized client-server rollout.

---

## 3. Anti-Cheat & GPS Spoofing Policy

Territory Runner employs multi-layer anti-cheat defenses:
1. **Kinematic Outlier Rejection**: Consecutive sample speed limits calibrated by modality (Walking: 15 km/h, Running: 35 km/h, Cycling: 60 km/h).
2. **Server-Side Timestamp Hygiene**: Rejection of future timestamps (> 10m drift) and expired runs (> 14 days).
3. **Transaction-Scoped Spatial Locking**: PostgreSQL advisory locks prevent race conditions during concurrent territory captures.

Reports demonstrating mathematical or logical circumvention of consecutive sample outlier filters or PostGIS topology validation are treated as high-priority security defects.
