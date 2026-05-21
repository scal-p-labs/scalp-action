# scalp-action — SCAL-P GitHub Action

![logo](https://raw.githubusercontent.com/scal-p-labs/assets/main/banner.png)

> Run [SCAL-P](https://github.com/scal-p-labs/SCAL-P) CI in your GitHub workflows —
> enforce policy, verify dependency hashes, and audit your JavaScript project with zero config.

```yaml
- uses: scal-p-labs/scalp-action@<SHA_COMMIT>
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
      - uses: actions/checkout@<SHA_COMMIT>
      - uses: actions/setup-node@<SHA_COMMIT>
      - uses: scal-p-labs/scalp-action@<SHA_COMMIT>
        with:
          version: latest
          pm: npm
          pr-context: fork
```

### With custom policy

```yaml
- uses: scal-p-labs/scalp-action@<SHA_COMMIT>
  with:
    policy: .scalp/policy.json
    output: .scalp/ci-report.json
    pr-context: internal
```

### Using the report output

```yaml
- uses: scal-p-labs/scalp-action@<SHA_COMMIT>
  id: scalp
  with:
    pm: pnpm

- name: Upload CI report
  uses: actions/upload-artifact@<SHA_COMMIT>
  with:
    name: scalp-report
    path: ${{ steps.scalp.outputs.report-path }}
```

### With SARIF and Code Scanning

```yaml
- uses: scal-p-labs/scalp-action@<SHA_COMMIT>
  id: scalp
  with:
    sarif: .scalp/results.sarif

- uses: github/codeql-action/upload-sarif@<SHA_COMMIT>
  with:
    sarif_file: ${{ steps.scalp.outputs.sarif-path }}
```

---



## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `version` | `latest` | SCAL-P release version (`v0.1.0`, or `latest` for the most recent) |
| `pm` | auto-detect | Package manager: `npm`, `pnpm`, `yarn`, `bun` |
| `policy` | `.scalp/policy.json` | Path to the policy file |
| `output` | `.scalp/ci-report.json` | Path for the CI report |
| `sarif` | (none) | Path for the SARIF report (e.g. `.scalp/results.sarif`) |
| `pr-context` | `fork` | PR context — `fork` (blocks scripts, enforces hash) or `internal` |
| `allow-scripts` | `false` | Allow install scripts (`internal` PRs only) |
| `working-directory` | `.` | Working directory relative to the repository root |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | CI run result: `pass` or `fail` |
| `report-path` | Absolute path to the generated JSON report |
| `sarif-path` | Absolute path to the generated SARIF report (if `sarif` input is set) |

---

## How it works

1. The action detects the runner OS and architecture (linux/macos/windows × amd64/arm64)
2. Downloads the matching `scalp` binary from the [SCAL-P releases](https://github.com/scal-p-labs/SCAL-P/releases)
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
      - uses: actions/checkout@<SHA_COMMIT>
      - uses: actions/setup-node@<SHA_COMMIT>
      - uses: scal-p-labs/scalp-action@<SHA_COMMIT>
```

### Multi-package manager matrix

```yaml
strategy:
  matrix:
    pm: [npm, pnpm, yarn, bun]
steps:
  - uses: actions/checkout@<SHA_COMMIT>
  - uses: actions/setup-node@<SHA_COMMIT>
  - uses: scal-p-labs/scalp-action@<SHA_COMMIT>
    with:
      pm: ${{ matrix.pm }}
      pr-context: fork
```

---

## Why SHA pinning?

You'll notice this action pins all its internal dependencies by commit SHA (e.g., `actions/checkout@11bd719...`) instead of by semver tag (`@v4`). This is a supply-chain security practice:

- **Tags are mutable** — a maintainer account compromise can move a tag to a different commit, injecting malicious code into your workflow without changing the version number.
- **SHAs are immutable** — a commit hash uniquely identifies the exact code that was reviewed and approved. No tag move can change what runs.
- **Renovate / Dependabot** still work: they update the SHA when a new version is released, and the PR diff shows exactly what code changed.

The principle applies to your own usage too: pin `scalp-action` by commit SHA in your workflows, and let Renovate or Dependabot manage updates.

```yaml
- uses: scal-p-labs/scalp-action@a1b2c3d4e5f6...
```

---

## License

MIT
