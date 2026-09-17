# Troubleshooting

## `jira: command not found` (especially in non-interactive/agent shells)

`jira` must be the executable shim at `~/.local/bin/jira`, not only an rc-loaded
shell function: agents run `bash -c`, which never sources `~/.bashrc`/`.zshrc`.

Fix:

```bash
scripts/install_wrapper.sh            # reinstala el shim
command -v jira                       # debe resolver a ~/.local/bin/jira
export PATH="$HOME/.local/bin:$PATH"  # si no estaba en PATH (añádelo a tu rc)
```

`scripts/detect.sh` reports `jira_on_path` and `shim_present`.

## `invalid character '<' looking for beginning of value`

The API returned HTML, not JSON. Almost always the **server URL includes a
path**. jira-cli appends `/rest/api/...` to the server value, so a URL like
`https://acme.atlassian.net/jira/software/projects/PROJ/boards/123/backlog`
resolves to an HTML page.

Fix: use only the base `https://acme.atlassian.net`. `configure.sh` rejects URLs
with paths. Verify manually:

```bash
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' \
  -u "you@example.com:$JIRA_API_TOKEN" \
  https://acme.atlassian.net/rest/api/3/myself
# expect: 200 application/json
```

## Container cannot resolve DNS (`dial tcp: lookup ... i/o timeout`)

The host resolves but the container does not, typically because
`/etc/resolv.conf` points at `127.0.0.53` (systemd-resolved). Re-run with an
explicit resolver, or add `--dns 1.1.1.1` to the wrapper's `docker run` args:

```bash
docker run --rm --dns 1.1.1.1 ... ghcr.io/ankitpokhrel/jira-cli:v1.7.0 ...
```

DNS failures are sometimes transient; retry once before changing anything.

## Config owned by `root`

If the wrapper was run without `--user "$(id -u):$(id -g)"`, the bind mount gets
root-owned files. Fix ownership and always run via the skill wrapper:

```bash
sudo chown -R "$(id -u):$(id -g)" ~/.config/.jira
```

## `401` / `403` on API calls

- Wrong email in `login`, or token not exported in the current shell.
- Server install without `JIRA_AUTH_TYPE=bearer` when using a PAT.
- Token expired/revoked: regenerate it.

## `board not found` during init

Pass an exact board name from `scripts/discover.sh boards KEY`, or let `jira init`
prompt by omitting `--board`.

## Completions do nothing

Completions are per shell. Re-run `scripts/install_completions.sh` and start a
new shell. In fish the file must be `~/.config/fish/completions/_jira.fish`.

## Docker limitations (expected)

- `jira open` / `ENTER` cannot launch a host browser from the container.
- Copy-to-clipboard (`c`, `CTRL+k`) needs `xsel`/`xclip` and a display.
If either is a hard requirement, use the local binary path
(`scripts/install.sh --local`) instead of Docker.

## Pager issues in scripts

`jira issue view` pages with `less`. In pipelines prefer `--plain`/`--raw`, or
set `PAGER=cat`.

## `python3` missing

`discover.sh` uses `python3` to format JSON. Without it, install Python 3 or read
the raw API responses directly.
