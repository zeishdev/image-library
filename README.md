# image-library

Docker images for the spinupdev platform. Images are published to
[ghcr.io/spinupdev](https://github.com/orgs/spinupdev/packages).

## Images

| Image | Base | Description |
|-------|------|-------------|
| [`base`](images/base) | ubuntu:26.04 | Shared dev toolchain: Docker, version-switchable Go/Node/Python (`g`/`nvm`/`pyenv`), ripgrep/fzf/fd/gh/jq, filebrowser, AI agent CLIs, **Chrome** (amd64) / Playwright Chromium (arm64), `zeish-chrome-cdp` helper. Not run standalone in practice — `desktop-x11` and `workstation` both build `FROM` it |
| [`desktop-x11`](images/desktop-x11) | `base` | X11 desktop: Xvfb/xfwm4/picom/x11vnc over noVNC (`:6080`); `sandboxd` drives input/screenshot in-process over XTEST (no `desktop-agentd`, no Wayland). `zeish-chrome` visible-window/CDP launcher |
| [`ubuntu`](images/ubuntu) | ubuntu:26.04 | Base Ubuntu with SSH, user setup, and init |
| [`workstation`](images/workstation) | `base` | Headless dev workstation — `base` plus sshd |

`desktop-x11` and `workstation` share the exact same toolchain (`base`) so a script
or agent that works in one works in the other; `desktop-x11` is just `base` with a
GUI bolted on.

### Agent browser (Arin / Playwright CDP)

`base` (and therefore `desktop-x11` / `workstation`) installs:

| Path | Role |
|------|------|
| `/usr/bin/google-chrome-stable` | Google Chrome (linux/amd64) |
| `/usr/local/bin/google-chrome-stable` | Playwright Chromium symlink (arm64) |
| `/usr/local/bin/zeish-chrome-cdp` | Starts Chrome with `--remote-debugging-port` (default **9222**) |

```sh
# Inside a running sandbox:
zeish-chrome-cdp 9222
# → prints STARTED when http://127.0.0.1:9222/json/version is ready
```

Arin (`@arin/harness` `ensureZeishBrowserCdp`) prefers this helper, then falls
back to the same binary paths. Edge templates should use the **desktop** image
and expose port **9222** for preview/CDP tunnels.

## Building locally

Each image has a `Makefile` with standard targets.

```sh
# desktop and workstation are FROM ghcr.io/spinupdev/base:latest, so build
# base first (or `make base` from the repo root)
make -C images/base build

# Build a specific image
make -C images/desktop-x11 build

# Build and run the desktop image (opens on :6080)
make -C images/desktop-x11 run
```

Or use Docker Compose for the desktop image:

```sh
cd images/desktop-x11
docker compose up
```

Environment variables for the desktop image:

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_RESOLUTION` | `1280x720` | Display resolution |
| `VNC_DEPTH` | `24` | Color depth |
| `AUTH_ENABLED` | `false` | Enable JWT auth on the noVNC proxy |

## Releasing

Releases are tag-driven. Pushing a tag of the form `<image>/v<semver>` triggers
the [build workflow](.github/workflows/build.yml), which builds the image and
pushes both the version tag and `latest` to GHCR.

```sh
# Release desktop v1.2.0
git tag desktop/v1.2.0
git push origin desktop/v1.2.0

# Release ubuntu v1.0.0
git tag ubuntu/v1.0.0
git push origin ubuntu/v1.0.0
```

The workflow builds for all platforms listed in the image's `platform` file.

`desktop-x11` and `workstation` `FROM ghcr.io/spinupdev/base:latest` — release
`base` first (`git tag base/v1.0.0 && git push origin base/v1.0.0`) whenever
its Dockerfile changes, before re-releasing `desktop-x11`/`workstation`.

## Adding a new image

1. Create the image directory and Dockerfile:
   ```
   images/<name>/Dockerfile
   ```

2. Add a `platform` file listing the target architectures:
   ```sh
   echo "linux/amd64,linux/arm64" > images/<name>/platform
   ```

3. Tag a release to publish:
   ```sh
   git tag <name>/v1.0.0 && git push origin <name>/v1.0.0
   ```

No workflow changes needed — the build workflow picks up any image automatically
from the tag prefix.
