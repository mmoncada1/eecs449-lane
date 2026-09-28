"""Terminal face of Lane. Talks to the planner service the web server hosts."""

import argparse;
import asyncio;
import os;
import sys;
import from jaclang.server { sv_client }
import from jaclang.server.bridge {
    BridgeError,
    BridgeRejected,
    BridgeTimeout,
    BridgeUnavailable
}
import from core.planner {
    snapshot,
    add_task,
    add_course,
    add_block,
    complete_task,
    cycle_task,
    set_status,
    delete_task,
    delete_course,
    delete_block,
    reset_planner,
    load_sample,
    TaskView,
    BlockView,
    DayView
}

glob EXIT_OK: int = 0,
    EXIT_FAILURE: int = 1,
    EXIT_USAGE: int = 2,
    EXIT_UNAVAILABLE: int = 3;

obj Args {
    has command: str = "",
        title: str = "",
        course: str = "",
        due: str = "",
        priority: str = "medium",
        minutes: int = 45,
        notes: str = "",
        code: str = "",
        color: str = "",
        meetings: str = "",
        day: str = "mon",
        start: str = "18:00",
        ident: str = "",
        kind: str = "",
        status: str = "doing";
}

def warn(text: str) {
    print(text, file=sys.stderr);
}

def explain(err: BridgeError) -> int {
    where = err.app + "." + err.name;
    if isinstance(err, BridgeUnavailable) {
        warn("lane: " + where + " is not reachable (" + err.detail + ")");
        warn("hint: start the planner with `jac run`, then run this command again");
        return EXIT_UNAVAILABLE;
    }
    if isinstance(err, BridgeTimeout) {
        warn("lane: " + where + " timed out (" + err.detail + ")");
        return EXIT_FAILURE;
    }
    if isinstance(err, BridgeRejected) {
        warn("lane: " + where + " rejected the call (" + err.detail + ")");
        return EXIT_FAILURE;
    }
    warn("lane: " + where + " failed (" + err.detail + ")");
    return EXIT_FAILURE;
}

def short_id(ident: str) -> str {
    if len(ident) <= 8 {
        return ident;
    }
    return ident[:8];
}

def course_name(code: str) -> str {
    if code == "" {
        return "personal";
    }
    return code;
}

def print_task(task: TaskView) {
    print(
        "  " + short_id(task.id)
        + "  " + task.status
        + "  " + task.priority
        + "  " + task.due_label
        + "  " + task.effort
        + "  " + course_name(task.course_code)
        + "  " + task.title
    );
}

def print_group(label: str, tasks: list[TaskView]) {
    print(label);
    if len(tasks) == 0 {
        print("  none");
        return;
    }
    for task in tasks {
        print_task(task);
    }
    print("");
}

def weekday_index(token: str) -> int {
    name = token.strip().lower();
    names = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    full = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    for i in [0, 1, 2, 3, 4, 5, 6] {
        if name == names[i] or name == full[i] or name == str(i) {
            return i;
        }
    }
    return -1;
}

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="lane",
        description="Lane from the terminal. The web server has to be running."
    );
    commands = parser.add_subparsers(dest="command", required=True);
    commands.add_parser("today", help="today's suggestion, deadlines, and study blocks");
    commands.add_parser("week", help="Monday-Sunday deadlines and blocks");
    commands.add_parser("tasks", help="every task, open ones first");
    commands.add_parser("courses", help="courses and how much open work each has");
    commands.add_parser("blocks", help="weekly study blocks");
    added = commands.add_parser("add", help="add a task");
    added.add_argument("title");
    added.add_argument("--course", `default="");
    added.add_argument("--due", `default="", help="YYYY-MM-DD, default today");
    added.add_argument("--priority", `default="medium", help="urgent, high, medium, or low");
    added.add_argument("--minutes", type=int, `default=45);
    added.add_argument("--notes", `default="");
    done = commands.add_parser("done", help="mark a task complete; id can be a prefix");
    done.add_argument("ident");
    cycle = commands.add_parser("cycle", help="move a task todo -> doing -> done -> todo");
    cycle.add_argument("ident");
    status = commands.add_parser("status", help="set a task to todo, doing, or done");
    status.add_argument("ident");
    status.add_argument("status");
    course = commands.add_parser("course", help="add a course");
    course.add_argument("code");
    course.add_argument("title");
    course.add_argument("--color", `default="");
    course.add_argument("--meetings", `default="");
    block = commands.add_parser("block", help="add a weekly study block");
    block.add_argument("title");
    block.add_argument("--course", `default="");
    block.add_argument("--day", `default="mon", help="mon..sun or 0..6");
    block.add_argument("--start", `default="18:00");
    block.add_argument("--minutes", type=int, `default=60);
    drop = commands.add_parser("drop", help="delete a task, course, or block");
    drop.add_argument("kind", choices=["task", "course", "block"]);
    drop.add_argument("ident");
    commands.add_parser("reset", help="erase the plan");
    commands.add_parser("sample", help="replace the plan with the sample week");
    return parser;
}

def parse_args(argv: list[str]) -> Args {
    parser = build_parser();
    ns = parser.parse_args(argv);
    minutes = getattr(ns, "minutes", 45);
    if minutes is None {
        minutes = 45;
    }
    return Args(
        command=str(getattr(ns, "command", "") or ""),
        title=str(getattr(ns, "title", "") or ""),
        course=str(getattr(ns, "course", "") or ""),
        due=str(getattr(ns, "due", "") or ""),
        priority=str(getattr(ns, "priority", "") or "medium"),
        minutes=int(minutes),
        notes=str(getattr(ns, "notes", "") or ""),
        code=str(getattr(ns, "code", "") or ""),
        color=str(getattr(ns, "color", "") or ""),
        meetings=str(getattr(ns, "meetings", "") or ""),
        day=str(getattr(ns, "day", "") or "mon"),
        start=str(getattr(ns, "start", "") or "18:00"),
        ident=str(getattr(ns, "ident", "") or ""),
        kind=str(getattr(ns, "kind", "") or ""),
        status=str(getattr(ns, "status", "") or "")
    );
}

async def show_today -> int {
    snap = await snapshot();
    view = snap.today;
    print("Lane  |  " + view.label);
    print(view.suggestion);
    print("");
    print("Open " + str(view.open_count) + "  |  " + str(view.minutes_left) + "m left");
    print("");
    print_group("Overdue", view.overdue);
    print_group("Due today", view.due_today);
    print_group("Up next", view.focus);
    print("Study blocks");
    if len(view.blocks) == 0 {
        print("  none today");
    }
    for block in view.blocks {
        print(
            "  " + block.start
            + "  " + block.title
            + "  " + block.effort
            + "  " + course_name(block.course_code)
        );
    }
    return EXIT_OK;
}

async def show_week -> int {
    snap = await snapshot();
    print("Lane week");
    print("");
    for day in snap.days {
        mark = "";
        if day.is_today {
            mark = "  <- today";
        }
        print(day.label + "  " + day.date + mark);
        if len(day.blocks) == 0 and len(day.tasks) == 0 {
            print("  clear");
        }
        for block in day.blocks {
            print("  " + block.start + "  block  " + block.title);
        }
        for task in day.tasks {
            print_task(task);
        }
        print("");
    }
    return EXIT_OK;
}

async def show_tasks -> int {
    snap = await snapshot();
    if len(snap.tasks) == 0 {
        print("No tasks. Add one: jac run cli -- add \"Read chapter 3\" --course \"EECS 449\"");
        return EXIT_OK;
    }
    for task in snap.tasks {
        print_task(task);
    }
    return EXIT_OK;
}

async def show_courses -> int {
    snap = await snapshot();
    if len(snap.courses) == 0 {
        print("No courses.");
        return EXIT_OK;
    }
    for course in snap.courses {
        print(
            course.code
            + "  " + course.title
            + "  " + course.meetings
            + "  " + str(course.open_tasks) + " open"
            + "  " + str(course.minutes_left) + "m"
        );
    }
    return EXIT_OK;
}

async def show_blocks -> int {
    snap = await snapshot();
    if len(snap.blocks) == 0 {
        print("No study blocks.");
        return EXIT_OK;
    }
    for block in snap.blocks {
        print(
            short_id(block.id)
            + "  " + block.day
            + "  " + block.start
            + "  " + block.effort
            + "  " + course_name(block.course_code)
            + "  " + block.title
        );
    }
    return EXIT_OK;
}

async def run_add(args: Args) -> int {
    made = await add_task(
        title=args.title,
        course=args.course,
        due=args.due,
        priority=args.priority,
        minutes=args.minutes,
        notes=args.notes
    );
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print("added " + short_id(made.id) + "  " + made.title + "  " + made.due_label);
    return EXIT_OK;
}

async def run_done(args: Args) -> int {
    made = await complete_task(id=args.ident);
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print("done  " + made.title);
    return EXIT_OK;
}

async def run_cycle(args: Args) -> int {
    made = await cycle_task(id=args.ident);
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print(made.status + "  " + made.title);
    return EXIT_OK;
}

async def run_status(args: Args) -> int {
    made = await set_status(id=args.ident, status=args.status);
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print(made.status + "  " + made.title);
    return EXIT_OK;
}

async def run_course(args: Args) -> int {
    made = await add_course(
        code=args.code,
        title=args.title,
        color=args.color,
        meetings=args.meetings
    );
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print("course  " + made.code + "  " + made.title);
    return EXIT_OK;
}

async def run_block(args: Args) -> int {
    weekday = weekday_index(args.day);
    if weekday < 0 {
        warn("lane: day must be mon..sun or 0..6");
        return EXIT_USAGE;
    }
    made = await add_block(
        title=args.title,
        course=args.course,
        weekday=weekday,
        start=args.start,
        minutes=args.minutes
    );
    if made.error != "" {
        warn("lane: " + made.error);
        return EXIT_FAILURE;
    }
    print("block  " + short_id(made.id) + "  " + made.day + " " + made.start + "  " + made.title);
    return EXIT_OK;
}

async def run_drop(args: Args) -> int {
    ok = False;
    if args.kind == "task" {
        ok = await delete_task(id=args.ident);
    }
    if args.kind == "course" {
        ok = await delete_course(id=args.ident);
    }
    if args.kind == "block" {
        ok = await delete_block(id=args.ident);
    }
    if args.kind != "task" and args.kind != "course" and args.kind != "block" {
        ok = False;
    }
    if not ok {
        warn("lane: no single " + args.kind + " matches \"" + args.ident + "\"");
        return EXIT_FAILURE;
    }
    print("removed " + args.kind + " " + args.ident);
    return EXIT_OK;
}

def env_or(name: str, fallback: str) -> str {
    if name in os.environ {
        value = str(os.environ[name]);
        if value != "" {
            return value;
        }
    }
    return fallback;
}

def connect_planner {
    url = env_or("JAC_APP_PLANNER_URL", "http://127.0.0.1:8000");
    route = env_or("JAC_APP_PLANNER_ROUTE", "/api/planner");
    sv_client.register("planner", url, route=route);
}

async def dispatch(args: Args) -> int {
    connect_planner();
    try {
        if args.command == "today" {
            return await show_today();
        }
        if args.command == "week" {
            return await show_week();
        }
        if args.command == "tasks" {
            return await show_tasks();
        }
        if args.command == "courses" {
            return await show_courses();
        }
        if args.command == "blocks" {
            return await show_blocks();
        }
        if args.command == "add" {
            return await run_add(args);
        }
        if args.command == "done" {
            return await run_done(args);
        }
        if args.command == "cycle" {
            return await run_cycle(args);
        }
        if args.command == "status" {
            return await run_status(args);
        }
        if args.command == "course" {
            return await run_course(args);
        }
        if args.command == "block" {
            return await run_block(args);
        }
        if args.command == "drop" {
            return await run_drop(args);
        }
        if args.command == "reset" {
            await reset_planner();
            print("cleared");
            return EXIT_OK;
        }
        if args.command == "sample" {
            await load_sample();
            print("loaded the sample week");
            return EXIT_OK;
        }
        warn("lane: unknown command " + args.command);
        return EXIT_USAGE;
    } except BridgeError as err {
        return explain(err);
    }
}

async def main(argv: list[str]) -> int {
    return await dispatch(parse_args(argv));
}

with entry:__main__ {
    sys.exit(asyncio.run(main(sys.argv[1:])));
}
