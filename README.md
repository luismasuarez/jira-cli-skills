# jira-cli-skills

[![skills.sh](https://skills.sh/b/luismasuarez/jira-cli-skills)](https://skills.sh/luismasuarez/jira-cli-skills)

A shared skills repository for the team. Today it ships one skill:

- **`jira-cli`** — set up and use [JiraCLI](https://github.com/ankitpokhrel/jira-cli)
  so any developer can manage Jira (Cloud or Server) from the terminal, without
  the web UI. One invocation leaves the tool installed (pinned Docker image, or
  a local binary fallback), an executable `jira` shim on PATH (so the command
  works in any shell, including an agent's non-interactive one), the shell
  equipped (wrapper + completions + `jm`), the credential and config in place,
  and the assigned tasks reachable.

The skill is idempotent, never touches the API token value, and verifies itself
before reporting success.

## Requirements

- Linux or macOS.
- One of: **Docker** (preferred) or `curl` (for the local binary fallback).
- A Jira account (Cloud or Server/Data Center).
- Optional: `python3` (used by `discover.sh` to format API responses).

## Register the skill

Install it with the open skills CLI (works with opencode, Claude Code, Cursor,
Codex and 37+ agents). Global install (`-g`) gives a stable path under
`~/.agents/skills/`:

```bash
npx skills add luismasuarez/jira-cli-skills -g
```

Or register this repo's `skills/` directory directly.

opencode and Claude Code both load skills from a `SKILL.md` folder. Point them
at this repo's `skills/` directory.

### opencode

Add to `~/.config/opencode/opencode.jsonc`:

```json
{
  "skills": { "paths": ["/absolute/path/to/jira-cli-skills/skills"] }
}
```

### Claude Code

Symlink the skill into the Claude skills directory:

```bash
ln -s "$PWD/skills/jira-cli" ~/.claude/skills/jira-cli
```

Then **restart** the agent so it reloads config.

### Helper

```bash
./install.sh              # prints the registration snippets for your machine
./install.sh --link claude   # symlinks skills/jira-cli into ~/.claude/skills
./install.sh --link opencode # symlinks into ~/.config/opencode/skills
```

## After installing — the teammate flow

One command configures everything (tool, shell, completions, `jm`, config,
verification):

```bash
~/.agents/skills/jira-cli/scripts/setup.sh   # or the jira-setup alias it creates
```

The only manual step is pasting your **API token**; the wizard tells you exactly
how and waits. Site URL, email, project and board are resolved automatically:

```
flags > env (JIRA_*) > ~/.config/jira-cli-skills/defaults.env > git user.email > prompt
```

The company provisions `~/.config/jira-cli-skills/defaults.env` (template:
`skills/jira-cli/assets/defaults.env.example`) so a dev only pastes the token.
Details: [skills/jira-cli/references/onboarding.md](skills/jira-cli/references/onboarding.md).

Useful modes:

```bash
scripts/setup.sh --guide    # print requirements/links/commands; change nothing
scripts/setup.sh --yes      # agent/CI: no prompts; exit 2 stating what is missing
```

## Use it

Ask the agent, in plain language, e.g.:

- "Configúrame Jira CLI y muéstrame mis tareas."
- "Quiero ver el PROJ-123 desde la terminal."

Or run the steps manually, in order:

```bash
skills/jira-cli/scripts/detect.sh
skills/jira-cli/scripts/install.sh
skills/jira-cli/scripts/install_wrapper.sh
skills/jira-cli/scripts/install_completions.sh
# set your token (see references/auth.md), then:
JIRA_SERVER=https://acme.atlassian.net JIRA_LOGIN=you@example.com \
  skills/jira-cli/scripts/discover.sh boards KEY
JIRA_SERVER=... JIRA_LOGIN=... skills/jira-cli/scripts/configure.sh \
  --server https://acme.atlassian.net --login you@example.com --project KEY --board "Board"
skills/jira-cli/scripts/verify.sh
```

## Daily commands

```bash
jira issue list -a$(jira me)            # my tasks (interactive)
jm                                       # abbreviation for the above
jira sprint list --current -a$(jira me)
jira issue view KEY-123
```

## Layout

```
skills/jira-cli/
├── SKILL.md            # the agent-facing instructions
├── references/         # auth, shells, workflow, troubleshooting
├── scripts/            # detect, install, wrapper, completions, discover, configure, verify
├── assets/             # shell templates + config template
└── evals/              # test prompts and assertions
```

## Security

- The API token is never printed, logged, or requested in chat. The scripts only
  check whether it exists (`token_present`) and pass it through.
- The config directory is written with the user's own uid/gid.

## License

MIT — see [LICENSE](LICENSE).
