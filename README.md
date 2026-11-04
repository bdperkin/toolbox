# toolbox

Builds and manages domain-specific Fedora [`toolbox`](https://containertoolbx.org/) container
images — Audio/Video, Development, Editors, Graphics, and Web Browsers — plus the host-side
glue that keeps a developer's shell integrated with those containers.

## What's here

- `containerfiles/` — one `Containerfile.fedora-toolbox-<flavor>` per domain image.
- `files/` — `dnf-install-<flavor>.sh` package-installation scripts run during each image
  build, plus `files/lib/` shared helpers they source.
- `bashrcs/` — `<flavor>.sh` fragments, synced into `~/.bashrc.d/`, that ensure the matching
  toolbox container is running and put its PATH shims in front of `$PATH`.
- `tools/` — `toolbox-update.sh`, the orchestrator a developer runs to pull fresh images,
  recreate containers, and regenerate PATH shims; `sync-toolbox-<flavor>.sh` shim generators
  it invokes per flavor; and `tools/lib/` shared helpers.
- `Makefile` — local build/push/remove targets for a single image flavor.

See [`CLAUDE.md`](CLAUDE.md) for the full architecture notes, command reference, and
troubleshooting guide.

## Getting started

```sh
# Build and push one flavor's image
CONTAINER_FLAVOR=fedora-toolbox-devel make push

# Reconcile containers + host shims/bashrc for every flavor
tools/toolbox-update.sh
```

`make help` lists available Makefile targets and image flavors.

## Linting

```sh
pre-commit run --all-files --show-diff-on-failure
```

Runs shellcheck, shfmt, hadolint, yamllint, markdownlint, and GitLab CI schema validation —
the same checks CI runs on every pipeline.
