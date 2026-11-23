"""Scores how closely a model render matches its target picture (6A world-and-art section IV, measured matching):
  silhouette IoU      overlap of the two outlines, both scaled to the same height and centred
  width profile       mean difference of the outline width, row by row, as a share of the target's width
  colour (Lab dE)     mean CIE Lab difference where both are solid
and writes a sheet: target | render | outline diff (green shared, red target only, blue model only).
Run: python scripts/match_score.py target.png render.png sheet.png
The target has a white background; the render a transparent one."""
import sys

from PIL import Image, ImageChops

H = 360
# gates (coordinator 2026-11-23): outline IoU 90%; region colour calibrated on the paintings themselves
# (scripts/match_calibrate.py: the picture against itself 6% lighter/darker and softened scores 3-6, so 10 leaves room\n# for the outline differences a 90% IoU allows); detail: the picture softened by a 1.5 px blur keeps 0.83 of its detail
GATE_IOU = 0.90
GATE_REGION = 10.0
GATE_DETAIL = (0.85, 1.3)


def mask_target(im):
    rgb = im.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    m = Image.new("L", (w, h), 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) < 238:
                mp[x, y] = 255
    return rgb, m


def mask_render(im):
    rgba = im.convert("RGBA")
    white = Image.new("RGB", rgba.size, (255, 255, 255))
    white.paste(rgba, (0, 0), rgba)   # on white like the picture (the sheet showed it on black)
    return white, rgba.split()[3].point(lambda a: 255 if a > 40 else 0)


def normalise(rgb, m):
    box = m.getbbox()
    rgb, m = rgb.crop(box), m.crop(box)
    w = max(1, round(m.size[0] * H / m.size[1]))
    return rgb.resize((w, H)), m.resize((w, H))


def centred(img, width, mode, fill):
    canvas = Image.new(mode, (width, H), fill)
    canvas.paste(img, ((width - img.size[0]) // 2, 0))
    return canvas


def lab(rgb):
    return rgb.convert("LAB") if hasattr(Image, "LAB") else rgb


def main():
    t_rgb, t_m = normalise(*mask_target(Image.open(sys.argv[1])))
    r_rgb, r_m = normalise(*mask_render(Image.open(sys.argv[2])))
    width = max(t_m.size[0], r_m.size[0]) + 20
    t_m, r_m = centred(t_m, width, "L", 0), centred(r_m, width, "L", 0)
    t_rgb, r_rgb = centred(t_rgb, width, "RGB", (255, 255, 255)), centred(r_rgb, width, "RGB", (255, 255, 255))
    a, b = t_m.load(), r_m.load()
    inter = union = 0
    widths = []
    for y in range(H):
        tw = rw = 0
        for x in range(width):
            ta, rb = a[x, y] > 0, b[x, y] > 0
            inter += ta and rb
            union += ta or rb
            tw += ta
            rw += rb
        if tw:
            widths.append(abs(tw - rw) / tw)
    iou = inter / max(1, union)
    profile = sum(widths) / max(1, len(widths))
    # colour: Lab difference where both are solid
    from PIL import ImageCms
    srgb = ImageCms.createProfile("sRGB")
    labp = ImageCms.createProfile("LAB")
    tf = ImageCms.buildTransformFromOpenProfiles(srgb, labp, "RGB", "LAB")
    tl, rl = ImageCms.applyTransform(t_rgb, tf).load(), ImageCms.applyTransform(r_rgb, tf).load()
    de, n = 0.0, 0
    for y in range(0, H, 2):
        for x in range(0, width, 2):
            if a[x, y] and b[x, y]:
                p, q = tl[x, y], rl[x, y]
                de += ((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2) ** 0.5
                n += 1
    de = de / max(1, n)
    # region colour: mean Lab per cell of a grid (a small misalignment of the outlines does not count as colour)
    # and per band of the tower (roof, lookout, wall, footing), so the report says where the colour is off
    def cell_means(lp, mk, x0, y0, x1, y1):
        acc, cnt = [0.0, 0.0, 0.0], 0
        for yy in range(y0, y1, 2):
            for xx in range(x0, x1, 2):
                if mk[xx, yy]:
                    p = lp[xx, yy]
                    acc = [acc[0] + p[0], acc[1] + p[1], acc[2] + p[2]]
                    cnt += 1
        return [v / max(1, cnt) for v in acc], cnt
    def lab_d(p, q):
        # PIL keeps L in 0..255; a and b are offset by 128 (bytes), so differences are fine; L is scaled to 0..100
        return (((p[0] - q[0]) * 100 / 255) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2) ** 0.5
    COLS, ROWS = 6, 12
    cells = []
    for cy in range(ROWS):
        for cx in range(COLS):
            x0, x1 = cx * width // COLS, (cx + 1) * width // COLS
            y0, y1 = cy * H // ROWS, (cy + 1) * H // ROWS
            mt, nt = cell_means(tl, a, x0, y0, x1, y1)
            mr, nr = cell_means(rl, b, x0, y0, x1, y1)
            full = (x1 - x0) * (y1 - y0) / 4
            if nt > full * 0.35 and nr > full * 0.35:
                cells.append(lab_d(mt, mr))
    region = sum(cells) / max(1, len(cells))
    BANDS = (("roof", 0.0, 0.42), ("lookout", 0.42, 0.62), ("wall", 0.62, 0.9), ("footing", 0.9, 1.0))
    bands = []
    for name, f0, f1 in BANDS:
        mt, _ = cell_means(tl, a, 0, int(H * f0), width, int(H * f1))
        mr, _ = cell_means(rl, b, 0, int(H * f0), width, int(H * f1))
        bands.append(f"{name} {lab_d(mt, mr):.0f} (L {mt[0] * 100 / 255:.0f}/{mr[0] * 100 / 255:.0f})")
    diff = Image.new("RGB", (width, H), (255, 255, 255))
    d = diff.load()
    for y in range(H):
        for x in range(width):
            ta, rb = a[x, y] > 0, b[x, y] > 0
            d[x, y] = (90, 190, 90) if ta and rb else (225, 80, 70) if ta else (80, 120, 230) if rb else (255, 255, 255)
    sheet = Image.new("RGB", (width * 3, H), (255, 255, 255))
    sheet.paste(t_rgb, (0, 0))
    sheet.paste(r_rgb, (width, 0))
    sheet.paste(diff, (width * 2, 0))
    if len(sys.argv) > 3:
        sheet.save(sys.argv[3])
    # detail: how much painted detail (edges) there is inside each outline, so a plain model cannot pass on
    # its outline alone (coordinator 2026-11-23: flat roofs, no brass, blob archers)
    from PIL import ImageFilter
    def detail(rgb, m):
        edges = rgb.convert("L").filter(ImageFilter.FIND_EDGES).load()
        mk = m.load()
        inside = strong = 0
        for y in range(1, H - 1):
            for x in range(1, width - 1):
                if mk[x, y]:
                    inside += 1
                    strong += edges[x, y] > 40
        return strong / max(1, inside)
    dt, dr = detail(t_rgb, t_m), detail(r_rgb, r_m)
    ratio = dr / max(1e-6, dt)
    passed = iou >= GATE_IOU and region <= GATE_REGION and GATE_DETAIL[0] <= ratio <= GATE_DETAIL[1]
    print(f"IoU {iou * 100:.1f}%  width profile off {profile * 100:.1f}%  region colour dE {region:.1f}  "
          f"(pixel dE {de:.1f})  detail {dr * 100:.1f}% vs picture {dt * 100:.1f}% (ratio {ratio:.2f})  "
          f"{'PASS' if passed else 'not yet'}  [pass: IoU >= {GATE_IOU * 100:.0f}%, region dE <= {GATE_REGION}, "
          f"detail ratio {GATE_DETAIL[0]}-{GATE_DETAIL[1]}]")
    print("bands (dE, lightness picture/model): " + "  ".join(bands))
    if len(sys.argv) > 3:
        # the flicker pair: picture and model in the same frame, to flip between (differences jump out)
        t_img = Image.new("RGB", (width, H), (255, 255, 255))
        t_img.paste(t_rgb, (0, 0), t_m)
        r_img = Image.new("RGB", (width, H), (255, 255, 255))
        r_img.paste(r_rgb, (0, 0), r_m)
        stem = sys.argv[3].rsplit(".", 1)[0]
        t_img.save(stem + "_flicker.gif", save_all=True, append_images=[r_img], duration=700, loop=0)


if __name__ == "__main__":
    main()
