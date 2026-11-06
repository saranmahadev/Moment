# Working agreement: TDD and git

## Branches

- `main` always builds and passes every test. Nothing is committed to it directly except merges.
- One short-lived branch per chunk of work: `feat/<topic>`, `fix/<topic>`, `chore/<topic>`.
- A chunk is a slice a person can review in one sitting: one rule, one screen, one pipeline.
- A chunk merges into `main` with `git merge --no-ff`, so every chunk stays visible in history as one unit.

## TDD inside a chunk

Each behaviour is two commits, in this order:

1. `test(<scope>): <behaviour>` : the failing test (red).
2. `feat(<scope>): <behaviour>` : the least code that makes it pass (green). Refactors get their own `refactor:` commit and never change behaviour.

Small related behaviours can share one red/green pair. Production code never lands without a test commit before it.

## Commit messages

Conventional Commits: `type(scope): summary` in the imperative, 72 characters or fewer, with a body saying why when it is not obvious.
Types: `feat`, `fix`, `test`, `refactor`, `chore`, `docs`, `ci`, `build`.

## Merge gate

Before a chunk merges into `main`:

- `dart format --set-exit-if-changed .` is clean.
- `flutter analyze` has no issues.
- `flutter test` is green.
- For UI chunks, golden images are approved against the mockup artboard.

## Releases

- Each phase ends with a tag `v0.1.0`, `v0.2.0`, `v0.3.0`, `v0.4.0`, and `v1.0.0` after Phase 5.
- A tag is created only after CI is green on the release commit and the phase exit gate in the roadmap is met.
- `CHANGELOG.md` gets one entry per release.

## Never in git

Signing keys, `key.properties`, user data, generated `*.g.dart` files.
