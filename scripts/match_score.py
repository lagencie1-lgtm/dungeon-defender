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
    return rgba.convert("RGB"), rgba.split()[3].point(lambda a: 255 if a > 40 else 0)


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
    passed = iou >= 0.85 and de <= 25 and ratio >= 0.7
    print(f"IoU {iou * 100:.1f}%  width profile off {profile * 100:.1f}%  colour dE {de:.1f}  "
          f"detail {dr * 100:.1f}% vs picture {dt * 100:.1f}% (ratio {ratio:.2f})  {'PASS' if passed else 'not yet'}"
          "  [pass: IoU >= 85%, colour dE <= 25, detail ratio >= 0.7]")


if __name__ == "__main__":
    main()
