# Repo Instructions

These instructions apply to the entire repository.

## Keep `AGENTS.md` and `CLAUDE.md` identical

`REPO_INSTRUCTIONS.md` is the shared source of truth for repo guidance.

- `AGENTS.md` and `CLAUDE.md` must remain byte-for-byte identical wrapper files that direct the agent to read `./REPO_INSTRUCTIONS.md`.
- If you change the wrapper text in one file, make the same change in the other file.
- Do not intentionally diverge the contents between those two wrapper files.

## Escalation (Commands That Often Need Real AWS/Network/Docker)

- request escalation for `just tg <env> <module> validate` and `just tg-all <env> plan|apply|destroy`
- prefer asking for escalation up front when the task clearly depends on AWS, remote state, or the local Docker daemon

## Documentation Contract

- keep docs aligned with behavior changes
- README files explain the system to humans and agents; `REPO_INSTRUCTIONS.md` tells agents how to work in this repo
- keep human-facing technical contracts in the nearest owning README, not duplicated in `REPO_INSTRUCTIONS.md`
- use `REPO_INSTRUCTIONS.md` as the agent operating manual and context router
- entry point: `README.md` (human-facing high-level map, setup, and infra layout)
- module contracts: `infra/modules/**/README.md`
- before editing, read the relevant local contract docs for the files you plan to touch and follow those contracts
- when adding or reorganizing docs, prefer short README sections that point to the owning nested README rather than expanding the root README with deep implementation detail
- when removing detail from one doc, relocate the content to the owning doc instead of dropping it; it may be shortened or clarified, but the underlying guidance must remain findable in the repo

## Context Loading Order

- load context lazily and only as needed
- start with `REPO_INSTRUCTIONS.md`, then `README.md`
- next read only the relevant contract docs for the capability subset being considered
- only after that inspect implementation files for the selected shape
- avoid loading unrelated capability areas unless the task requires them

## Current Repo Shape

- the active live stacks are `infra/live/dev/aws/security` and `infra/live/prod/aws/security`
- the active Terraform module is `infra/modules/aws/security`
- the repo-local helper surfaces are the root `justfile` and `scripts/ci/justfile`
- treat the current filesystem and tracked config as the source of truth; if docs or comments reference repo surfaces that are not present, verify them before acting on them

## Feasibility + Dependency Checks (When Editing Infra / Workflows)

- verify the current stack/module shape and required backing resources before changing infra
- before adding environments or changing generated AWS names, verify the resulting AWS names because many names include account, region, environment, and repo name
- before adding Terragrunt dependency edges, verify the target live stack exists in that environment and review the raw dependency graph with `just tg-graph <env>` when needed
- for cross-stack output passthroughs, preserve consumer-facing output names and update the nearest module README
- prefer Terragrunt `dependency` inputs plus `mock_outputs` over `terraform_remote_state`; if remote state is intentional, add a `# remote_state_reason: ...` comment
- when introducing or expanding bootstrap/mock-output behavior, update the nearest owning human-facing README
- for detailed checks, read `README.md` and the nearest owning README files

## Terragrunt Plan Expectation

- for a change scoped to one concrete live stack/module, run the targeted plan, for example `just tg dev aws/security plan`
- for changes touching both environments, shared modules, Terragrunt dependency edges, or cross-stack contracts, run the environment plan, for example `just tg-all dev plan`
- do not run both targeted and environment plans unless the first plan exposes a reason to broaden verification
- for noisy plans or logs, create an ignored per-run directory before writing command output there, for example `mkdir -p tmp && run_tmp="$(mktemp -d tmp/plan.XXXXXX)"`, and return only filtered summary lines such as `No changes`, `Plan:`, `Error:`, `Failed`, or relevant `WARN`
- treat saved plans as apply-intent artifacts
- if credentials, network, permissions, or state access block planning, say so and name the exact manual plan command
- for saved-plan and mock-output details, read `infra/README.md`

## High-Signal Edit Warnings

- before editing `scripts/ci/justfile`, warn the human in commentary that the file is used by automation as well as local commands
