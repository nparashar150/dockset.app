<!--
  Three questions. A longer template than this does not get filled in.
-->

## What this changes

What broke, and how you know it is fixed. If it is a behaviour change rather
than a fix, what you tried and what the alternative was.

## Test

- [ ] There is a test for it.
- [ ] There is not, and here is why: the code cannot move somewhere
      `DocketTests` compiles. Name the file and say what it drags in.
      CONTRIBUTING.md, "What a test can actually reach", is the constraint.

## Before you open it

- [ ] **The title is a Conventional Commit.** `fix:` cuts a patch release,
      `feat:` cuts a minor one, and `docs:`, `chore:`, `refactor:`, `test:`,
      `ci:` and `build:` cut nothing. The release automation reads the title,
      so `fix:` and `feat:` are not interchangeable and neither is a bare
      sentence.
- [ ] No em dashes, and nothing naming the tooling the change was made with.
      CI fails the pull request on both.
- [ ] `Closes #123`, unless the branch came from `scripts/start-issue.sh`, in
      which case the issue is already linked and closes itself.
