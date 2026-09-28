"""Phone UI for Lane: see today, check a task off, capture the next one."""

import from "@jac/mobui" {
    View, Text, Pressable, TextInput, ScrollView, StyleSheet
}
import from core.planner {
    snapshot,
    add_task,
    complete_task,
    TaskView,
    BlockView,
    CourseView
}

glob styles = StyleSheet.create({
    screen: {"flex": 1, "backgroundColor": "#1c1915"},
    body: {"padding": 20, "paddingBottom": 48, "gap": 14},
    mark: {"color": "#f3ecdf", "fontSize": 42, "fontWeight": "700"},
    date: {"color": "#b7ab9d", "fontSize": 14},
    banner: {
        "backgroundColor": "#c24d1d",
        "borderRadius": 14,
        "padding": 12
    },
    banner_text: {"color": "#fff7f2", "fontSize": 15, "lineHeight": 21},
    row: {"flexDirection": "row", "gap": 8},
    tab: {
        "paddingVertical": 8,
        "paddingHorizontal": 12,
        "borderRadius": 999,
        "backgroundColor": "#2a2520"
    },
    tab_on: {"backgroundColor": "#f3ecdf"},
    tab_label: {"color": "#f3ecdf", "fontSize": 14},
    tab_label_on: {"color": "#1c1915", "fontWeight": "700"},
    section: {"color": "#b7ab9d", "marginTop": 8, "fontSize": 13, "letterSpacing": 1},
    card: {
        "backgroundColor": "#2a2520",
        "borderRadius": 16,
        "padding": 12,
        "flexDirection": "row",
        "alignItems": "center",
        "gap": 10
    },
    card_body: {"flex": 1, "gap": 4},
    card_title: {"color": "#f3ecdf", "fontSize": 16, "fontWeight": "600"},
    card_meta: {"color": "#b7ab9d", "fontSize": 13},
    done: {
        "backgroundColor": "#215c45",
        "borderRadius": 999,
        "paddingVertical": 8,
        "paddingHorizontal": 12
    },
    done_label: {"color": "#f3ecdf", "fontWeight": "700"},
    input: {
        "backgroundColor": "#2a2520",
        "color": "#f3ecdf",
        "borderRadius": 12,
        "padding": 12,
        "fontSize": 16
    },
    save: {
        "backgroundColor": "#c24d1d",
        "borderRadius": 12,
        "padding": 14,
        "alignItems": "center"
    },
    save_label: {"color": "#fff7f2", "fontWeight": "700", "fontSize": 16},
    error: {"color": "#ffb4a8"}
});

def:pub MobileTask(task: TaskView, on_done: any) -> JsxElement {
    code = "Personal";
    if task.course_code != "" {
        code = task.course_code;
    }
    <View style={styles.card}>
        <View style={styles.card_body}>
            <Text style={styles.card_title}>{task.title}</Text>
            <Text style={styles.card_meta}>{code} · {task.due_label} · {task.effort}</Text>
        </View>
        <Pressable style={styles.done} onPress={lambda { on_done(task.id); }}>
            <Text style={styles.done_label}>Done</Text>
        </Pressable>
    </View>
}

def:pub app -> JsxElement {
    has screen: str = "today",
        loaded: bool = False,
        error: str = "",
        today_label: str = "",
        suggestion: str = "",
        overdue: list[TaskView] = [],
        due_today: list[TaskView] = [],
        focus: list[TaskView] = [],
        blocks: list[BlockView] = [],
        courses: list[CourseView] = [],
        title: str = "",
        course: str = "",
        due: str = "",
        minutes: str = "45";

    async can with entry {
        await reload();
    }

    async def reload {
        try {
            snap = await snapshot();
            today_label = snap.today.label;
            suggestion = snap.today.suggestion;
            overdue = snap.today.overdue;
            due_today = snap.today.due_today;
            focus = snap.today.focus;
            blocks = snap.today.blocks;
            courses = snap.courses;
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

    async def save_task {
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
            priority="high",
            minutes=amount,
            notes=""
        );
        if made.error != "" {
            error = made.error;
            return;
        }
        title = "";
        screen = "today";
        await reload();
    }

    <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
        <Text style={styles.mark}>Lane</Text>
        <Text style={styles.date}>{today_label if loaded else "Loading the plan..."}</Text>
        {(<View style={styles.banner}><Text style={styles.banner_text}>{suggestion}</Text></View>) if suggestion != "" else None}
        {(<Text style={styles.error}>{error}</Text>) if error != "" else None}
        <View style={styles.row}>
            <Pressable style={styles.tab_on if screen == "today" else styles.tab} onPress={lambda { screen = "today"; }}>
                <Text style={styles.tab_label_on if screen == "today" else styles.tab_label}>Today</Text>
            </Pressable>
            <Pressable style={styles.tab_on if screen == "add" else styles.tab} onPress={lambda { screen = "add"; }}>
                <Text style={styles.tab_label_on if screen == "add" else styles.tab_label}>Add</Text>
            </Pressable>
            <Pressable style={styles.tab_on if screen == "courses" else styles.tab} onPress={lambda { screen = "courses"; }}>
                <Text style={styles.tab_label_on if screen == "courses" else styles.tab_label}>Courses</Text>
            </Pressable>
        </View>
        {(<View style={{"gap": 10}}>
            <Text style={styles.section}>OVERDUE</Text>
            {(<Text style={styles.date}>Nothing slipped.</Text>) if len(overdue) == 0 else None}
            {[<MobileTask key={task.id} task={task} on_done={mark_done}/> for task in overdue]}
            <Text style={styles.section}>DUE TODAY</Text>
            {(<Text style={styles.date}>Nothing due today.</Text>) if len(due_today) == 0 else None}
            {[<MobileTask key={task.id} task={task} on_done={mark_done}/> for task in due_today]}
            <Text style={styles.section}>UP NEXT</Text>
            {[<MobileTask key={task.id} task={task} on_done={mark_done}/> for task in focus]}
            <Text style={styles.section}>BLOCKS</Text>
            {(<Text style={styles.date}>No study block on this weekday.</Text>) if len(blocks) == 0 else None}
            {[
                <Text key={block.id} style={styles.card_meta}>{block.start}  {block.title}  {block.effort}</Text>
                for block in blocks
            ]}
        </View>) if loaded and screen == "today" else None}
        {(<View style={{"gap": 10}}>
            <TextInput
                style={styles.input}
                value={title}
                placeholder="Task title"
                placeholderTextColor="#8d8276"
                onChangeText={lambda (text: str) { title = text; }}
            />
            <TextInput
                style={styles.input}
                value={course}
                placeholder="Course code, or leave blank"
                placeholderTextColor="#8d8276"
                onChangeText={lambda (text: str) { course = text; }}
            />
            <TextInput
                style={styles.input}
                value={due}
                placeholder="YYYY-MM-DD"
                placeholderTextColor="#8d8276"
                onChangeText={lambda (text: str) { due = text; }}
            />
            <TextInput
                style={styles.input}
                value={minutes}
                placeholder="Minutes"
                placeholderTextColor="#8d8276"
                onChangeText={lambda (text: str) { minutes = text; }}
            />
            <Pressable style={styles.save} onPress={lambda { save_task(); }}>
                <Text style={styles.save_label}>Add to the lane</Text>
            </Pressable>
        </View>) if screen == "add" else None}
        {(<View style={{"gap": 10}}>
            {[
                <View key={item.id} style={styles.card}>
                    <View style={styles.card_body}>
                        <Text style={styles.card_title}>{item.code}</Text>
                        <Text style={styles.card_meta}>{item.title}</Text>
                        <Text style={styles.card_meta}>{item.meetings} · {item.open_tasks} open</Text>
                    </View>
                </View>
                for item in courses
            ]}
        </View>) if loaded and screen == "courses" else None}
    </ScrollView>
}
