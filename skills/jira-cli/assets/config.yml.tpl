# Reference template for ~/.config/.jira/.config.yml
#
# Prefer generating this file with `jira init` (via scripts/configure.sh):
# it fills in issue types and custom fields automatically by querying Jira.
# This template is a fallback/reference for what the file looks like and for
# environments where the metadata endpoints are unavailable.
#
# Values in <angle brackets> are placeholders. Do NOT add your API token here;
# the token lives in JIRA_API_TOKEN (or ~/.netrc).

installation: Cloud          # Cloud | Local
server: <https://acme.atlassian.net>   # base URL only, no path
login: <you@example.com>
auth_type: basic             # basic | bearer | mtls
project:
    key: <KEY>
    type: <next-gen|classic>
board:
    id: <board-id>
    name: <board name>
    type: <simple|scrum|kanban>
epic:
    name: ""
    link: ""
timezone: <America/Caracas>
