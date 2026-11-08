## New features

- Typing a query now offers a `Send to <agent>` row below the web search row. It hands the query straight to your default Omarchy agent as its first prompt, whatever `omarchy default agent` is set to. Turn it off with `"sendToAgent": false` in `~/.config/omarchy/menu.json`.
- The agent starts in `~` by default. Set `"agentDirectory"` in the same file to open it somewhere else.
