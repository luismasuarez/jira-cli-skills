# Shell integration

`install_wrapper.sh` installs a `jira` function so the command behaves natively
while the actual work runs in the pinned Docker image. `install_completions.sh`
adds completion for the same shell.

## What the wrapper does

- Runs `ghcr.io/ankitpokhrel/jira-cli:<pinned>` with `--entrypoint jira`.
- Runs as the current uid/gid (`--user "$(id -u):$(id -g)"`) and sets
  `HOME=/home/jira`, mounting `~/.config/.jira` there. This keeps the config
  owned by the user instead of `root:root`.
- Forwards `JIRA_API_TOKEN` from the environment.
- Adds `-it` **only when stdin and stdout are TTYs**, so pipelines and command
  substitution (`$(jira me)`, `jira ... --plain | grep`) keep working.
- Falls back to `~/.local/bin/jira` when Docker is not available.

The same logic lives in `scripts/_lib.sh` (`jira_cmd`) for non-interactive use
by the other scripts.

## Install locations

| Shell | Wrapper | Completions |
|-------|---------|-------------|
| fish  | `~/.config/fish/functions/jira.fish` | `~/.config/fish/completions/_jira.fish` |
| bash  | block in `~/.bashrc` (markers) | `~/.local/share/bash-completion/completions/jira` |
| zsh   | block in `~/.zshrc` (markers) | `~/.zfunc/_jira` (+ `fpath` line) |

bash/zsh wrappers are wrapped in `# >>> jira-cli skill >>>` /
`# <<< jira-cli skill <<<` markers, so re-running only rewrites that region and
never touches the rest of the rc file. A non-skill `jira.fish` is backed up
before being replaced.

## `jm` — my tasks

`install_wrapper.sh` also installs the abbreviation/alias:

- fish: `~/.config/fish/conf.d/jira-cli.fish`
  (`abbr --add jm 'jira issue list -a(jira me)'`). `conf.d` is sourced at
  startup, so `jm` is ready before the first `jira` call.
- bash: `alias jm='jira issue list -a$(jira me)'` inside the marker block in
  `~/.bashrc`.
- zsh: same alias inside the marker block in `~/.zshrc`.

To add it by hand instead:

- fish: `abbr --add jm 'jira issue list -a(jira me)'`
- bash/zsh: `alias jm='jira issue list -a$(jira me)'`

## New shell required

Config-time files are read when the shell starts. Tell the user to open a new
terminal (or `source` the rc / `so` if they have that abbreviation).

## Manual install (no scripts)

```fish
# fish
abbr --add jm 'jira issue list -a(jira me)'
jira completion fish > ~/.config/fish/completions/_jira.fish
```

## Optional hardening

If container DNS resolution is flaky (common with `systemd-resolved` on the
host), add `--dns 1.1.1.1` to the `docker run` arguments in the wrapper.

## opencode / Claude registration

The skill lives in a repo with a `skills/` folder. Register it by adding the
absolute path to `skills.paths`:

```json
{
  "skills": { "paths": ["/abs/path/to/jira-cli-skills/skills"] }
}
```

Then **restart** opencode/Claude so config is reloaded.
