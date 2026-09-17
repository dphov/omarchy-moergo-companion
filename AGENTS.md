# Agent Authorization Rules

This document governs what autonomous actions this repository's AI agents may take without explicit human confirmation.

## General principle

"How to" questions must be answered with instructions only. Agents must not perform the action unless the user explicitly asks with a direct command such as "do it", "post it", "push it", or "run it".

## Actions requiring explicit confirmation

Before performing any of the following, the agent MUST ask the user explicitly:

- Posting, editing, or deleting comments, issues, pull requests, or any content on GitHub or other platforms under the user's identity.
- Creating, deleting, or force-pushing git tags or branches.
- Publishing a GitHub Release.
- Opening pull requests or merging branches.
- Running commands that send email, notifications, or messages on behalf of the user.
- Editing marketplace listings, plugin submissions, or public-facing metadata.
- Running `just release`, `git push --tags`, or any equivalent release-cut command.

## Allowed without explicit confirmation

- Local file reads and edits inside the repository.
- Local builds, tests, linting, and dry-run simulations that do not mutate remote state.
- Running `git commit`, `git push`, `just build`, or `just check` when the user has explicitly asked for those specific actions.
- Explaining how to perform any of the actions listed above.

## Default response to "how do I ...?"

Answer with clear, self-contained steps. End with an offer: "Let me know if you want me to do it." Do not perform the steps unless the user confirms.
