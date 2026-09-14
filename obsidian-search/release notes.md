## Fixes

- Creating a new note from a query that looks like a path (for example containing `../`) can no longer write outside the vault. Such queries no longer offer a create row, and note creation now verifies the destination stays inside the vault before writing.
