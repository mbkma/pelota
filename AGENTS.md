# Development Rules

## Code Quality
- Fix root causes. Never add fallbacks to conceal underlying problems.
- Do not retain obsolete code for backward compatibility unless explicitly requested.
- During substantial changes, refactor affected code when necessary to maintain
  clean architecture. Avoid unrelated refactoring.
- Prefer explicit, statically resolvable dependencies over runtime resource
  loading by string path.
- Prefer named classes and well-defined interfaces where they improve clarity
  and maintainability. Avoid unnecessary abstractions.

## Project Boundaries
- Never modify files inside `addons/`.
- Use existing addon APIs without editing addon internals.

## Workflow
- Inspect relevant code before modifying it.
- Follow existing project conventions and reuse existing systems where appropriate.
- For substantial changes, identify the affected files and outline the approach
  before implementation.
- For small, straightforward changes, implement directly without unnecessary planning.
- Keep changes focused on the requested task.
- Run relevant tests or validation after changes.
- Fix regressions introduced by your changes.
- Do not claim that tests passed unless they were actually executed.

## Efficiency
- Avoid exploring unrelated files or rereading code that is already understood.
- Prefer targeted searches and reading relevant sections over dumping entire files.
- Do not repeat investigations or checks without a reason.
- Keep explanations and final reports concise.
- If blocked, explain the specific blocker rather than repeatedly trying
  variations of an unsuccessful approach.