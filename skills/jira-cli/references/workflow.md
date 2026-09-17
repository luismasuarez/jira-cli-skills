# Daily workflow

Everything below runs through the `jira` shell function (Docker-backed). Use it
from the terminal; for scripting use `--plain`/`--raw`/`--csv`.

## Find your work

```bash
jira me                                   # your account
jira issue list -a$(jira me)              # assigned to me (interactive UI)
jira issue list -a$(jira me) --plain      # plain table (pipe-friendly)
jira issue list -a$(jira me) --raw        # JSON
jira issue list -a$(jira me) --csv        # CSV
jira sprint list --current -a$(jira me)   # current sprint
jira issue list --history                 # tickets you opened recently
```

## Filters (combinable)

```bash
jira issue list -s"En curso"                       # by status
jira issue list -yHigh -sopen                      # priority + open
jira issue list -tBug -a$(jira me) -sDone          # type + assignee + status
jira issue list --created week                     # created this week
jira issue list -lbackend -yHigh --created month   # labels + priority + period
jira issue list -s~Done                            # NOT done (~ negates)
jira issue list -q "summary ~ login"               # raw JQL in project context
```

## Inspect and act

```bash
jira issue view KEY-123                 # details (add --comments N)
jira issue move KEY-123 "In Progress"   # transition; --comment "..." too
jira issue comment add KEY-123 "text"
jira issue create -tBug -s"Summary" -yHigh -b"Description" --no-input
jira issue edit KEY-123 -s"New summary"
jira issue assign KEY-123 "$(jira me)"
jira issue link KEY-123 KEY-456 Blocks
jira issue worklog add KEY-123 "1h 30m"
```

## Boards, epics, sprints, releases

```bash
jira board list
jira epic list [EPIC-KEY]
jira sprint list --current --prev --next
jira sprint add SPRINT_ID ISSUE-1 ISSUE-2
jira release list --project KEY
```

## Interactive UI keys

`j/k/h/l` navigate, `v` view, `m` transition, `c` copy URL, `CTRL+k` copy key,
`ENTER` open in browser, `CTRL+r`/`F5` refresh, `?` help, `q` quit.

> Inside Docker the browser/clipboard features do not work (no host browser or
> `DISPLAY`); everything else does.

## Multiple sites/projects

Point a command at a different config file:

```bash
JIRA_CONFIG_FILE=./other.yml jira issue list
jira issue list -c ./other.yml
jira issue list -p OTHER                    # override project per call
```

## Scripts over the output

```bash
jira issue list -a$(jira me) --plain --columns key,status,summary --no-headers
scripts/list-my-tasks.sh --columns key,status,summary --no-headers
```
