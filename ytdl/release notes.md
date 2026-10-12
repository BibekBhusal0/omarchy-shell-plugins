Fixes
- Replace TextInput fields with plain-text TextEdit editors, so clipboard changes only check offered formats and move no bytes.
- Bound every paste path through the capped clipboard helper, which now also has an overall deadline.
- Pass user extra args through to downloads again, so options like an audio format take effect.
