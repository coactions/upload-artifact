# `@coactions/upload-artifact`

This actions acts like a drop-in wrapper replacement for original
`@actions/upload-artifact` action.

Before running original action, it will scan the archive files with gitleaks
and refuse to archive the artifacts if any secrets are detected.
