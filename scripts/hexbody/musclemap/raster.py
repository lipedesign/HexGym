# Turns the MuscleMap front/back artwork (MIT, Melih Colpan) into label maps the 3D body can be painted from.
# HEX_FIG=male (default) or female. Output: labels_{view}[ _f].npy (int32, S px per SVG unit) and labels[_f].json.
# Both figures share one id table: a piece keeps its id across figures, and new pieces are appended,
# so labels.json (with the v2 rows) is never renumbered.
import json, math, re, os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 2.0
FIG = os.environ.get("HEX_FIG", "male")
SUF = "" if FIG == "male" else "_f"
VB = {"male": {"front": (0.0, 95.0, 727.0, 1280.0), "back": (718.0, 95.0, 727.0, 1280.0)},
      "female": {"front": (0.0, 0.0, 650.0, 1450.0), "back": (823.0, 0.0, 650.0, 1450.0)}}[FIG]
SUB = {"upperChest": "chest", "lowerChest": "chest", "innerQuad": "quadriceps", "outerQuad": "quadriceps",
       "hipFlexors": "hip-flexors", "upperAbs": "abs", "lowerAbs": "abs", "frontDeltoid": "deltoids",
       "rearDeltoid": "deltoids", "upperTrapezius": "trapezius", "lowerTrapezius": "trapezius",
       "serratus": "serratus", "rotatorCuff": "deltoids", "rhomboids": "upper-back"}
GROUP = {"upperBack": "upper-back", "lowerBack": "lower-back", "hipFlexors": "hip-flexors"}
INERT = {"head", "hair", "neck", "hands", "feet", "knees", "ankles"}
NUM = re.compile(r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?')

def tokens(d):
    i, n = 0, len(d)
    while i < n:
        c = d[i]
        if c.isalpha():
            yield c; i += 1
        elif c in ' ,\n\t':
            i += 1
        else:
            m = NUM.match(d, i)
            yield m.group(0); i = m.end()

def arc_points(p0, rx, ry, phi, fa, fs, p1, steps=10):
    x1, y1 = p0; x2, y2 = p1
    if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2):
        return [p1]
    rx, ry = abs(rx), abs(ry); ph = math.radians(phi); c, s = math.cos(ph), math.sin(ph)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    xp, yp = c * dx + s * dy, -s * dx + c * dy
    lam = xp * xp / (rx * rx) + yp * yp / (ry * ry)
    if lam > 1: rx *= math.sqrt(lam); ry *= math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp
    den = rx * rx * yp * yp + ry * ry * xp * xp
    k = math.sqrt(max(0.0, num / den)) * (-1 if fa == fs else 1)
    cxp, cyp = k * rx * yp / ry, -k * ry * xp / rx
    cx, cy = c * cxp - s * cyp + (x1 + x2) / 2, s * cxp + c * cyp + (y1 + y2) / 2
    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a
    t1 = ang(1, 0, (xp - cxp) / rx, (yp - cyp) / ry)
    dt = ang((xp - cxp) / rx, (yp - cyp) / ry, (-xp - cxp) / rx, (-yp - cyp) / ry)
    if not fs and dt > 0: dt -= 2 * math.pi
    elif fs and dt < 0: dt += 2 * math.pi
    out = []
    for i in range(1, steps + 1):
        t = t1 + dt * i / steps
        out.append((cx + rx * math.cos(t) * c - ry * math.sin(t) * s, cy + rx * math.cos(t) * s + ry * math.sin(t) * c))
    return out

def flatten(d, seg=8):
    """SVG path data -> list of closed polygons (absolute coordinates)."""
    tk = list(tokens(d)); i = 0
    polys, cur = [], []
    x = y = sx = sy = 0.0; lc = None; cmd = None; prev_ctrl = None
    def num():
        nonlocal i
        v = float(tk[i]); i += 1; return v
    def flag():
        nonlocal i
        t = tk[i]
        if len(t) > 1 and t[0] in '01' and not t.startswith(('0.', '1.')):
            tk[i] = t[1:]; return int(t[0])
        if t in ('0', '1'):
            i += 1; return int(t)
        if t.startswith(('0', '1')):   # e.g. "01.94" = flag 0, flag 1, number .94
            tk[i] = t[1:]; return int(t[0])
        i += 1; return int(float(t))
    while i < len(tk):
        if tk[i].isalpha():
            cmd = tk[i]; i += 1
            if cmd in 'Zz':
                if cur: polys.append(cur)
                cur = []; x, y = sx, sy; prev_ctrl = None; continue
        rel = cmd.islower(); C = cmd.upper()
        ox, oy = (x, y) if rel else (0.0, 0.0)
        if C == 'M':
            if cur: polys.append(cur)
            x, y = ox + num(), oy + num(); sx, sy = x, y; cur = [(x, y)]
            cmd = 'l' if rel else 'L'; prev_ctrl = None
        elif C == 'L':
            x, y = ox + num(), oy + num(); cur.append((x, y)); prev_ctrl = None
        elif C == 'H':
            x = ox + num() if rel else num(); cur.append((x, y)); prev_ctrl = None
        elif C == 'V':
            y = (y + num()) if rel else num(); cur.append((x, y)); prev_ctrl = None
        elif C in 'CS':
            if C == 'C':
                c1 = (ox + num(), oy + num())
            else:
                c1 = (2 * x - prev_ctrl[0], 2 * y - prev_ctrl[1]) if prev_ctrl and lc in 'CS' else (x, y)
            c2 = (ox + num(), oy + num()); p = (ox + num(), oy + num())
            for k in range(1, seg + 1):
                t = k / seg; u = 1 - t
                cur.append((u**3 * x + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p[0],
                            u**3 * y + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p[1]))
            prev_ctrl = c2; x, y = p
        elif C in 'QT':
            if C == 'Q':
                c1 = (ox + num(), oy + num())
            else:
                c1 = (2 * x - prev_ctrl[0], 2 * y - prev_ctrl[1]) if prev_ctrl and lc in 'QT' else (x, y)
            p = (ox + num(), oy + num())
            for k in range(1, seg + 1):
                t = k / seg; u = 1 - t
                cur.append((u * u * x + 2 * u * t * c1[0] + t * t * p[0], u * u * y + 2 * u * t * c1[1] + t * t * p[1]))
            prev_ctrl = c1; x, y = p
        elif C == 'A':
            rx, ry, ph = num(), num(), num(); fa, fs = flag(), flag()
            p = (ox + num(), oy + num())
            cur += arc_points((x, y), rx, ry, ph, fa, fs, p); x, y = p; prev_ctrl = None
        lc = C
    if cur: polys.append(cur)
    return polys

data = json.load(open(os.path.join(HERE, FIG + ".json")))
LJ = os.path.join(HERE, "labels.json")
table = json.load(open(LJ))["table"] if os.path.exists(LJ) else [{"id": 0, "kind": "outside"}, {"id": 1, "kind": "gap"}]
KEY = {(t["view"], t["slug"], t["side"], t["piece"]): t["id"] for t in table if t.get("kind") in ("muscle", "inert") and not t.get("v2")}
maps, marks = {}, {}
for view in ("front", "back"):
    x0, y0, w, h = VB[view]
    W, Hh = int(w * S), int(h * S)
    img = Image.new("I", (W, Hh), 0); dr = ImageDraw.Draw(img)
    parts = data[view]["parts"]
    order = [p for p in parts if p["slug"] not in SUB] + [p for p in parts if p["slug"] in SUB]
    boxes = {}
    for p in order:
        slug = p["slug"]
        for side in ("left", "right", "common"):
            for k, d in enumerate(p.get(side, [])):
                lid = KEY.get((view, slug, side, k))
                if lid is None:
                    lid = len(table)
                    kind = "inert" if slug in INERT else "muscle"
                    group = SUB.get(slug, GROUP.get(slug, slug))
                    table.append({"id": lid, "kind": kind, "view": view, "slug": slug, "group": group,
                                  "sub": slug in SUB, "side": side, "piece": k, "fig": FIG})
                for poly in flatten(d):
                    pts = [((px - x0) * S, (py - y0) * S) for px, py in poly]
                    if len(pts) >= 3: dr.polygon(pts, fill=lid)
                    for px, py in poly:
                        b = boxes.setdefault(slug, [1e9, 1e9, -1e9, -1e9])
                        b[0] = min(b[0], px); b[1] = min(b[1], py); b[2] = max(b[2], px); b[3] = max(b[3], py)
    a = np.array(img, dtype=np.int32)
    # close the thin gaps between muscles to get the body silhouette; gaps inside it become "gap" (skin)
    occ = a > 0
    r = int(7 * S)
    def dil(m, r):
        o = m.copy()
        for _ in range(r):
            o = o | np.roll(o, 1, 0) | np.roll(o, -1, 0) | np.roll(o, 1, 1) | np.roll(o, -1, 1)
        return o
    def ero(m, r):
        return ~dil(~m, r)
    sil = ero(dil(occ, r), r)
    a[(~occ) & sil] = 1
    maps[view] = a
    marks[view] = {k: v for k, v in boxes.items()}
    np.save(os.path.join(HERE, f"labels_{view}{SUF}.npy"), a)
    vis = Image.fromarray(((a * 37) % 200 + 40).astype(np.uint8) * (a > 0)).convert("L")
    vis.save(os.path.join(HERE, f"labels_{view}{SUF}.png"))
json.dump({"S": S, "vb": VB, "table": table, "boxes": marks}, open(os.path.join(HERE, f"labels{SUF}.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
if SUF:   # keep the shared table in labels.json current; its male boxes and viewBoxes stay as they are
    L = json.load(open(LJ)); L["table"] = table; json.dump(L, open(LJ, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("labels", len(table))
for view in ("front", "back"):
    b = marks[view]
    print(view, "head", [round(v) for v in b.get("head", b.get("hair", [0, 0, 0, 0]))], "feet", [round(v) for v in b["feet"]],
          "knees", [round(v) for v in b.get("knees", [0, 0, 0, 0])], "deltoids", [round(v) for v in b["deltoids"]],
          "hands", [round(v) for v in b["hands"]])
