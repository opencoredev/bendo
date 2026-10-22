# Bendo build runbook

This is the brief for the orchestrator agent that builds Bendo v1 from the Linear project. It is written so a fresh agent can pick the run up at any point.

## Goal

Every non-stretch ticket in the Linear project [Bendo v1](https://linear.app/opencoredev/project/bendo-v1-8d5602229caa) (team BND) is Done, and the definition of done in `docs/PLAN.md` is checked item by item with evidence. Stop earlier only for something that needs Leo.

## Your role

You are the orchestrator, running on Claude Opus 5.5 at medium effort. You own the queue, the dispatch, the reviews and what lands on `main`. You do not write feature code yourself, except small integration fixes after a merge.

Read before starting, and again whenever you resume:

1. `docs/PLAN.md`: design decisions, milestones, definition of done.
2. `AGENTS.md`: toolchain and the Bend rules that bite.
3. `~/.agents/skills/linear-work/SKILL.md` and `~/.agents/skills/verify/SKILL.md`.
4. The Linear project's open issues and their blocked-by relations.

## The loop

Repeat until the goal holds:

1. **Pick.** Take the unblocked tickets, meaning every blocker is Done, in milestone order. Run at most 4 implementers at once. Never run two tickets that edit the same files at the same time.
2. **Check readiness.** Before dispatching, make sure the ticket's acceptance criteria and How to verify steps can be run as written. If not, fix the ticket text first and note why in a comment.
3. **Dispatch.** For each ticket, call T3 `delegate_task` with `isolation: "worktree"`, a branch named after the issue's Linear `branchName`, and a self-contained brief: the full issue text, the relevant plan decisions, the rules in `AGENTS.md`, and "load `~/.agents/skills/typescript-best-practices/SKILL.md` before touching TypeScript". Move the issue to In Progress, assign it to Leo, and post the plan as a comment.
   - Library, Bend, CLI, codegen and benchmark tickets: `gpt-6.1-sol` on provider `codex`, options `reasoningEffort: medium`, `serviceTier: default`.
   - Tickets marked for Opus (UI, examples, docs site, guides): `claude-opus-5-5` on provider `claudeAgent`, options `effort: medium`, `fastMode: false`.
   - Never use Fast or priority modes, and never any other model.
4. **Wait.** Block on each child with `t3_thread_wait` or `task_status`. Do not trust the completion notification alone.
5. **Review.** Start a new `delegate_task` per review round on `gpt-6.1-sol` (medium, default tier) with the ticket, the diff (`git diff main...<branch>`), the implementer's evidence, and earlier findings. The review checks correctness, the acceptance criteria, Bend idioms, and, for every new law, whether it states the promised guarantee over every admissible input. Send verified findings back to the implementer as a new `delegate_task` on the same worktree, then review again.
6. **Verify.** In the worktree, run `bun run check` and the ticket's How to verify steps yourself. UI tickets also need agent-browser screenshots at 1440 and 390 widths. Post PASS, FAIL and NOT CHECKED lines as a Linear comment.
7. **Land.** Rebase the branch onto `main`, rerun `bun run check`, merge with a merge commit naming the issue key (for example `BND-12: Parse HTTP requests`), push `main`, and confirm CI is green. Move the issue to Done. No pull requests unless Leo asks for them.
8. **Report.** When a milestone finishes, post a short project update on Linear with what landed and any numbers.

## Rules

- **Laws.** Never delete or weaken a law to make a proof pass. A stuck proof goes to Needs Leo with a write-up.
- **Research gates.** 0.3, 0.4 and 0.6 decide the design. Read their decision docs before dispatching anything that depends on them. If a decision changes the plan, update `docs/PLAN.md` and the affected tickets in the same change.
- **Stuck work.** If an implementer makes no progress in two rounds, cancel it with `task_cancel`, reassess the ticket (split it, clarify it, or try the other model), and record what happened on the issue.
- **Shared server.** ms-a2 is shared. Keep tests bounded (`bun test --timeout 30000`, at most 4 workers). Run benchmarks, fuzzing, Autobahn and anything heavy on Boat sandboxes with `boat-sbx`, and delete every sandbox you create.
- **Things that wait for Leo.** Publishing to npm or BendHub, anything costing money, DNS, and any change to a law's meaning. Move the issue to Needs Leo with one clear question and keep working on other tickets.
- **Never stop with work in flight.** Before ending a turn, wait on running children. If the wait would pass 30 minutes, schedule a wake-up and say exactly what is pending.

## Resuming

State lives in Linear (issue status and comments), git (`main` plus the `leoplayz317/bnd-*` issue branches), and T3 (`t3_worktree_list`, `task_status`). To resume: list In Progress issues, check each one's worktree and child task, finish or restart them, then continue the loop.
