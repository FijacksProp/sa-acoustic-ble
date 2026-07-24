from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "assets" / "report"
FONT_REGULAR = Path(r"C:\Windows\Fonts\times.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\timesbd.ttf")

INK = "#17212B"
MUTED = "#52606D"
NAVY = "#123B5D"
BLUE = "#246B9E"
TEAL = "#0D7A6C"
GREEN = "#237A4B"
RED = "#A33A3A"
AMBER = "#9B6811"
PAPER = "#FFFFFF"
PANEL = "#F4F7F9"
PALE_BLUE = "#E8F1F7"
PALE_TEAL = "#E4F3F0"
PALE_GREEN = "#E9F4EC"
PALE_AMBER = "#FAF1DE"
PALE_RED = "#F8EAEA"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REGULAR
    return ImageFont.truetype(str(path), size=size)


def wrapped_lines(
    draw: ImageDraw.ImageDraw,
    text: str,
    face: ImageFont.FreeTypeFont,
    width: int,
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textbbox((0, 0), candidate, font=face)[2] <= width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = word
    if current:
        lines.append(current)
    return lines


def text_center(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
    face: ImageFont.FreeTypeFont,
    fill: str = INK,
    spacing: int = 6,
) -> None:
    x1, y1, x2, y2 = box
    lines = wrapped_lines(draw, text, face, x2 - x1 - 28)
    heights = [
        draw.textbbox((0, 0), line, font=face)[3]
        - draw.textbbox((0, 0), line, font=face)[1]
        for line in lines
    ]
    total = sum(heights) + spacing * max(0, len(lines) - 1)
    y = y1 + ((y2 - y1) - total) / 2
    for line, height in zip(lines, heights):
        bounds = draw.textbbox((0, 0), line, font=face)
        text_width = bounds[2] - bounds[0]
        draw.text((x1 + ((x2 - x1) - text_width) / 2, y), line, font=face, fill=fill)
        y += height + spacing


def rounded_box(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    title: str,
    body: str = "",
    *,
    fill: str = PANEL,
    outline: str = NAVY,
    radius: int = 20,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=4)
    x1, y1, x2, y2 = box
    if body:
        draw.line((x1 + 18, y1 + 48, x2 - 18, y1 + 48), fill=outline, width=2)
        text_center(draw, (x1 + 8, y1 + 5, x2 - 8, y1 + 46), title, font(25, True), outline)
        text_center(draw, (x1 + 10, y1 + 52, x2 - 10, y2 - 8), body, font(20), INK)
    else:
        text_center(draw, box, title, font(22, True), outline)


def arrow(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    *,
    fill: str = NAVY,
    width: int = 5,
) -> None:
    draw.line((start, end), fill=fill, width=width)
    x1, y1 = start
    x2, y2 = end
    length = max(((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5, 1)
    ux = (x2 - x1) / length
    uy = (y2 - y1) / length
    px = -uy
    py = ux
    head = 15
    spread = 8
    points = [
        (x2, y2),
        (x2 - ux * head + px * spread, y2 - uy * head + py * spread),
        (x2 - ux * head - px * spread, y2 - uy * head - py * spread),
    ]
    draw.polygon(points, fill=fill)


def title(draw: ImageDraw.ImageDraw, text: str, subtitle: str = "") -> None:
    draw.text((70, 34), text, font=font(38, True), fill=INK)
    if subtitle:
        draw.text((70, 82), subtitle, font=font(21), fill=MUTED)
    draw.line((70, 120, 1730, 120), fill=BLUE, width=4)


def save(image: Image.Image, name: str) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT / name, dpi=(220, 220), optimize=True)


def architecture() -> None:
    image = Image.new("RGB", (1800, 1120), PAPER)
    draw = ImageDraw.Draw(image)
    title(
        draw,
        "Implemented System Architecture",
        "Physical signal capture is separated from server-side attendance acceptance.",
    )

    rounded_box(
        draw,
        (70, 175, 440, 435),
        "Lecturer Android App",
        "Authenticate\nCreate session and select room\nOpen or close attendance\nView reports and export CSV",
        fill=PALE_TEAL,
        outline=TEAL,
    )
    rounded_box(
        draw,
        (70, 500, 440, 805),
        "Broadcast Service",
        "Android foreground service\nPersistent notification and wake lock\nRotate every 45 seconds\nAcoustic token and lecturer BLE nonce",
        fill=PALE_BLUE,
        outline=BLUE,
    )

    rounded_box(
        draw,
        (540, 190, 850, 375),
        "Acoustic Channel",
        "17.8-19.4 kHz frame\nSpeaker to microphone\n60-second token lifetime",
        fill=PALE_AMBER,
        outline=AMBER,
    )
    rounded_box(
        draw,
        (540, 440, 850, 625),
        "Lecturer BLE",
        "Service-data advertisement\nShort-lived session nonce\nNo pairing required",
        fill=PALE_BLUE,
        outline=BLUE,
    )
    rounded_box(
        draw,
        (540, 690, 850, 875),
        "DX-CP27 Room Beacon",
        "Static iBeacon/Eddystone identity\nRegistered room and RSSI policy",
        fill=PALE_GREEN,
        outline=GREEN,
    )

    rounded_box(
        draw,
        (955, 260, 1285, 705),
        "Student Android App",
        "Authenticate and retain device ID\nRun acoustic and BLE scans concurrently\nCompare BLE candidates by RSSI\nResolve room beacon session\nBuild and submit proof",
        fill=PALE_TEAL,
        outline=TEAL,
    )

    rounded_box(
        draw,
        (1390, 175, 1730, 475),
        "Django REST API",
        "Authentication and role checks\nSession and room validation\nFreshness, digest, device, duplicate, replay, and RSSI rules",
        fill=PALE_BLUE,
        outline=NAVY,
    )
    rounded_box(
        draw,
        (1390, 555, 1730, 855),
        "PostgreSQL and Reports",
        "Users and profiles\nLecturer-owned sessions\nAttendance proofs\nRegistered beacons\nReplay guards\nSession reports and CSV",
        fill=PALE_GREEN,
        outline=GREEN,
    )

    arrow(draw, (255, 435), (255, 500), fill=TEAL)
    arrow(draw, (440, 610), (540, 285), fill=AMBER)
    arrow(draw, (440, 645), (540, 530), fill=BLUE)
    arrow(draw, (850, 285), (955, 390), fill=AMBER)
    arrow(draw, (850, 530), (955, 505), fill=BLUE)
    arrow(draw, (850, 780), (955, 620), fill=GREEN)
    arrow(draw, (1285, 420), (1390, 325), fill=NAVY)
    arrow(draw, (1560, 475), (1560, 555), fill=NAVY)
    arrow(draw, (1390, 730), (1285, 650), fill=GREEN)

    draw.text((82, 930), "Key distinction", font=font(24, True), fill=NAVY)
    draw.rounded_rectangle((70, 970, 1730, 1060), radius=18, fill=PANEL, outline="#B5C1CA", width=3)
    text_center(
        draw,
        (90, 978, 1710, 1052),
        "A scan supplies evidence. Only the authenticated backend can accept attendance and create the record.",
        font(25, True),
        INK,
    )
    save(image, "system_architecture.png")


@dataclass
class FlowNode:
    x: int
    y: int
    w: int
    h: int
    text: str
    kind: str = "process"
    colour: str = BLUE


def draw_flow_node(draw: ImageDraw.ImageDraw, node: FlowNode) -> None:
    box = (node.x, node.y, node.x + node.w, node.y + node.h)
    if node.kind == "decision":
        cx = node.x + node.w // 2
        cy = node.y + node.h // 2
        points = [
            (cx, node.y),
            (node.x + node.w, cy),
            (cx, node.y + node.h),
            (node.x, cy),
        ]
        draw.polygon(points, fill=PALE_AMBER, outline=AMBER)
        draw.line(points + [points[0]], fill=AMBER, width=4)
        text_center(draw, (node.x + 30, node.y + 15, node.x + node.w - 30, node.y + node.h - 15), node.text, font(20, True), AMBER)
    elif node.kind == "terminator":
        draw.rounded_rectangle(box, radius=node.h // 2, fill=PALE_TEAL, outline=TEAL, width=4)
        text_center(draw, box, node.text, font(21, True), TEAL)
    else:
        draw.rounded_rectangle(box, radius=15, fill=PANEL, outline=node.colour, width=4)
        text_center(draw, box, node.text, font(20, True), node.colour)


def attendance_workflow() -> None:
    image = Image.new("RGB", (1800, 1120), PAPER)
    draw = ImageDraw.Draw(image)
    title(draw, "Attendance Workflow", "Lecturer, signal, student, and server actions in one class session.")

    nodes = [
        FlowNode(80, 190, 250, 90, "Lecturer signs in", "terminator"),
        FlowNode(395, 190, 300, 90, "Create session and select room"),
        FlowNode(760, 180, 300, 110, "Open 15-minute attendance window"),
        FlowNode(1125, 180, 300, 110, "Start foreground acoustic and BLE broadcast"),
        FlowNode(1475, 190, 250, 90, "Student starts scan", "terminator"),
        FlowNode(1475, 380, 250, 130, "Valid acoustic, lecturer BLE, or room beacon?", "decision"),
        FlowNode(1085, 400, 300, 90, "Resolve session and show captured source"),
        FlowNode(720, 400, 300, 90, "Build proof and SHA-256 digest"),
        FlowNode(355, 385, 300, 120, "Backend validates identity, session, signal, device, replay, and duplicate"),
        FlowNode(80, 390, 220, 110, "Proof accepted?", "decision"),
        FlowNode(80, 650, 270, 90, "Store attendance and replay record", colour=GREEN),
        FlowNode(430, 650, 270, 90, "Show success confirmation", colour=GREEN),
        FlowNode(805, 650, 270, 90, "Display in selected session report", colour=GREEN),
        FlowNode(1180, 650, 270, 90, "Search or export CSV", colour=GREEN),
        FlowNode(1475, 650, 250, 90, "Lecturer closes attendance", "terminator"),
    ]
    for node in nodes:
        draw_flow_node(draw, node)

    for start, end in [
        ((330, 235), (395, 235)),
        ((695, 235), (760, 235)),
        ((1060, 235), (1125, 235)),
        ((1425, 235), (1475, 235)),
        ((1600, 280), (1600, 380)),
        ((1475, 445), (1385, 445)),
        ((1085, 445), (1020, 445)),
        ((720, 445), (655, 445)),
        ((355, 445), (300, 445)),
        ((190, 500), (190, 650)),
        ((350, 695), (430, 695)),
        ((700, 695), (805, 695)),
        ((1075, 695), (1180, 695)),
        ((1450, 695), (1475, 695)),
    ]:
        arrow(draw, start, end)

    draw.text((1395, 417), "Yes", font=font(18, True), fill=GREEN)
    draw.text((197, 575), "Yes", font=font(18, True), fill=GREEN)
    draw.line((1600, 510, 1600, 565, 1430, 565), fill=RED, width=4)
    arrow(draw, (1430, 565), (1430, 500), fill=RED)
    draw.text((1610, 525), "No: guide and rescan", font=font(18, True), fill=RED)
    draw.line((80, 445, 35, 445, 35, 575, 190, 575), fill=RED, width=4)
    draw.text((42, 530), "No: reject with reason", font=font(18, True), fill=RED)

    draw.rounded_rectangle((110, 865, 1690, 1035), radius=22, fill=PALE_BLUE, outline=BLUE, width=3)
    text_center(
        draw,
        (135, 885, 1665, 1015),
        "The fixed beacon may remain powered throughout the day. It becomes valid only when the server finds one open session in its registered room and the observed RSSI satisfies policy.",
        font(25),
        INK,
    )
    save(image, "attendance_workflow.png")


def validation_flow() -> None:
    image = Image.new("RGB", (1800, 1450), PAPER)
    draw = ImageDraw.Draw(image)
    title(draw, "Backend Validation Flow", "Every material decision is repeated on the server.")

    centre = 620
    node_w = 560
    nodes = [
        FlowNode(centre, 155, node_w, 72, "Authenticated proof request", "terminator"),
        FlowNode(centre, 265, node_w, 80, "Request timestamp within -120 s / +10 s?", "decision"),
        FlowNode(centre, 385, node_w, 80, "Owned session active, open, and unexpired?", "decision"),
        FlowNode(centre, 505, node_w, 80, "At least one supported acoustic or BLE path?", "decision"),
        FlowNode(centre, 625, node_w, 80, "Formats, session IDs, and 60 s signal age valid?", "decision"),
        FlowNode(centre, 745, node_w, 80, "If beacon: active, registered, room matched, RSSI accepted?", "decision"),
        FlowNode(centre, 865, node_w, 80, "Student identity and registered device valid?", "decision"),
        FlowNode(centre, 985, node_w, 80, "No prior proof and no student-scoped replay?", "decision"),
        FlowNode(centre, 1105, node_w, 80, "SHA-256 proof digest matches?", "decision"),
        FlowNode(centre, 1225, node_w, 80, "Create proof and replay record atomically", colour=GREEN),
        FlowNode(centre + 125, 1340, 310, 70, "Attendance accepted", "terminator"),
    ]
    for node in nodes:
        draw_flow_node(draw, node)
    for a, b in zip(nodes, nodes[1:]):
        arrow(
            draw,
            (a.x + a.w // 2, a.y + a.h),
            (b.x + b.w // 2, b.y),
            fill=GREEN,
        )

    reject_x = 80
    reject_w = 330
    reject_y = 660
    rounded_box(
        draw,
        (reject_x, reject_y, reject_x + reject_w, reject_y + 210),
        "Reject Request",
        "Return one clear field or policy error.\nDo not create attendance or replay data.",
        fill=PALE_RED,
        outline=RED,
    )
    decision_nodes = nodes[1:9]
    for index, node in enumerate(decision_nodes):
        y = node.y + node.h // 2
        bend_x = 540 - (index % 2) * 35
        draw.line((node.x, y, bend_x, y, bend_x, reject_y + 105), fill=RED, width=3)
        arrow(draw, (bend_x, reject_y + 105), (reject_x + reject_w, reject_y + 105), fill=RED, width=3)
        draw.text((node.x - 42, y - 20), "No", font=font(17, True), fill=RED)

    draw.text((1210, 280), "Yes", font=font(17, True), fill=GREEN)
    draw.rounded_rectangle((1260, 235, 1730, 545), radius=20, fill=PALE_BLUE, outline=BLUE, width=3)
    text_center(
        draw,
        (1285, 255, 1705, 525),
        "Database constraints remain the final concurrency guard:\n\none proof per student/session\none device per student profile\none rotating challenge/nonce use per student/session",
        font(22),
        INK,
    )
    save(image, "validation_flow.png")


def entity_relationship() -> None:
    image = Image.new("RGB", (1800, 1200), PAPER)
    draw = ImageDraw.Draw(image)
    title(
        draw,
        "Core Entity Relationship Model",
        "Active attendance entities, relationships, and database constraints.",
    )

    boxes = {
        "User": (80, 190, 440, 430),
        "UserProfile": (575, 160, 1020, 470),
        "Session": (1175, 160, 1695, 500),
        "AttendanceProof": (575, 650, 1130, 1080),
        "RegisteredBeacon": (1240, 700, 1710, 1080),
        "AttendanceReplayGuard": (80, 700, 465, 1045),
    }
    contents = {
        "User": ["PK id", "username", "password hash", "full name", "auth token"],
        "UserProfile": ["PK id", "FK user (unique)", "role", "matric number (unique)", "registered device ID", "device registered time"],
        "Session": ["PK id", "FK created_by", "course code and title", "lecturer name", "room", "start/end times", "attendance open/close state"],
        "AttendanceProof": ["PK id", "FK session", "student ID", "device ID and trust", "acoustic token", "BLE nonce", "FK registered beacon", "beacon proof and RSSI", "observed time and digest", "UNIQUE session + student"],
        "RegisteredBeacon": ["PK id", "name and room", "beacon type", "UUID / major / minor", "namespace / instance", "reference and minimum RSSI", "TX power and interval", "active state"],
        "AttendanceReplayGuard": ["PK id", "FK session", "student ID", "acoustic challenge", "BLE nonce", "used time", "UNIQUE per session + student + signal"],
    }
    colours = {
        "User": BLUE,
        "UserProfile": TEAL,
        "Session": NAVY,
        "AttendanceProof": GREEN,
        "RegisteredBeacon": AMBER,
        "AttendanceReplayGuard": RED,
    }
    fills = {
        "User": PALE_BLUE,
        "UserProfile": PALE_TEAL,
        "Session": PALE_BLUE,
        "AttendanceProof": PALE_GREEN,
        "RegisteredBeacon": PALE_AMBER,
        "AttendanceReplayGuard": PALE_RED,
    }

    for name, box in boxes.items():
        x1, y1, x2, y2 = box
        draw.rounded_rectangle(box, radius=18, fill=fills[name], outline=colours[name], width=4)
        draw.rectangle((x1, y1, x2, y1 + 55), fill=colours[name])
        text_center(draw, (x1 + 5, y1 + 3, x2 - 5, y1 + 52), name, font(24, True), PAPER)
        y = y1 + 70
        for item in contents[name]:
            draw.text((x1 + 24, y), f"- {item}", font=font(19), fill=INK)
            y += 34

    arrow(draw, (440, 310), (575, 310), fill=TEAL)
    draw.text((463, 277), "1 : 1", font=font(18, True), fill=TEAL)
    arrow(draw, (1020, 300), (1175, 300), fill=NAVY)
    draw.text((1050, 267), "1 : many", font=font(18, True), fill=NAVY)
    arrow(draw, (1435, 500), (1040, 650), fill=GREEN)
    draw.text((1210, 555), "1 : many", font=font(18, True), fill=GREEN)
    arrow(draw, (1240, 850), (1130, 850), fill=AMBER)
    draw.text((1148, 815), "0..1 : many", font=font(18, True), fill=AMBER)
    arrow(draw, (575, 880), (465, 880), fill=RED)
    draw.text((474, 845), "same session/student", font=font(17, True), fill=RED)

    draw.rounded_rectangle((95, 1100, 1705, 1160), radius=15, fill=PANEL, outline="#B5C1CA", width=2)
    text_center(
        draw,
        (110, 1106, 1690, 1154),
        "Deleting a session cascades to its proofs and replay guards; operational deletion must therefore be controlled.",
        font(21),
        INK,
    )
    save(image, "entity_relationship.png")


def main() -> None:
    architecture()
    attendance_workflow()
    validation_flow()
    entity_relationship()
    for path in sorted(OUTPUT.glob("*.png")):
        print(path)


if __name__ == "__main__":
    main()
