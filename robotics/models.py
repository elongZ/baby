from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class DetectionBox:
    label: str
    confidence: float
    x1: float
    y1: float
    x2: float
    y2: float
    center_x: float
    center_y: float
    box_width: float
    box_height: float

    @classmethod
    def from_dict(cls, payload: dict) -> "DetectionBox":
        box = payload.get("box") or []
        if len(box) != 4:
            raise ValueError(f"Detection box must contain 4 values, got: {box}")

        x1, y1, x2, y2 = [float(value) for value in box]
        width = float(payload.get("box_width", x2 - x1))
        height = float(payload.get("box_height", y2 - y1))
        center_x = float(payload.get("center_x", x1 + (width / 2.0)))
        center_y = float(payload.get("center_y", y1 + (height / 2.0)))
        return cls(
            label=str(payload["label"]),
            confidence=float(payload["confidence"]),
            x1=x1,
            y1=y1,
            x2=x2,
            y2=y2,
            center_x=center_x,
            center_y=center_y,
            box_width=width,
            box_height=height,
        )

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "confidence": self.confidence,
            "box": [self.x1, self.y1, self.x2, self.y2],
            "center_x": self.center_x,
            "center_y": self.center_y,
            "box_width": self.box_width,
            "box_height": self.box_height,
        }


@dataclass(frozen=True)
class PickPoint:
    x: float
    y: float
    method: str = "bbox_center"

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class RobotDecision:
    target_label: str
    confidence: float
    pick_point: PickPoint
    destination_bin: str
    planner: str
    route_rule: str
    selection_reason: str
    target_box: DetectionBox

    def to_dict(self) -> dict:
        return {
            "target_label": self.target_label,
            "confidence": self.confidence,
            "pick_point": self.pick_point.to_dict(),
            "destination_bin": self.destination_bin,
            "planner": self.planner,
            "route_rule": self.route_rule,
            "selection_reason": self.selection_reason,
            "target_box": self.target_box.to_dict(),
        }
