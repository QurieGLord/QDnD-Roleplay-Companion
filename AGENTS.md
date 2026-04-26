Please refer to `.docs/AGENTS.md` for the core instructions, context, and rules regarding this project.
Commit workflow note: agents should not commit autonomously; instead, they should propose a `git commit -m "..."` line at the end of each completed task, and if the user has not confirmed the previous commit, the next proposal should include all still-uncommitted changes.
