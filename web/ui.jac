"""Desk UI for Lane: plan the week, capture work, check it off."""

import from core.planner {
    snapshot,
    add_task,
    add_course,
    add_block,
    complete_task,
    cycle_task,
    delete_task,
    delete_course,
    delete_block,
    reset_planner,
    load_sample,
    TaskView,
    CourseView,
    BlockView,
    DayView
}

def:pub TaskCard(task: TaskView, on_done: any, on_cycle: any, on_delete: any) -> JsxElement {
    code = "Personal";
    if task.course_code != "" {
        code = task.course_code;
    }
    tone = "task";
    if task.status == "done" {
        tone = "task is-done";
    }
    <article className={tone} style={{"borderLeftColor": task.color}}>
        <div>
            <h3>{task.title}</h3>
            <p className="meta">
                {code} · {task.due_label} · {task.effort} · {task.priority}
            </p>
            {(<p className="notes">{task.notes}</p>) if task.notes != "" else None}
        </div>
        <div className="task-actions">
            <button type="button" className="btn btn-ghost" onClick={lambda { on_cycle(task.id); }}>
                {task.status}
            </button>
            {(<button type="button" className="btn btn-done" onClick={lambda { on_done(task.id); }}>Done</button>) if task.status != "done" else None}
            <button type="button" className="btn btn-ghost" onClick={lambda { on_delete(task.id); }}>
                Remove
            </button>
        </div>
    </article>
}

def:pub DayColumn(day: DayView, on_done: any) -> JsxElement {
    tone = "day";
    if day.is_today {
        tone = "day is-today";
    }
    <section className={tone}>
        <header>
            <h3>{day.label}</h3>
            <span>{day.date[5:]}</span>
        </header>
        {[
            <p key={block.id} className="block">
                <span className="swatch" style={{"background": block.color}}></span>
                {block.start} {block.title}
            </p>
            for block in day.blocks
        ]}
        {[
            <p key={task.id} className={"due " + task.status}>
                <span>{task.title}</span>
                {(<button type="button" onClick={lambda { on_done(task.id); }}>done</button>) if task.status != "done" else None}
            </p>
            for task in day.tasks
        ]}
        {(<p className="empty">Clear</p>) if len(day.blocks) == 0 and len(day.tasks) == 0 else None}
    </section>
}

def:pub CourseCard(course: CourseView, on_delete: any) -> JsxElement {
    <article className="course">
        <span className="swatch lg" style={{"background": course.color}}></span>
        <div>
            <h3>{course.code}</h3>
            <p>{course.title}</p>
            <p className="meta">{course.meetings}</p>
            <p className="meta">{course.open_tasks} open · {course.minutes_left}m left</p>
        </div>
        <button type="button" className="btn btn-ghost" onClick={lambda { on_delete(course.id); }}>
            Remove
        </button>
    </article>
}

def:pub BlockRow(block: BlockView, on_delete: any) -> JsxElement {
    code = "Personal";
    if block.course_code != "" {
        code = block.course_code;
    }
    <li className="block-row">
        <span className="swatch" style={{"background": block.color}}></span>
        <span>{block.day} {block.start}</span>
        <strong>{block.title}</strong>
        <span className="meta">{code} · {block.effort}</span>
        <button type="button" className="btn btn-ghost" onClick={lambda { on_delete(block.id); }}>
            Remove
        </button>
    </li>
}

def:pub Planner -> JsxElement {
    has tab: str = "today",
        loaded: bool = False,
        error: str = "",
        today_label: str = "",
        today_date: str = "",
        week_of: str = "",
        suggestion: str = "",
        open_count: int = 0,
        minutes_left: int = 0,
        overdue: list[TaskView] = [],
        due_today: list[TaskView] = [],
        focus: list[TaskView] = [],
        today_blocks: list[BlockView] = [],
        days: list[DayView] = [],
        courses: list[CourseView] = [],
        blocks: list[BlockView] = [],
        title: str = "",
        course: str = "",
        due: str = "",
        priority: str = "high",
        minutes: str = "60",
        notes: str = "",
        c_code: str = "",
        c_title: str = "",
        c_color: str = "#c24d1d",
        c_meet: str = "",
        b_title: str = "",
        b_course: str = "",
        b_day: str = "0",
        b_start: str = "19:00",
        b_minutes: str = "60";

    async can with entry {
        await reload();
    }

    async def reload {
        try {
            snap = await snapshot();
            today_label = snap.today.label;
            today_date = snap.today.date;
            suggestion = snap.today.suggestion;
            open_count = snap.today.open_count;
            minutes_left = snap.today.minutes_left;
            overdue = snap.today.overdue;
            due_today = snap.today.due_today;
            focus = snap.today.focus;
            today_blocks = snap.today.blocks;
            days = snap.days;
            courses = snap.courses;
            blocks = snap.blocks;
            if len(snap.days) > 0 {
                week_of = snap.days[0].label + " – " + snap.days[6].label;
            }
            if due == "" {
                due = snap.today.date;
            }
            loaded = True;
            error = "";
        } except Exception as err {
            error = str(err);
            loaded = True;
        }
    }

    async def mark_done(id: str) {
        made = await complete_task(id=id);
        if made.error != "" {
            error = made.error;
            return;
        }
        await reload();
    }

    async def mark_cycle(id: str) {
        made = await cycle_task(id=id);
        if made.error != "" {
            error = made.error;
            return;
        }
        await reload();
    }

    async def remove_task(id: str) {
        ok = await delete_task(id=id);
        if not ok {
            error = "Could not remove that task. It may match more than one id.";
            return;
        }
        await reload();
    }

    async def remove_course(id: str) {
        ok = await delete_course(id=id);
        if not ok {
            error = "Could not remove that course.";
            return;
        }
        await reload();
    }

    async def remove_block(id: str) {
        ok = await delete_block(id=id);
        if not ok {
            error = "Could not remove that study block.";
            return;
        }
        await reload();
    }

    async def submit_task(event: FormEvent) {
        event.preventDefault();
        if title.strip() == "" {
            error = "Give the task a title.";
            return;
        }
        amount = 45;
        if minutes.strip() != "" {
            amount = int(minutes);
        }
        made = await add_task(
            title=title,
            course=course,
            due=due,
            priority=priority,
            minutes=amount,
            notes=notes
        );
        if made.error != "" {
            error = made.error;
            return;
        }
        title = "";
        notes = "";
        await reload();
    }

    async def submit_course(event: FormEvent) {
        event.preventDefault();
        made = await add_course(
            code=c_code,
            title=c_title,
            color=c_color,
            meetings=c_meet
        );
        if made.error != "" {
            error = made.error;
            return;
        }
        c_code = "";
        c_title = "";
        c_meet = "";
        await reload();
    }

    async def submit_block(event: FormEvent) {
        event.preventDefault();
        amount = 60;
        if b_minutes.strip() != "" {
            amount = int(b_minutes);
        }
        made = await add_block(
            title=b_title,
            course=b_course,
            weekday=int(b_day),
            start=b_start,
            minutes=amount
        );
        if made.error != "" {
            error = made.error;
            return;
        }
        b_title = "";
        await reload();
    }

    async def do_reset {
        await reset_planner();
        due = "";
        await reload();
    }

    async def do_sample {
        await load_sample();
        due = "";
        await reload();
    }

    <div className="shell">
        <header className="top">
            <div className="brand">
                <p className="mark">Lane</p>
                <p className="kicker">Semester desk</p>
            </div>
            <nav>
                <button type="button" className={"tab on" if tab == "today" else "tab"} onClick={lambda { tab = "today"; }}>Today</button>
                <button type="button" className={"tab on" if tab == "week" else "tab"} onClick={lambda { tab = "week"; }}>Week</button>
                <button type="button" className={"tab on" if tab == "courses" else "tab"} onClick={lambda { tab = "courses"; }}>Courses</button>
            </nav>
            <p className="when">{today_label}</p>
        </header>
        <section className="stats">
            <p><strong>{open_count}</strong> open</p>
            <p><strong>{minutes_left}</strong> min left</p>
            <p><strong>{len(courses)}</strong> courses</p>
        </section>
        {(<p className="banner">{suggestion}</p>) if loaded and suggestion != "" else None}
        {(<p className="error">{error}</p>) if error != "" else None}
        {(<p className="loading">Opening your week...</p>) if not loaded else None}
        {(<div className="today">
            <div className="columns">
                <section>
                    <h2>Overdue</h2>
                    {(<p className="empty">Nothing slipped.</p>) if len(overdue) == 0 else None}
                    {[<TaskCard key={task.id} task={task} on_done={mark_done} on_cycle={mark_cycle} on_delete={remove_task}/> for task in overdue]}
                </section>
                <section>
                    <h2>Due today</h2>
                    {(<p className="empty">Nothing due today.</p>) if len(due_today) == 0 else None}
                    {[<TaskCard key={task.id} task={task} on_done={mark_done} on_cycle={mark_cycle} on_delete={remove_task}/> for task in due_today]}
                </section>
                <section>
                    <h2>Up next</h2>
                    {(<p className="empty">No later deadlines yet.</p>) if len(focus) == 0 else None}
                    {[<TaskCard key={task.id} task={task} on_done={mark_done} on_cycle={mark_cycle} on_delete={remove_task}/> for task in focus]}
                </section>
            </div>
            <aside className="side">
                <h2>Today's blocks</h2>
                {(<p className="empty">No study block on this weekday.</p>) if len(today_blocks) == 0 else None}
                {[
                    <p key={block.id} className="block">
                        <span className="swatch" style={{"background": block.color}}></span>
                        {block.start} {block.title}
                        <span className="meta"> {block.effort}</span>
                    </p>
                    for block in today_blocks
                ]}
                <h2>Add a task</h2>
                <form onSubmit={submit_task} className="stack">
                    <input value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} placeholder="What needs doing?"/>
                    <select value={course} onChange={lambda (e: ChangeEvent) { course = e.target.value; }}>
                        <option value="">Personal</option>
                        {[<option key={item.id} value={item.code}>{item.code}</option> for item in courses]}
                    </select>
                    <input type="date" value={due} onChange={lambda (e: ChangeEvent) { due = e.target.value; }}/>
                    <div className="split">
                        <select value={priority} onChange={lambda (e: ChangeEvent) { priority = e.target.value; }}>
                            <option value="urgent">Urgent</option>
                            <option value="high">High</option>
                            <option value="medium">Medium</option>
                            <option value="low">Low</option>
                        </select>
                        <input value={minutes} onChange={lambda (e: ChangeEvent) { minutes = e.target.value; }} placeholder="Minutes"/>
                    </div>
                    <input value={notes} onChange={lambda (e: ChangeEvent) { notes = e.target.value; }} placeholder="Note (optional)"/>
                    <button type="submit" className="btn btn-primary">Add to the lane</button>
                </form>
            </aside>
        </div>) if loaded and tab == "today" else None}
        {(<div className="week-wrap">
            <p className="kicker">Week of {week_of}</p>
            <div className="week">
                {[<DayColumn key={day.date} day={day} on_done={mark_done}/> for day in days]}
            </div>
            <div className="week-tools">
                <section>
                    <h2>Recurring blocks</h2>
                    <ul className="plain">
                        {[<BlockRow key={block.id} block={block} on_delete={remove_block}/> for block in blocks]}
                    </ul>
                    {(<p className="empty">No weekly blocks yet.</p>) if len(blocks) == 0 else None}
                </section>
                <form onSubmit={submit_block} className="stack">
                    <h2>Add a weekly block</h2>
                    <input value={b_title} onChange={lambda (e: ChangeEvent) { b_title = e.target.value; }} placeholder="Deep work, office hours, review"/>
                    <select value={b_course} onChange={lambda (e: ChangeEvent) { b_course = e.target.value; }}>
                        <option value="">Personal</option>
                        {[<option key={item.id} value={item.code}>{item.code}</option> for item in courses]}
                    </select>
                    <div className="split">
                        <select value={b_day} onChange={lambda (e: ChangeEvent) { b_day = e.target.value; }}>
                            <option value="0">Monday</option>
                            <option value="1">Tuesday</option>
                            <option value="2">Wednesday</option>
                            <option value="3">Thursday</option>
                            <option value="4">Friday</option>
                            <option value="5">Saturday</option>
                            <option value="6">Sunday</option>
                        </select>
                        <input value={b_start} onChange={lambda (e: ChangeEvent) { b_start = e.target.value; }} placeholder="19:00"/>
                    </div>
                    <input value={b_minutes} onChange={lambda (e: ChangeEvent) { b_minutes = e.target.value; }} placeholder="Minutes"/>
                    <button type="submit" className="btn btn-primary">Save block</button>
                </form>
            </div>
        </div>) if loaded and tab == "week" else None}
        {(<div className="course-wrap">
            <div className="course-list">
                {[<CourseCard key={item.id} course={item} on_delete={remove_course}/> for item in courses]}
                {(<p className="empty">No courses yet. Add the ones you are actually taking.</p>) if len(courses) == 0 else None}
            </div>
            <form onSubmit={submit_course} className="stack">
                <h2>Add a course</h2>
                <input value={c_code} onChange={lambda (e: ChangeEvent) { c_code = e.target.value; }} placeholder="EECS 449"/>
                <input value={c_title} onChange={lambda (e: ChangeEvent) { c_title = e.target.value; }} placeholder="Course title"/>
                <input value={c_meet} onChange={lambda (e: ChangeEvent) { c_meet = e.target.value; }} placeholder="Mon/Wed 10:30"/>
                <label className="color">
                    Color
                    <input type="color" value={c_color} onChange={lambda (e: ChangeEvent) { c_color = e.target.value; }}/>
                </label>
                <button type="submit" className="btn btn-primary">Add course</button>
            </form>
        </div>) if loaded and tab == "courses" else None}
        <footer>
            <button type="button" className="link" onClick={lambda { do_reset(); }}>Clear my lane</button>
            <button type="button" className="link" onClick={lambda { do_sample(); }}>Reload the sample week</button>
            <span>Same plan on the phone and from the terminal.</span>
        </footer>
    </div>
}
