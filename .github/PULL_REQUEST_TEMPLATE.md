## What & why

<!-- What does this change and why? Link any related issue. -->

Closes #

## API-parity checklist (required)

> Any public API added to one platform must land on the other in the same or a linked
> PR, with mirrored tests. See [CONTRIBUTING.md](../CONTRIBUTING.md).

- [ ] No public API change **— or —** the twin is included/linked: <!-- link -->
- [ ] Swift and Kotlin method names & behavior match
- [ ] Tests are mirrored across `ios/Tests` and `android/aksara-core/src/test`

## Checks

- [ ] `swift test` passes (if `ios/` touched)
- [ ] `./gradlew :aksara-core:test` passes (if `android/` touched)
- [ ] Docs updated if behavior/API changed
- [ ] Commits are authored by me only (no AI/tool attribution or `Co-Authored-By` bot trailers)
