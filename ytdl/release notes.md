Fixes

- Cap the clipboard read that runs when the panel opens, so oversized clipboard content is ignored instead of buffered without limit.
- Bound clipboard bytes before the parser collects them, so an unterminated clipboard stream cannot pile up in memory.
- Route all field pastes through the capped helper, so Qt's own clipboard path never runs.
