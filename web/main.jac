"""Web entry. `jac run` serves this app and the colocated planner."""

import "./styles.css";
import from .ui { Planner }

def:pub app -> JsxElement {
    <Planner/>
}
