# scalp-action — SCAL-P GitHub Action

> Run [SCAL-P](https://github.com/scal-p-labs/SCAL-P) CI in your GitHub workflows —
> enforce policy, verify dependency hashes, and audit your JavaScript project with zero config.

```yaml
- uses: scal-p-labs/scalp-action@v1
```

---

## Why

npm/pnpm/yarn/bun run arbitrary code during install. SCAL-P flips the order: policy before trust, hash after install, audit always.

This action installs the `scalp` binary and runs `scalp ci` — a single command that resolves your lockfile, evaluates policy, blocks violations, installs dependencies, verifies hashes, and produces a structured JSON report.

---

## Usage

```yaml
jobs:
  scalp-ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - uses: scal-p-labs/scalp-action@v1
        with:
          version: latest
          pm: npm
          pr-context: fork
```

### With custom policy

```yaml
- uses: scal-p-labsscalp-action@v1
  with:
    policy: .scalp/policy.json
    output: .scalp/ci-report.json
    pr-context: internal
```

### Using the report output

```yaml
- uses: scal-p-labsscalp-action@v1
  id: scalp
  with:
    pm: pnpm

- name: Upload CI report
  uses: actions/upload-artifact@v4
  with:
    name: scalp-report
    path: ${{ steps.scalp.outputs.report-path }}
```

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `version` | `latest` | SCAL-P release version (`v0.1.0`, or `latest` for the most recent) |
| `pm` | auto-detect | Package manager: `npm`, `pnpm`, `yarn`, `bun` |
| `policy` | `.scalp/policy.json` | Path to the policy file |
| `output` | `.scalp/ci-report.json` | Path for the CI report |
| `pr-context` | `fork` | PR context — `fork` (blocks scripts, enforces hash) or `internal` |
| `allow-scripts` | `false` | Allow install scripts (`internal` PRs only) |
| `working-directory` | `.` | Working directory relative to the repository root |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | CI run result: `pass` or `fail` |
| `report-path` | Absolute path to the generated JSON report |

---

## How it works

1. The action detects the runner OS and architecture (linux/macos/windows × amd64/arm64)
2. Downloads the matching `scalp` binary from the [SCAL-P releases](https://github.com/scal-p-labsSCAL-P/releases)
3. Runs `scalp ci` with the provided inputs
4. Exits with the same status as `scalp ci` — fail on policy violations or hash mismatches

---

## Examples

### Quick CI check

```yaml
name: Dependency Security
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - uses: scal-p-labsscalp-action@v1
```

### Multi-package manager matrix

```yaml
strategy:
  matrix:
    pm: [npm, pnpm, yarn, bun]
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
  - uses: scal-p-labsscalp-action@v1
    with:
      pm: ${{ matrix.pm }}
      pr-context: fork
```

---

## License

MIT
