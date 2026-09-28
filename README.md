# Lane

**Name:** Miguel Moncada-Larrotiz
**UMID:** REPLACE_WITH_YOUR_UMID

Lane is a personal semester planner. It keeps courses, assignment deadlines, and weekly study blocks in one saved plan, then tells you what to do next. The desk (web), the phone, and the terminal all read and write that same plan.

The first time you open it, Lane loads a sample week relative to today: one overdue assignment, something due today, later deadlines, a finished task, and a study block on a few weekdays. Clear it or replace it whenever you want your own term.

## What it does

- Ranks open work. Overdue items come first, then what is due today, then the next few deadlines. A one-line suggestion names the task to start and the next study block.
- Lets you add courses, tasks, and recurring study blocks, mark work done, and move a task through todo, doing, and done.
- Saves the plan in the project graph, so it is still there after a restart.

## Prerequisites

- [Jac](https://jaclang.org/docs/latest) 0.37.23 (`jac --version`). This project is pinned to that compiler.
- A browser.
- The phone preview uses the browser. A native iOS or Android build needs Xcode or the Android SDK, documented below.

## Run the desk and the server

From the repository root:

```bash
jac install
jac run
```

The first launch downloads an embedded Postgres and installs the client packages. After that, the app is at [http://localhost:8000](http://localhost:8000).

Use **Today** to check work off and add a task, **Week** to see the Monday–Sunday grid and study blocks, and **Courses** to add a class. **Clear my lane** empties the plan. **Reload the sample week** puts the starter week back.

The planner API is also listed at [http://localhost:8000/docs](http://localhost:8000/docs). The saved graph is at [http://localhost:8000/graph](http://localhost:8000/graph).

## CLI

Leave `jac run` going, then in another terminal:

```bash
jac run cli -- today
jac run cli -- week
jac run cli -- tasks
jac run cli -- courses
jac run cli -- blocks
jac run cli -- add "Read chapter 4" --course "EECS 449" --due 2026-10-03 --priority high --minutes 50
jac run cli -- done 2c3200b7
jac run cli -- cycle 2c3200b7
jac run cli -- status 2c3200b7 doing
jac run cli -- course "EECS 481" "Software Engineering" --meetings "Tue/Thu 12:00"
jac run cli -- block "Review notes" --course "EECS 449" --day mon --start 19:00 --minutes 90
jac run cli -- drop task 2c3200b7
jac run cli -- reset
jac run cli -- sample
```

`done`, `cycle`, `status`, and `drop` accept a prefix of the id printed by `tasks` or `blocks`. `--due` defaults to today. `--priority` is `urgent`, `high`, `medium`, or `low`. `--day` is `mon` through `sun`.

The CLI talks to the server from `jac run` on port 8000. If you start that server with `--port`, point the CLI at it:

```bash
JAC_APP_PLANNER_URL=http://127.0.0.1:3000 jac run cli -- today
```

## Mobile

In a second terminal, with or without the desk already running:

```bash
jac run --dev --platform web mobile
```

Open the URL it prints (usually [http://localhost:8002](http://localhost:8002)). **Today** is the check-off list, **Add** captures a task, and **Courses** shows what you are taking. That preview is the real phone UI, rendered with React Native Web. It uses the same saved plan as the desk and the CLI.

A device or simulator:

```bash
jac run --dev mobile
```

The first run scaffolds an Expo project under `.jac/`. Press `i` for the iOS simulator (Xcode) or `a` for Android. A phone on your network has to be able to reach the machine running Lane.

## How the four pieces fit

```text
web/      desk UI          kind web-app     jac run
mobile/   phone UI         kind mobile      jac run --dev --platform web mobile
cli/      terminal         kind cli         jac run cli -- today
core/     planner service  kind service     colocated when you jac run
```

`core/planner.jac` owns the courses, tasks, and study blocks and exposes them as public functions (`snapshot`, `add_task`, `complete_task`, and the rest). The desk, the phone, and the CLI call those functions. They do not keep separate copies of the plan. A task you add in the terminal shows up on the desk and on the phone, and marking it done in one place updates the others.

Bare `jac run` serves the web app because `[project] default-app` is `web`. The planner service is colocated in that process. The CLI registers itself against `http://127.0.0.1:8000/api/planner`. The phone preview starts its own API process and uses the same project database.

## What makes it useful

Lane is the plan I would actually open on a weekday. The desk is for laying out the week. The phone is for the minute between classes: see the suggestion, tap done, add the thing you just remembered. The terminal is for when you are already in a shell. The ranking is deterministic (priority, how late it is, and how soon it is due), so the suggestion does not depend on an API key. The sample week is generated from today's date, so the overdue item, the task due today, and today's study block are visible the first time someone runs it.
