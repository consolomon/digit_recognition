"""Minimal PSD reader: header, image resources, layer records, tagged blocks,
text (TySh) + EngineData fonts/colours, and per-layer RGBA rasters to PNG."""
import json, re, struct, sys, os
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, "layers"), exist_ok=True)
data = open(src, "rb").read()
pos = 0

def rd(fmt):
    global pos
    v = struct.unpack_from(">" + fmt, data, pos)
    pos += struct.calcsize(">" + fmt)
    return v if len(v) > 1 else v[0]

def raw(n):
    global pos
    b = data[pos:pos + n]; pos += n
    return b

report = {}
sig, ver = raw(4), rd("H"); raw(6)
ch, h, w, depth, mode = rd("HIIHH")
report["header"] = dict(sig=sig.decode(), version=ver, channels=ch, width=w, height=h, depth=depth, color_mode=mode)

cm_len = rd("I"); raw(cm_len)

# Image resources
ir_len = rd("I"); ir_end = pos + ir_len
resources = []
while pos < ir_end:
    raw(4); rid = rd("H"); nl = data[pos]; name = data[pos+1:pos+1+nl]; pos += 1 + nl
    if pos % 2: pos += 1
    sz = rd("I"); body = raw(sz)
    if sz % 2: pos += 1
    item = {"id": rid, "size": sz}
    if rid == 1060:  # XMP
        item["xmp"] = body.decode("utf8", "replace")
    if rid == 1005:
        hr, _, _, vr = struct.unpack_from(">IHHI", body)
        item["resolution_dpi"] = [hr / 65536, vr / 65536]
    if rid == 1032:
        n = struct.unpack_from(">I", body, 12)[0]
        item["guides"] = [dict(pos=struct.unpack_from(">i", body, 16+i*5)[0]/32,
                               dir="vertical" if body[20+i*5] == 0 else "horizontal") for i in range(n)]
    resources.append(item)
pos = ir_end
report["resources"] = [{k: v for k, v in r.items() if k != "xmp"} for r in resources]
xmp = next((r["xmp"] for r in resources if "xmp" in r), "")
open(os.path.join(out, "xmp.xml"), "w").write(xmp)

# --- descriptor parsing (for TySh) ---
def unicode_str(b, p):
    n = struct.unpack_from(">I", b, p)[0]; p += 4
    return b[p:p+n*2].decode("utf-16-be").rstrip("\x00"), p + n*2

def key(b, p):
    n = struct.unpack_from(">I", b, p)[0]; p += 4
    if n == 0: n = 4
    return b[p:p+n].decode("latin1"), p + n

def descriptor(b, p):
    _, p = unicode_str(b, p); _, p = key(b, p)
    cnt = struct.unpack_from(">I", b, p)[0]; p += 4
    d = {}
    for _ in range(cnt):
        k, p = key(b, p); v, p = item(b, p); d[k] = v
    return d, p

def item(b, p):
    t = b[p:p+4].decode("latin1"); p += 4
    if t in ("Objc", "GlbO"): return descriptor(b, p)
    if t == "TEXT": return unicode_str(b, p)
    if t == "long": return struct.unpack_from(">i", b, p)[0], p + 4
    if t == "doub": return struct.unpack_from(">d", b, p)[0], p + 8
    if t == "bool": return bool(b[p]), p + 1
    if t == "UntF":
        u = b[p:p+4].decode("latin1"); return {"unit": u, "v": struct.unpack_from(">d", b, p+4)[0]}, p + 12
    if t == "enum":
        _, p = key(b, p); v, p = key(b, p); return v, p
    if t == "VlLs":
        n = struct.unpack_from(">I", b, p)[0]; p += 4; arr = []
        for _ in range(n):
            v, p = item(b, p); arr.append(v)
        return arr, p
    if t == "tdta":
        n = struct.unpack_from(">I", b, p)[0]; p += 4
        return {"tdta": b[p:p+n]}, p + n
    if t == "type":
        _, p = unicode_str(b, p); v, p = key(b, p); return v, p
    raise ValueError("unsupported descriptor type " + t)

def engine_summary(ed):
    txt = ed.decode("latin1")
    fonts = re.findall(r"/Name \(\xfe\xff((?:[^)\\]|\\.)*)\)", txt)
    fonts = [re.sub(r"\\(.)", r"\1", f).encode("latin1").decode("utf-16-be", "replace") for f in fonts]
    sizes = sorted({float(x) for x in re.findall(r"/FontSize ([\d.]+)", txt)})
    leading = sorted({float(x) for x in re.findall(r"/Leading ([\d.]+)", txt)})
    tracking = sorted({int(float(x)) for x in re.findall(r"/Tracking (-?[\d.]+)", txt)})
    colors = re.findall(r"/FillColor << /Type 1 /Values \[ ([\d. ]+)\]", txt)
    cols = sorted({"#%02x%02x%02x" % tuple(round(float(c) * 255) for c in v.split()[1:4]) for v in colors})
    underline = "/Underline true" in txt
    return dict(fonts=sorted(set(fonts)), sizes=sizes, leading=leading, tracking=tracking,
                fill_colors=cols, underline=underline)

# Layer and mask info
lm_len = rd("I"); lm_end = pos + lm_len
li_len = rd("I"); li_end = pos + li_len
count = abs(rd("h"))
layers = []
for _ in range(count):
    t, l, b_, r = rd("iiii")
    nch = rd("H"); chans = [rd("hI") for _ in range(nch)]
    raw(4); blend = raw(4).decode(); opacity = data[pos]; clip = data[pos+1]; flags = data[pos+2]; pos += 4
    extra_len = rd("I"); extra_end = pos + extra_len
    mlen = rd("I"); raw(mlen)
    blen = rd("I"); raw(blen)
    nl = data[pos]; name = data[pos+1:pos+1+nl].decode("latin1"); pos += 1 + nl
    pos += (-(1 + nl)) % 4
    L = dict(name=name, bbox=[l, t, r, b_], blend=blend, opacity=opacity, clipping=clip,
             visible=not (flags & 2), channels=chans, tags={})
    while pos < extra_end:
        raw(4); k = raw(4).decode("latin1"); n = rd("I"); body = raw(n)
        if n % 2 and False: pass
        L["tags"].setdefault(k, n)
        if k == "luni":
            L["name"] = unicode_str(body, 0)[0]
        elif k in ("lsct", "lsdk"):
            L["section"] = {0: "other", 1: "open folder", 2: "closed folder", 3: "group end"}[struct.unpack_from(">I", body)[0]]
        elif k == "lclr":
            L["color_label"] = struct.unpack_from(">H", body)[0]
        elif k == "SoCo":
            d, _ = descriptor(body, 4)
            c = d.get("Clr ", {}); L["solid_fill"] = "#%02x%02x%02x" % (round(c.get("Rd  ", 0)), round(c.get("Grn ", 0)), round(c.get("Bl  ", 0)))
        elif k == "TySh":
            p = 2 + 48 + 2 + 4
            d, p = descriptor(body, p)
            L["text"] = d.get("Txt ")
            ed = d.get("EngineData", {}).get("tdta", b"")
            L["text_style"] = engine_summary(ed)
            L["text_transform"] = list(struct.unpack_from(">6d", body, 2))
        elif k in ("SoLd", "PlLd"):
            L["smart_object"] = True
        elif k == "lfx2":
            try:
                d, _ = descriptor(body, 8)
                L["effects"] = [x for x in d if isinstance(d[x], (dict, list))]
            except Exception as e:
                L["effects"] = "unparsed"
    pos = extra_end
    layers.append(L)

# Channel image data per layer
def unrle(buf, p, rows, width):
    counts = struct.unpack_from(">%dH" % rows, buf, p); p += 2 * rows
    outb = bytearray()
    for c in counts:
        row = buf[p:p+c]; p += c; i = 0
        while i < len(row):
            n = row[i]; i += 1
            if n < 128:
                outb += row[i:i+n+1]; i += n + 1
            elif n > 128:
                outb += bytes([row[i]]) * (257 - n); i += 1
    return bytes(outb), p

for idx, L in enumerate(layers):
    l, t, r, b_ = L["bbox"]; lw, lh = r - l, b_ - t
    planes = {}
    for cid, clen in L["channels"]:
        start = pos; comp = rd("H")
        rows = lh if cid != -2 else 0
        if lw > 0 and lh > 0 and cid in (-1, 0, 1, 2):
            if comp == 0:
                planes[cid] = data[pos:pos + lw*lh]
            elif comp == 1:
                planes[cid], _ = unrle(data, pos, lh, lw)
        pos = start + clen
    if lw > 0 and lh > 0 and all(c in planes for c in (0, 1, 2)):
        a = planes.get(-1, b"\xff" * (lw*lh))
        im = Image.merge("RGBA", [Image.frombytes("L", (lw, lh), planes[c][:lw*lh]) for c in (0, 1, 2)] +
                         [Image.frombytes("L", (lw, lh), a[:lw*lh])])
        fn = "layers/%02d_%s.png" % (idx, re.sub(r"[^\w.-]+", "_", L["name"])[:40])
        im.save(os.path.join(out, fn)); L["png"] = fn
        # dominant opaque colours
        small = im.copy(); small.thumbnail((200, 200))
        px = [p[:3] for p in small.getdata() if p[3] > 200]
        if px:
            q = Image.new("RGB", (len(px), 1)); q.putdata(px)
            pal = q.quantize(6).convert("RGB").getcolors(4096) or []
            L["dominant"] = ["#%02x%02x%02x" % c for _, c in sorted(pal, reverse=True)[:6]]
    L.pop("channels")

report["layers"] = layers
json.dump(report, open(os.path.join(out, "psd_report.json"), "w"), indent=1, ensure_ascii=False, default=str)
print(json.dumps(report["header"]), len(layers), "layers")
for i, L in enumerate(layers):
    print(i, repr(L["name"]), L["bbox"], L["blend"], L["opacity"], "vis" if L["visible"] else "HID",
          L.get("section", ""), "T:" + repr(L.get("text"))[:60] if L.get("text") else "",
          L.get("text_style", {}).get("fonts", ""), L.get("solid_fill", ""), "SO" if L.get("smart_object") else "",
          L.get("dominant", "")[:3] if L.get("dominant") else "")
