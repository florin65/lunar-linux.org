Lunar Linux Website has been promoted to version 3.3.

This release marks the completion of a major internal evolution of the website generator. The build system is now incremental, resilient and easier to verify, while preserving the simple static architecture of the project.

The new generator rebuilds only the pages and news entries whose sources or relevant dependencies have changed. Content that remains unchanged is reused instead of being generated again.

Website 3.3 also introduces safer archive handling, controlled cleanup of stale generated files, persistent administrative build reports and a strict validation mode suitable for automated checks.

The historical news archive remains protected: isolated archive problems no longer prevent the active website from being generated, and valid previously generated pages can be preserved when recovery is needed.

The result is a faster and more dependable build process without introducing a heavyweight framework or abandoning the project's shell-based, transparent design.

> Website 3.3 turns the generator from a full rebuild script into a deterministic, incremental and recoverable build system.
