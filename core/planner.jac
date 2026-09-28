"""Lane's planner service.

Courses, assignments, and weekly study blocks live on the shared graph.
`:pub` functions are the API the web app, the phone, and the CLI all call,
so every surface reads and writes the same plan.
"""

import from datetime { date, datetime, timedelta }

glob DAYS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    FULL_DAYS: list[str] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ],
    MONTHS: list[str] = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ],
    PALETTE: list[str] = [
        "#c24d1d", "#1f6f6a", "#2c4c8c", "#8a5a12", "#5c3d73", "#3d5a3d"
    ];

node PlannerMeta {
    has seeded: bool = True;
}

node Course {
    has code: str,
        title: str = "",
        color: str = "#c24d1d",
        meetings: str = "";
}

node Task {
    has title: str,
        course_id: str = "",
        due: str = "",
        priority: str = "medium",
        status: str = "todo",
        minutes: int = 30,
        notes: str = "";
}

node Block {
    has title: str,
        course_id: str = "",
        weekday: int = 0,
        start: str = "18:00",
        minutes: int = 60;
}

obj CourseView {
    has id: str = "",
        code: str = "",
        title: str = "",
        color: str = "#8a8175",
        meetings: str = "",
        open_tasks: int = 0,
        minutes_left: int = 0,
        error: str = "";
}

obj TaskView {
    has id: str = "",
        title: str = "",
        course_id: str = "",
        course_code: str = "",
        color: str = "#8a8175",
        due: str = "",
        due_label: str = "",
        priority: str = "medium",
        status: str = "todo",
        minutes: int = 0,
        effort: str = "",
        notes: str = "",
        score: int = 0,
        error: str = "";
}

obj BlockView {
    has id: str = "",
        title: str = "",
        course_id: str = "",
        course_code: str = "",
        color: str = "#8a8175",
        weekday: int = 0,
        day: str = "",
        start: str = "",
        minutes: int = 0,
        effort: str = "",
        error: str = "";
}

obj DayView {
    has date: str = "",
        label: str = "",
        weekday: int = 0,
        is_today: bool = False,
        tasks: list[TaskView] = [],
        blocks: list[BlockView] = [];
}

obj TodayView {
    has date: str = "",
        label: str = "",
        suggestion: str = "",
        overdue: list[TaskView] = [],
        due_today: list[TaskView] = [],
        focus: list[TaskView] = [],
        blocks: list[BlockView] = [],
        open_count: int = 0,
        minutes_left: int = 0;
}

obj Snapshot {
    has today: TodayView = TodayView(),
        days: list[DayView] = [],
        courses: list[CourseView] = [],
        tasks: list[TaskView] = [],
        blocks: list[BlockView] = [];
}

def:priv parse_day(text: str) -> date {
    return datetime.strptime(text.strip(), "%Y-%m-%d").date();
}

def:priv iso_in(days: int) -> str {
    day = date.today() + timedelta(days=days);
    return day.isoformat();
}

def:priv monday_of(day: date) -> date {
    return day - timedelta(days=day.weekday());
}

def:priv pretty_date(day: date) -> str {
    return FULL_DAYS[day.weekday()] + ", " + MONTHS[day.month - 1] + " " + str(day.day);
}

def:priv days_until(due: str) -> int {
    try {
        return (parse_day(due) - date.today()).days;
    } except Exception {
        return 0;
    }
}

def:priv due_label(due: str) -> str {
    days = days_until(due);
    if days < -1 {
        return str(-days) + "d late";
    }
    if days == -1 {
        return "1d late";
    }
    if days == 0 {
        return "today";
    }
    if days == 1 {
        return "tomorrow";
    }
    if days < 7 {
        return "in " + str(days) + "d";
    }
    return due;
}

def:priv effort(minutes: int) -> str {
    if minutes < 60 {
        return str(minutes) + "m";
    }
    hours = minutes // 60;
    rest = minutes % 60;
    if rest == 0 {
        return str(hours) + "h";
    }
    return str(hours) + "h " + str(rest) + "m";
}

def:priv priority_weight(priority: str) -> int {
    if priority == "urgent" {
        return 40;
    }
    if priority == "high" {
        return 28;
    }
    if priority == "low" {
        return 8;
    }
    return 16;
}

def:priv urgency(due: str, priority: str, status: str) -> int {
    if status == "done" {
        return 0;
    }
    base = priority_weight(priority);
    days = days_until(due);
    if days < 0 {
        late = -days;
        if late > 10 {
            late = 10;
        }
        return base + 50 + late * 3;
    }
    if days == 0 {
        return base + 36;
    }
    fade = 24 - days * 3;
    if fade < 0 {
        fade = 0;
    }
    return base + fade;
}

def:priv clean_due(text: str) -> str {
    raw = text.strip();
    if raw == "" {
        return date.today().isoformat();
    }
    try {
        return parse_day(raw).isoformat();
    } except Exception {
        return date.today().isoformat();
    }
}

def:priv clean_priority(text: str) -> str {
    name = text.strip().lower();
    if name == "urgent" or name == "high" or name == "medium" or name == "low" {
        return name;
    }
    return "medium";
}

def:priv clean_status(text: str) -> str {
    name = text.strip().lower();
    if name == "todo" or name == "doing" or name == "done" {
        return name;
    }
    return "todo";
}

def:priv clean_minutes(value: int) -> int {
    if value < 5 {
        return 5;
    }
    if value > 480 {
        return 480;
    }
    return value;
}

def:priv clean_weekday(value: int) -> int {
    if value < 0 or value > 6 {
        return 0;
    }
    return value;
}

def:priv clean_start(text: str) -> str {
    parts = text.strip().split(":");
    if len(parts) != 2 {
        return "18:00";
    }
    hour = parts[0];
    minute = parts[1];
    if len(hour) == 1 {
        hour = "0" + hour;
    }
    if len(minute) == 1 {
        minute = "0" + minute;
    }
    if len(hour) != 2 or len(minute) != 2 {
        return "18:00";
    }
    return hour + ":" + minute;
}

def:priv clean_color(text: str, index: int) -> str {
    raw = text.strip();
    if len(raw) == 7 and raw[0] == "#" {
        return raw.lower();
    }
    return PALETTE[index % len(PALETTE)];
}

def:priv next_status(current: str) -> str {
    if current == "todo" {
        return "doing";
    }
    if current == "doing" {
        return "done";
    }
    return "todo";
}

def:priv by_due(task: TaskView) -> str {
    return task.due;
}

def:priv by_score(task: TaskView) -> int {
    return -task.score;
}

def:priv by_open(task: TaskView) -> int {
    if task.status == "done" {
        return 1;
    }
    return 0;
}

def:priv by_start(block: BlockView) -> str {
    return block.start;
}

def:priv by_code(course: Course) -> str {
    return course.code;
}

def:priv all_courses -> list[Course] {
    found = [c for c in [root-->][?:Course]];
    found.sort(key=by_code);
    return found;
}

def:priv course_index -> dict[str, Course] {
    found: dict[str, Course] = {};
    for course in [root-->][?:Course] {
        found[jid(course)] = course;
    }
    return found;
}

def:priv view_course(course: Course) -> CourseView {
    cid = jid(course);
    open_count = 0;
    minutes = 0;
    for task in [root-->][?:Task] {
        if task.course_id == cid and task.status != "done" {
            open_count = open_count + 1;
            minutes = minutes + task.minutes;
        }
    }
    return CourseView(
        id=cid,
        code=course.code,
        title=course.title,
        color=course.color,
        meetings=course.meetings,
        open_tasks=open_count,
        minutes_left=minutes
    );
}

def:priv view_task(task: Task, courses: dict[str, Course]) -> TaskView {
    code = "";
    color = "#8a8175";
    if task.course_id in courses {
        course = courses[task.course_id];
        code = course.code;
        color = course.color;
    }
    return TaskView(
        id=jid(task),
        title=task.title,
        course_id=task.course_id,
        course_code=code,
        color=color,
        due=task.due,
        due_label=due_label(task.due),
        priority=task.priority,
        status=task.status,
        minutes=task.minutes,
        effort=effort(task.minutes),
        notes=task.notes,
        score=urgency(task.due, task.priority, task.status)
    );
}

def:priv view_block(block: Block, courses: dict[str, Course]) -> BlockView {
    code = "";
    color = "#8a8175";
    if block.course_id in courses {
        course = courses[block.course_id];
        code = course.code;
        color = course.color;
    }
    day_name = DAYS[0];
    if block.weekday >= 0 and block.weekday < 7 {
        day_name = DAYS[block.weekday];
    }
    return BlockView(
        id=jid(block),
        title=block.title,
        course_id=block.course_id,
        course_code=code,
        color=color,
        weekday=block.weekday,
        day=day_name,
        start=block.start,
        minutes=block.minutes,
        effort=effort(block.minutes)
    );
}

def:priv sort_by_score(tasks: list[TaskView]) -> list[TaskView] {
    ranked = [t for t in tasks];
    ranked.sort(key=by_due);
    ranked.sort(key=by_score);
    return ranked;
}

def:priv sort_tasks(tasks: list[TaskView]) -> list[TaskView] {
    ranked = sort_by_score(tasks);
    ranked.sort(key=by_open);
    return ranked;
}

def:priv make_suggestion(
    overdue: list[TaskView],
    due_today: list[TaskView],
    focus: list[TaskView],
    blocks: list[BlockView]
) -> str {
    top = TaskView();
    if len(overdue) > 0 {
        top = overdue[0];
        line = "Clear " + top.title + " first. It is " + top.due_label + ".";
    } elif len(due_today) > 0 {
        top = due_today[0];
        line = "Start " + top.title + " (" + top.effort + ", due today).";
    } elif len(focus) > 0 {
        top = focus[0];
        line = "Start " + top.title + " (" + top.effort + ", " + top.due_label + ").";
    } else {
        line = "Nothing is waiting. The lane is clear.";
    }
    if len(blocks) > 0 {
        block = blocks[0];
        line = line + " Next block: " + block.title + " at " + block.start + ".";
    }
    return line;
}

def:priv build_today(tasks: list[TaskView], blocks: list[BlockView]) -> TodayView {
    today = date.today();
    today_iso = today.isoformat();
    weekday = today.weekday();
    open_tasks = [t for t in tasks if t.status != "done"];
    overdue = sort_by_score([t for t in open_tasks if t.due < today_iso]);
    due_now = sort_by_score([t for t in open_tasks if t.due == today_iso]);
    upcoming = sort_by_score([t for t in open_tasks if t.due > today_iso]);
    focus = upcoming[:5];
    today_blocks = [b for b in blocks if b.weekday == weekday];
    minutes = 0;
    for task in open_tasks {
        minutes = minutes + task.minutes;
    }
    return TodayView(
        date=today_iso,
        label=pretty_date(today),
        suggestion=make_suggestion(overdue, due_now, focus, today_blocks),
        overdue=overdue,
        due_today=due_now,
        focus=focus,
        blocks=today_blocks,
        open_count=len(open_tasks),
        minutes_left=minutes
    );
}

def:priv build_days(tasks: list[TaskView], blocks: list[BlockView]) -> list[DayView] {
    start = monday_of(date.today());
    today_iso = date.today().isoformat();
    days: list[DayView] = [];
    for offset in [0, 1, 2, 3, 4, 5, 6] {
        day = start + timedelta(days=offset);
        iso = day.isoformat();
        weekday = day.weekday();
        day_tasks = [t for t in tasks if t.due == iso];
        day_blocks = [b for b in blocks if b.weekday == weekday];
        day_blocks.sort(key=by_start);
        days.append(DayView(
            date=iso,
            label=DAYS[weekday] + " " + str(day.day),
            weekday=weekday,
            is_today=iso == today_iso,
            tasks=day_tasks,
            blocks=day_blocks
        ));
    }
    return days;
}

def:priv build_snapshot -> Snapshot {
    courses = course_index();
    course_nodes = all_courses();
    task_views = [view_task(t, courses) for t in [root-->][?:Task]];
    block_views = [view_block(b, courses) for b in [root-->][?:Block]];
    block_views.sort(key=by_start);
    course_views = [view_course(c) for c in course_nodes];
    ranked = sort_tasks(task_views);
    return Snapshot(
        today=build_today(ranked, block_views),
        days=build_days(task_views, block_views),
        courses=course_views,
        tasks=ranked,
        blocks=block_views
    );
}

def:priv wipe {
    for node in [t for t in [root-->][?:Task]] {
        del node;
    }
    for node in [b for b in [root-->][?:Block]] {
        del node;
    }
    for node in [c for c in [root-->][?:Course]] {
        del node;
    }
    for node in [m for m in [root-->][?:PlannerMeta]] {
        del node;
    }
}

def:priv ensure {
    if len([root-->][?:PlannerMeta]) > 0 {
        return;
    }
    root ++> PlannerMeta();
    languages = root ++> Course(
        code="EECS 449",
        title="Programming Languages",
        color="#c24d1d",
        meetings="Mon/Wed 10:30"
    );
    theory = root ++> Course(
        code="EECS 376",
        title="Foundations of Computer Science",
        color="#1f6f6a",
        meetings="Tue/Thu 13:00"
    );
    learning = root ++> Course(
        code="EECS 445",
        title="Introduction to Machine Learning",
        color="#2c4c8c",
        meetings="Mon/Wed/Fri 15:00"
    );
    root ++> Task(
        title="Ship the Lane planner",
        course_id=jid(languages),
        due=iso_in(7),
        priority="high",
        status="doing",
        minutes=180,
        notes="Web, phone, and terminal share one graph."
    );
    root ++> Task(
        title="Problem set 4",
        course_id=jid(theory),
        due=iso_in(2),
        priority="urgent",
        status="todo",
        minutes=90,
        notes="Start with the induction question."
    );
    root ++> Task(
        title="Reading response",
        course_id=jid(learning),
        due=iso_in(0),
        priority="medium",
        status="todo",
        minutes=40,
        notes=""
    );
    root ++> Task(
        title="Lab report draft",
        course_id=jid(learning),
        due=iso_in(-1),
        priority="high",
        status="todo",
        minutes=75,
        notes="Already slipped. Lane should put this first."
    );
    root ++> Task(
        title="Plan next week",
        course_id="",
        due=iso_in(5),
        priority="low",
        status="todo",
        minutes=25,
        notes="Personal, not tied to a course."
    );
    root ++> Task(
        title="Lecture notes",
        course_id=jid(languages),
        due=iso_in(-1),
        priority="medium",
        status="done",
        minutes=30,
        notes=""
    );
    root ++> Block(
        title="449 deep work",
        course_id=jid(languages),
        weekday=0,
        start="19:00",
        minutes=90
    );
    root ++> Block(
        title="376 problem set",
        course_id=jid(theory),
        weekday=1,
        start="16:00",
        minutes=60
    );
    root ++> Block(
        title="445 practice",
        course_id=jid(learning),
        weekday=2,
        start="18:30",
        minutes=75
    );
    root ++> Block(
        title="Weekly review",
        course_id="",
        weekday=6,
        start="11:00",
        minutes=40
    );
}

def:priv matching_courses(token: str) -> list[Course] {
    needle = token.strip().lower();
    exact: list[Course] = [];
    prefix: list[Course] = [];
    if needle == "" {
        return [];
    }
    for course in [root-->][?:Course] {
        ident = jid(course).lower();
        code = course.code.lower();
        if ident == needle or code == needle {
            exact.append(course);
        } elif ident.startswith(needle) or code.startswith(needle) {
            prefix.append(course);
        }
    }
    if len(exact) > 0 {
        return exact;
    }
    return prefix;
}

def:priv matching_tasks(token: str) -> list[Task] {
    needle = token.strip().lower();
    exact: list[Task] = [];
    prefix: list[Task] = [];
    if needle == "" {
        return [];
    }
    for task in [root-->][?:Task] {
        ident = jid(task).lower();
        if ident == needle {
            exact.append(task);
        } elif ident.startswith(needle) {
            prefix.append(task);
        }
    }
    if len(exact) > 0 {
        return exact;
    }
    return prefix;
}

def:priv matching_blocks(token: str) -> list[Block] {
    needle = token.strip().lower();
    exact: list[Block] = [];
    prefix: list[Block] = [];
    if needle == "" {
        return [];
    }
    for block in [root-->][?:Block] {
        ident = jid(block).lower();
        if ident == needle {
            exact.append(block);
        } elif ident.startswith(needle) {
            prefix.append(block);
        }
    }
    if len(exact) > 0 {
        return exact;
    }
    return prefix;
}

def:priv resolve_course(token: str) -> Course | None {
    hits = matching_courses(token);
    if len(hits) == 1 {
        return hits[0];
    }
    return None;
}

"""The whole plan: today, the week, courses, tasks, and study blocks."""
def:pub snapshot -> Snapshot {
    ensure();
    return build_snapshot();
}

"""Add a course. `color` is a #rrggbb hex; leave it blank to take the next palette color."""
def:pub add_course(code: str, title: str, color: str, meetings: str) -> CourseView {
    ensure();
    cleaned = code.strip();
    if cleaned == "" {
        return CourseView(error="A course needs a code, like EECS 449.");
    }
    for course in [root-->][?:Course] {
        if course.code.lower() == cleaned.lower() {
            return CourseView(error="You already have " + course.code + ".");
        }
    }
    count = len([root-->][?:Course]);
    made = root ++> Course(
        code=cleaned,
        title=title.strip(),
        color=clean_color(color, count),
        meetings=meetings.strip()
    );
    return view_course(made);
}

"""Delete one course. Open tasks stay, unassigned. Study blocks for it go away."""
def:pub delete_course(id: str) -> bool {
    ensure();
    hits = matching_courses(id);
    if len(hits) != 1 {
        return False;
    }
    course = hits[0];
    cid = jid(course);
    for task in [t for t in [root-->][?:Task]] {
        if task.course_id == cid {
            task.course_id = "";
        }
    }
    for block in [b for b in [root-->][?:Block]] {
        if block.course_id == cid {
            del block;
        }
    }
    del course;
    return True;
}

"""Add an assignment or personal task. `course` is a code or id; blank means personal."""
def:pub add_task(
    title: str,
    course: str,
    due: str,
    priority: str,
    minutes: int,
    notes: str
) -> TaskView {
    ensure();
    name = title.strip();
    if name == "" {
        return TaskView(error="A task needs a title.");
    }
    course_id = "";
    if course.strip() != "" {
        found = resolve_course(course);
        if found is None {
            return TaskView(error="No single course matches \"" + course + "\". Try `lane courses`.");
        }
        course_id = jid(found);
    }
    made = root ++> Task(
        title=name,
        course_id=course_id,
        due=clean_due(due),
        priority=clean_priority(priority),
        status="todo",
        minutes=clean_minutes(minutes),
        notes=notes.strip()
    );
    return view_task(made, course_index());
}

"""Mark a task done. `id` can be a prefix of the task id."""
def:pub complete_task(id: str) -> TaskView {
    ensure();
    hits = matching_tasks(id);
    if len(hits) == 0 {
        return TaskView(error="No task matches \"" + id + "\".");
    }
    if len(hits) > 1 {
        return TaskView(error="That id matches " + str(len(hits)) + " tasks. Pass a longer id.");
    }
    task = hits[0];
    task.status = "done";
    return view_task(task, course_index());
}

"""Move a task todo -> doing -> done -> todo."""
def:pub cycle_task(id: str) -> TaskView {
    ensure();
    hits = matching_tasks(id);
    if len(hits) == 0 {
        return TaskView(error="No task matches \"" + id + "\".");
    }
    if len(hits) > 1 {
        return TaskView(error="That id matches " + str(len(hits)) + " tasks. Pass a longer id.");
    }
    task = hits[0];
    task.status = next_status(task.status);
    return view_task(task, course_index());
}

"""Set a task to todo, doing, or done."""
def:pub set_status(id: str, status: str) -> TaskView {
    ensure();
    hits = matching_tasks(id);
    if len(hits) != 1 {
        return TaskView(error="No single task matches \"" + id + "\".");
    }
    task = hits[0];
    task.status = clean_status(status);
    return view_task(task, course_index());
}

"""Delete one task."""
def:pub delete_task(id: str) -> bool {
    ensure();
    hits = matching_tasks(id);
    if len(hits) != 1 {
        return False;
    }
    del hits[0];
    return True;
}

"""Add a weekly study block. `weekday` is 0 (Monday) through 6 (Sunday)."""
def:pub add_block(
    title: str,
    course: str,
    weekday: int,
    start: str,
    minutes: int
) -> BlockView {
    ensure();
    name = title.strip();
    if name == "" {
        return BlockView(error="A study block needs a title.");
    }
    course_id = "";
    if course.strip() != "" {
        found = resolve_course(course);
        if found is None {
            return BlockView(error="No single course matches \"" + course + "\".");
        }
        course_id = jid(found);
    }
    made = root ++> Block(
        title=name,
        course_id=course_id,
        weekday=clean_weekday(weekday),
        start=clean_start(start),
        minutes=clean_minutes(minutes)
    );
    return view_block(made, course_index());
}

"""Delete one study block."""
def:pub delete_block(id: str) -> bool {
    ensure();
    hits = matching_blocks(id);
    if len(hits) != 1 {
        return False;
    }
    del hits[0];
    return True;
}

"""Erase the plan and leave it empty."""
def:pub reset_planner -> bool {
    wipe();
    root ++> PlannerMeta();
    return True;
}

"""Erase the plan and load the sample semester week again."""
def:pub load_sample -> bool {
    wipe();
    ensure();
    return True;
}
