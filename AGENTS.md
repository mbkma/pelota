# Development Rules

- Prefer Godot's built-in classes and features over custom implementations. Favor editor-configurable nodes, scenes, and resources over hardcoded logic to keep everything easily editable by humans. Use code when necessary.
- Fix root causes. Never add fallbacks to conceal underlying problems.
- Do not retain obsolete code for backward compatibility unless explicitly requested.
- Prefer named classes and well-defined interfaces where they improve clarity
  and maintainability. Avoid unnecessary abstractions.
- Never modify files inside `addons/`.
- Use existing addon APIs without editing addon internals.
- If creating assets always try to make them easily editable by humans if possible.
- Only copy those assets into the assets folder that are really used.