# skigard-action

GitHub Action that installs a **pinned, checksum-verified** [skigard](https://github.com/ambierhq/skigard) release and runs
`skigard verify` on your repository: it fails the job when the approved skills, the lockfile, the installs or the generated
marketplace no longer agree (an unapproved or modified skill).

```yaml
name: skills
on: [push, pull_request]
permissions: {}
jobs:
  verify:
    runs-on: ubuntu-latest
    permissions: {contents: read}
    steps:
      - uses: actions/checkout@<full-commit-sha>   # pin actions by SHA
        with: {persist-credentials: false}
      - uses: ambierhq/skigard-action@<full-commit-sha>   # v1
        with:
          version: 0.1.1
          # sha256: <archive checksum from the release's checksums.txt>   # optional, pins the exact bytes
```

Pin this action by commit SHA, like every action in a security-sensitive workflow. The `v1` tag moves; a SHA does not.

## Inputs

| Input | Default | |
|---|---|---|
| `version` | required | skigard version without the `v`, e.g. `0.1.1`. There is no `latest`, on purpose. |
| `sha256` | none | SHA-256 of the archive for the runner (`skigard_<version>_<os>_<arch>.tar.gz`, `.zip` on Windows). The download must match it. |
| `args` | `--strict` | Arguments for `skigard verify`. |
| `home` | `.skigard` | `SKIGARD_HOME` (project scope), relative to `working-directory`. |
| `working-directory` | `.` | |
| `verify` | `true` | `false` only installs skigard. |
| `verify-signature` | `false` | `true` verifies the cosign signature of `checksums.txt` before it is trusted. Needs `cosign` on `PATH`; fails if it is missing. See below. |
| `base-url` | the GitHub release | Asset location for mirrors and this action's tests. `https://`, `file://` or localhost only. |

Output: `version`, the installed `skigard version` line.

## Verifying the signature

Install cosign first, pinned by SHA, then turn the input on:

```yaml
      - uses: sigstore/cosign-installer@756fe2d284c7292c4e9b62c8a28f1e5629c59532   # v4.1.3
      - uses: ambierhq/skigard-action@<full-commit-sha>   # v1
        with:
          version: 0.1.1
          verify-signature: true
          sha256: <archive checksum>   # optional, can be combined
```

The action does not install cosign itself, so there is no unpinned download. If `verify-signature` is true and cosign is
missing, the step fails rather than silently skipping the check.

## What it does and does not do

- Downloads `skigard_<version>_<os>_<arch>` and `checksums.txt` from the GitHub release, refuses on any SHA-256 mismatch
  (against `checksums.txt`, and against your `sha256` input when set), extracts only the binary and adds it to `PATH`.
- Runs on Linux, macOS and Windows runners (x64 and arm64).
- Never runs `skigard approve`: approval needs a human at a terminal and is not possible in CI.
- With `verify-signature: true` it runs `cosign verify-blob --bundle checksums.txt.sigstore.json` on `checksums.txt`,
  requiring the certificate identity to be skigard's `release.yml` workflow at `refs/tags/v<version>` and the issuer
  `https://token.actions.githubusercontent.com`. Off by default; pin `sha256` for the strongest guarantee.
- No telemetry; the only network access is the download above.

## Development

`.github/workflows/ci.yml` has two kinds of tests, each on Linux, macOS and Windows:

- `test` builds skigard from `main`, packages it like a release, serves it from localhost and runs the action against it
  (success, pinned checksum, wrong checksum, tampered archive, bad version, non-local URL, store drift).
- `real-release` runs the action against the real published `v0.1.1` release (no `base-url`): empty project passes,
  the real `sha256` is accepted, a wrong one is refused, the real cosign signature verifies, a tampered `checksums.txt`
  and a missing cosign are refused, and an unapproved skill fails `verify --strict`.

The `v1` tag is created by the maintainers after review, never automatically.

MIT licensed.
