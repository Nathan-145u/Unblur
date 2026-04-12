# Unblur

> Spec-Driven Development project. Read [docs/CONSTITUTION.md](docs/CONSTITUTION.md) for project principles and constraints.

## Layer 1 — Always Load

- [docs/CONSTITUTION.md](docs/CONSTITUTION.md) — Project principles, SSOT mapping, deviations log
- [docs/DECISIONS.md](docs/DECISIONS.md) — Architecture Decision Records

## Layer 1 — Load on Demand

- [docs/SCHEMA.md](docs/SCHEMA.md) — Database schema (when data model is involved)
- [docs/DESIGN.md](docs/DESIGN.md) — Design language (when UI is involved)

## Layer 2+3 — Feature Specs

- `specs/v0.x/xxx-feature/spec.md` — Feature requirements + acceptance criteria
- `specs/v0.x/xxx-feature/plan.md` — Technical implementation plan
- `specs/v0.x/xxx-feature/tasks.md` — Atomic work packages

## Layer 4 — Roadmap

- [docs/VERSION_PLAN.md](docs/VERSION_PLAN.md) — Version overview, shared architecture, tech stack

## Rules

- **Spec before code.** No implementation without a spec.
- **Spec is SSOT.** When code and spec disagree, spec wins.
- **Language:** Spec documents in English. Conversation in user's preferred language.
