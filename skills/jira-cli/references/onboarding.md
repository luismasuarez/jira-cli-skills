# Onboarding a new developer

This is the end-to-end flow for a teammate who has never used JiraCLI. The goal
is that they install the skill, paste their token, and everything else is
automatic.

## What they need

- Linux or macOS, a Jira account.
- Docker (preferred) or `curl`.
- Their personal **API token** (secret, per person):
  - Cloud: <https://id.atlassian.com/manage-profile/security/api-tokens>
  - Server: profile → Personal access tokens (and `JIRA_AUTH_TYPE=bearer`).
- The company **defaults** file, provisioned by IT/onboarding (see below). With
  it, the developer never types the site URL or email.

## Company provision (once, private channel)

Distribute `~/.config/jira-cli-skills/defaults.env` on each machine (dotfiles,
MDM, or an onboarding script). Template: `assets/defaults.env.example`.

```
JIRA_SERVER=https://acme.atlassian.net
JIRA_LOGIN=you@acme.com
JIRA_INSTALLATION=cloud
JIRA_AUTH_TYPE=basic
# JIRA_PROJECT=      # optional
# JIRA_BOARD=        # optional
```

Without this file the wizard asks for the URL and email the first time.

## Developer flow

1. **Install the skill** (global, stable path):

   ```bash
   npx skills add luismasuarez/jira-cli-skills -g
   ```

   Or, with opencode/Claude using `skills.paths`, point at the repo's `skills/`.

2. **Run the wizard**:

   ```bash
   ~/.agents/skills/jira-cli/scripts/setup.sh
   # or, after the first run, the alias it creates:
   jira-setup
   ```

   Prefer the agent? Just ask it in plain language: *"configúrame Jira CLI y
   muéstrame mis tareas"* — the skill performs the same steps.

3. **Paste your token when asked.** The wizard prints the exact command for your
   shell (`set -Ux` in fish, `export ...` in bash/zsh) and never receives the
   value. Set it, then run `jira-setup` again to finish.

4. **Use it**:

   ```bash
   jm                                       # my tasks
   jira issue list -a$(jira me)
   jira sprint list --current -a$(jira me)
   jira issue view PROJ-123
   ```

## What the wizard does under the hood

1. Detects OS, shell, Docker, existing config and token.
2. Installs the executable: pinned Docker image, or a release binary in
   `~/.local/bin`.
3. Installs the `jira` shell function, completions and the `jm` abbreviation.
4. Verifies the credential (without seeing it).
5. Resolves site/email/project/board by precedence:
   `flags > env > defaults file > git user.email > prompt`, validates the URL
   (base only, no path) and checks `/rest/api/3/myself`.
6. Discovers projects/boards, auto-selecting when there is only one.
7. Generates `~/.config/.jira/.config.yml` and runs `verify.sh`.

It is idempotent: re-running never duplicates wrappers or overwrites an existing
config unless `--force` is passed.

## Agent mode

If there is no TTY (or `--yes` is used), the wizard never prompts. When a value
is missing it prints exactly what is needed and exits with code `2`, so the agent
knows what to ask the user for. Token values are never requested in chat.

## Manual fallback (no wizard)

```bash
skills/jira-cli/scripts/install.sh
skills/jira-cli/scripts/install_wrapper.sh
skills/jira-cli/scripts/install_completions.sh
# set JIRA_API_TOKEN, then:
skills/jira-cli/scripts/discover.sh projects
skills/jira-cli/scripts/configure.sh --server ... --login ... --project KEY --board "Board"
skills/jira-cli/scripts/verify.sh
```

See `references/auth.md`, `references/shells.md`, `references/workflow.md` and
`references/troubleshooting.md` for details.
