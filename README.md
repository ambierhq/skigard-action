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
          version: 0.1.0
          # sha256: <archive checksum from the release's checksums.txt>   # optional, pins the exact bytes
```

Pin this action by commit SHA, like every action in a security-sensitive workflow. The `v1` tag moves; a SHA does not.

## Inputs

| Input | Default | |
|---|---|---|
| `version` | required | skigard version without the `v`, e.g. `0.1.0`. There is no `latest`, on purpose. |
| `sha256` | none | SHA-256 of the archive for the runner (`skigard_<version>_<os>_<arch>.tar.gz`, `.zip` on Windows). The download must match it. |
| `args` | `--strict` | Arguments for `skigard verify`. |
| `home` | `.skigard` | `SKIGARD_HOME` (project scope), relative to `working-directory`. |
| `working-directory` | `.` | |
| `verify` | `true` | `false` only installs skigard. |
| `base-url` | the GitHub release | Asset location for mirrors and this action's tests. `https://`, `file://` or localhost only. |

Output: `version`, the installed `skigard version` line.

## What it does and does not do

- Downloads `skigard_<version>_<os>_<arch>` and `checksums.txt` from the GitHub release, refuses on any SHA-256 mismatch
  (against `checksums.txt`, and against your `sha256` input when set), extracts only the binary and adds it to `PATH`.
- Runs on Linux, macOS and Windows runners (x64 and arm64).
- Never runs `skigard approve`: approval needs a human at a terminal and is not possible in CI.
- It does not verify the cosign signature of `checksums.txt` yet. Pin `sha256` for the strongest guarantee, or verify with
  `cosign verify-blob` as documented in the skigard repository. (Planned: optional signature verification.)
- No telemetry; the only network access is the download above.

## Development

`.github/workflows/ci.yml` builds skigard from `main`, packages it like a release, serves it from localhost and runs the
action against it (success, pinned checksum, wrong checksum, tampered archive, bad version, non-local URL, store drift) on
Linux, macOS and Windows. The `v1` tag is created by the maintainers after review, never automatically.

MIT licensed.
