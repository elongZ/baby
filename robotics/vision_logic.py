from __future__ import annotations

import json
from pathlib import Path

from robotics.models import DetectionBox, PickPoint, RobotDecision


DEFAULT_ROUTE_RULE = "Class-based routing from detected label to destination bin"
DEFAULT_PLANNER = "Center-point pick with fixed bin routing"
DEFAULT_DESTINATION_BIN = "bin A"


def load_demo_config(config_path: str | Path = "robotics/configs/demo_config.json") -> dict:
    path = Path(config_path).expanduser().resolve()
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def select_target(detections: list[DetectionBox]) -> DetectionBox | None:
    if not detections:
        return None
    return max(detections, key=lambda item: (item.confidence, item.box_width * item.box_height))


def compute_pick_point(detection: DetectionBox) -> PickPoint:
    return PickPoint(x=detection.center_x, y=detection.center_y, method="bbox_center")


def resolve_destination_bin(
    label: str,
    route_map: dict[str, str],
    default_bin: str = DEFAULT_DESTINATION_BIN,
) -> str:
    return route_map.get(label, default_bin)


def build_route_map(config: dict) -> dict[str, str]:
    routes = config.get("routes", [])
    return {
        str(item["class_name"]): str(item["destination_bin"])
        for item in routes
        if "class_name" in item and "destination_bin" in item
    }


def build_robot_decision(
    detections: list[dict],
    config: dict | None = None,
) -> RobotDecision | None:
    runtime_config = config or {}
    detection_boxes = [DetectionBox.from_dict(item) for item in detections]
    target = select_target(detection_boxes)
    if target is None:
        return None

    route_map = build_route_map(runtime_config)
    planner = str(runtime_config.get("planner", DEFAULT_PLANNER))
    route_rule = str(runtime_config.get("route_rule_description", DEFAULT_ROUTE_RULE))
    default_bin = str(runtime_config.get("default_destination_bin", DEFAULT_DESTINATION_BIN))
    destination_bin = resolve_destination_bin(target.label, route_map, default_bin)
    pick_point = compute_pick_point(target)
    selection_reason = (
        f"Selected {target.label} because it has the highest confidence "
        f"({target.confidence:.3f}); using the bounding-box center as the pick point."
    )
    return RobotDecision(
        target_label=target.label,
        confidence=target.confidence,
        pick_point=pick_point,
        destination_bin=destination_bin,
        planner=planner,
        route_rule=route_rule,
        selection_reason=selection_reason,
        target_box=target,
    )


def build_robot_decision_payload(
    detections: list[dict],
    config_path: str | Path = "robotics/configs/demo_config.json",
) -> dict:
    config = load_demo_config(config_path)
    decision = build_robot_decision(detections=detections, config=config)
    if decision is None:
        return {
            "decision_ready": False,
            "pick_point": None,
            "destination_bin": str(config.get("default_destination_bin", DEFAULT_DESTINATION_BIN)),
            "planner": str(config.get("planner", DEFAULT_PLANNER)),
            "route_rule": str(config.get("route_rule_description", DEFAULT_ROUTE_RULE)),
            "selection_reason": "No detection available, so no robot target was selected.",
            "target": None,
        }

    return {
        "decision_ready": True,
        "pick_point": decision.pick_point.to_dict(),
        "destination_bin": decision.destination_bin,
        "planner": decision.planner,
        "route_rule": decision.route_rule,
        "selection_reason": decision.selection_reason,
        "target": decision.target_box.to_dict(),
        "decision": decision.to_dict(),
    }
