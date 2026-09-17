---
name: jira-cli
description: >
  Set up and use JiraCLI so any developer can manage Jira (Atlassian Cloud or
  Server) from the terminal without the web UI. Use this whenever the user
  mentions Jira, JiraCLI, jira tickets/tasks/issues, "mis tareas de Jira",
  "configurar Jira en la terminal", sprints, boards, JQL, API tokens, or wants
  to list, view, create, transition, or comment on Jira issues, or to configure
  Jira authentication. Covers Docker and local installs, fish/bash/zsh wrappers,
  shell completions, token setup, project/board discovery, verification, and the
  daily task workflow. One invocation must leave the tool fully configured, the
  shell equipped, and the user's tasks reachable.
license: MIT
compatibility:
  - opencode
  - claude-code
metadata:
  version: "1.0.0"
  tags: [jira, atlassian, cli, docker, setup, tasks, developer-workflow]
---

# JiraCLI — setup and workflow

Goal: after this skill runs **once**, the user has a working `jira` command in
their shell (running a pinned Docker image, or a local binary when Docker is not
available), a persisted config, completions, and can see their assigned tasks —
without opening Jira in a browser.

The setup is **idempotent**. Running it again must not duplicate wrappers,
re-prompt, or overwrite an existing config unless explicitly forced.

## Non-negotiables

- **Never print, echo, log, or ask the user to paste the API token.** Check for
  its presence only (`scripts/detect.sh` reports `token_present` as a boolean).
  If it is missing, give the user the exact page/command to set it and stop.
- **Prefer Docker.** It is the pinned, reproducible path and needs no host
  install. Fall back to a local release binary only when Docker is absent.
- **The server URL is the base only** (`https://acme.atlassian.net`). A URL with
  a path (`.../jira/software/projects/KEY/boards/N/...`) makes the API return
  HTML and jira-cli fails with `invalid character '<' looking for beginning of
  value`. `configure.sh` rejects it.
- **Verify before reporting success.** Run `scripts/verify.sh` and only claim
  done when it passes.

## Workflow

Run the scripts from this skill's directory. They are bash and read the pinned
version/paths from `scripts/_lib.sh`.

### 0. Preflight — know the environment

```bash
scripts/detect.sh
```

Parse the JSON. Decide:
- `docker: true` → Docker mode; else → local binary mode.
- `config_exists: true` → do **not** re-run `configure.sh` (skip to step 4).
- `token_present: false` → do step 3 before configuring.
- `wrapper_present` / `image_present` → skip work already done.

### 1. Install the executable

```bash
scripts/install.sh            # auto: Docker if available, else local binary
scripts/install.sh --docker   # force Docker
scripts/install.sh --local    # force release binary into ~/.local/bin
```

### 2. Equip the shell

```bash
scripts/install_wrapper.sh        # detects $SHELL, installs the jira function
scripts/install_completions.sh    # installs completions for the same shell
```

The wrapper forwards `JIRA_API_TOKEN` into the container and only allocates a
TTY when one is attached, so `jira ... --plain | grep` keeps working. It also
adds (in `references/shells.md`) the `jm` abbreviation: your assigned tasks.

### 3. Credential (user action — never handled in chat)

Confirm `detect.sh` shows `token_present: true`. If it is false, tell the user
(do not ask for the value):

- **Jira Cloud**: create an API token at
  <https://id.atlassian.com/manage-profile/security/api-tokens>, then set it in
  their shell, e.g. fish: `set -Ux JIRA_API_TOKEN "..."`; bash/zsh:
  `export JIRA_API_TOKEN="..."` (add to the shell rc).
- **Jira Server / Data Center**: use a personal access token and also set
  `JIRA_AUTH_TYPE=bearer` (basic auth with the login password also works).

Stop here until the user confirms the token is set. See `references/auth.md` for
`.netrc`, SSO, and mtls variants.

### 4. Discover project and board (only when configuring)

```bash
JIRA_SERVER=https://acme.atlassian.net JIRA_LOGIN=you@example.com scripts/discover.sh myself
JIRA_SERVER=... JIRA_LOGIN=... scripts/discover.sh projects
JIRA_SERVER=... JIRA_LOGIN=... scripts/discover.sh boards KEY
```

Use this to propose a default `--project`/`--board` instead of asking the user
to pick blindly. If there is a single board, use it.

### 5. Generate the config

```bash
JIRA_API_TOKEN=... scripts/configure.sh \
  --installation cloud \
  --server https://acme.atlassian.net \
  --login you@example.com \
  --auth-type basic \
  --project KEY --board "Board name"
```

Existing config is preserved unless `--force` is passed.

### 6. Verify

```bash
scripts/verify.sh
```

It asserts: executable works, config exists and is user-owned, credential is
present, `jira me` resolves, projects are visible, and assigned tasks are
reachable. Fix any FAIL before finishing.

### 7. Report and hand off

Tell the user, concisely:
- what was installed (image tag or binary path), where the config lives;
- that a **new shell** (or `source` of their rc) is needed to pick up `jira`;
- the daily commands, e.g.:

```bash
jira issue list -a$(jira me)            # my tasks (interactive UI)
jm                                       # same, via the abbreviation
jira sprint list --current -a$(jira me)  # current sprint
jira issue list -a$(jira me) --plain     # pipe-friendly
jira issue view PROJ-123                # details in the terminal
```

For more (JQL, transitions, comments, multiple configs) read
`references/workflow.md`.

## Reference map (load only when needed)

- `references/auth.md` — token creation for Cloud/Server, `.netrc`, SSO, mtls.
- `references/shells.md` — wrapper/completion details, `jm`, manual install.
- `references/workflow.md` — daily commands, filters, JQL, create/move/comment.
- `references/troubleshooting.md` — the HTML-parse error, container DNS,
  root-owned config, and Docker limitations (`open`, clipboard).

## Done conditions

The task is complete only when all hold:

- Executable available (pinned image present, or `~/.local/bin/jira`).
- `jira version` runs through the installed shell function.
- Credential present; never printed.
- `~/.config/.jira/.config.yml` exists, is owned by the user, with correct
  server/login/project/board.
- Wrapper installed for the detected shell; `jm` resolves.
- Completions installed.
- `scripts/verify.sh` exits 0.
- Re-running the setup produces no duplicated blocks and exits 0.
