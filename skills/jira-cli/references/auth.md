# Authentication

jira-cli reads the credential at runtime; it is **not** stored in
`~/.config/.jira/.config.yml`. Prefer the environment variable, and never print
its value.

## Jira Cloud (most companies)

1. Create an API token: <https://id.atlassian.com/manage-profile/security/api-tokens>
2. Export it, persistently, in the user's shell:
   - fish: `set -Ux JIRA_API_TOKEN "..."` (universal variable, survives restarts,
     lives in `fish_variables`, not in a tracked dotfile).
   - bash: add `export JIRA_API_TOKEN="..."` to `~/.bashrc`.
   - zsh: add `export JIRA_API_TOKEN="..."` to `~/.zshrc`.
3. `auth_type: basic` (default) with `login` = Atlassian account email.

## Jira Server / Data Center

- **Personal access token (recommended):** create it in the Jira profile
  (Profile → Personal access tokens), export as `JIRA_API_TOKEN`, and set
  `JIRA_AUTH_TYPE=bearer`. Use `--auth-type bearer` with `configure.sh`.
- **Basic with password:** export the login password as `JIRA_API_TOKEN` and use
  `--auth-type basic`. Works, but a PAT is preferred.
- **mtls:** `jira init` supports client certificates; choose `--auth-type mtls`
  and provide CA cert, client key and client cert when prompted (interactive).

## Alternative: `~/.netrc`

If the environment cannot carry variables, an entry works too:

```
machine acme.atlassian.net login you@example.com password <API_TOKEN>
```

`discover.sh` uses `--netrc` automatically when `JIRA_API_TOKEN` is unset. The
Docker wrapper does not mount `.netrc` by default; if you rely on it, add
`-v "$HOME/.netrc:/home/jira/.netrc"` to the wrapper template.

## SSO caveats (Cloud)

- API tokens are the supported path for Cloud even when the account uses SSO.
  If the org enforces SSO, the token still authenticates against the REST API.
- A wrong `login` (not the Atlassian account email) usually yields `401` rather
  than an HTML page. An HTML response instead means a wrong **URL** (see
  `troubleshooting.md`).

## Rules for AI agents

- Check presence only: `scripts/detect.sh` exposes `token_present` boolean and
  `token_source` (`env` | `netrc` | `none`).
- Never run commands that echo the variable (no `env`, no `echo $JIRA_API_TOKEN`,
  no `set -x` around it).
- When it is missing, hand the user the page + the one-line command to set it and
  wait.
