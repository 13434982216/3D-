# -*- coding: utf-8 -*-
"""程序化绘制 5 个抽象几何风产品图标（透明背景，4x 超采样抗锯齿）"""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 4          # 超采样倍数
OUT = 256      # 输出尺寸
W = OUT * S

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def new_canvas():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def vgrad(draw, pts, c1, c2, y0, y1):
    """在多边形区域内做垂直渐变：用蒙版贴渐变图"""
    poly = [(x * W, y * W) for x, y in pts]
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    grad = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(W):
        c = lerp(c1, c2, min(1.0, max(0.0, (y - y0 * W) / max(1, (y1 - y0) * W))))
        gd.line([(0, y), (W, y)], fill=c)
    draw._image.paste(grad, (0, 0), mask)

def shrink_poly(pts, cx, cy, k):
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]

def save(img, name):
    img = img.resize((OUT, OUT), Image.LANCZOS)
    path = os.path.join(ASSETS, name + ".png")
    img.save(path)
    print("saved", path)

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "Images", "ui", "products")

# --------------------------------------------------------------- 1. 几何鲸鱼
def whale():
    img, d = new_canvas()
    cx, cy = 0.52, 0.55
    # 身体：低多边形鲸鱼（折线轮廓）
    body = [
        (0.16, 0.62), (0.22, 0.44), (0.36, 0.30), (0.56, 0.26), (0.74, 0.34),
        (0.82, 0.48), (0.80, 0.62), (0.66, 0.72), (0.44, 0.76), (0.26, 0.74),
    ]
    vgrad(d, body, (86, 130, 255, 255), (120, 84, 220, 255), 0.2, 0.8)
    # 切面：几块半透明浅色多边形模拟 low-poly 光影
    for poly, col in [
        ([(0.36, 0.30), (0.56, 0.26), (0.60, 0.50), (0.40, 0.52)], (255, 255, 255, 46)),
        ([(0.56, 0.26), (0.74, 0.34), (0.70, 0.56), (0.60, 0.50)], (255, 255, 255, 30)),
        ([(0.22, 0.44), (0.36, 0.30), (0.40, 0.52), (0.30, 0.62)], (30, 20, 90, 40)),
    ]:
        d.polygon([(x * W, y * W) for x, y in poly], fill=col)
    # 尾鳍
    tail = [(0.80, 0.55), (0.94, 0.40), (0.90, 0.58), (0.95, 0.74), (0.79, 0.63)]
    vgrad(d, tail, (108, 148, 255, 255), (96, 70, 200, 255), 0.3, 0.8)
    # 肚皮浅色
    belly = [(0.30, 0.66), (0.50, 0.70), (0.68, 0.66), (0.62, 0.74), (0.42, 0.76), (0.32, 0.72)]
    d.polygon([(x * W, y * W) for x, y in belly], fill=(210, 226, 255, 210))
    # 喷水几何水花
    for i, (dx, hgt, r) in enumerate([(0.44, 0.10, 0.028), (0.56, 0.14, 0.034), (0.66, 0.09, 0.024)]):
        x0, y0 = 0.56, 0.28
        x1, y1 = x0 + dx - 0.5, y0 - hgt
        d.line([(x0 * W, y0 * W), (x1 * W, y1 * W)], fill=(160, 200, 255, 200), width=int(0.012 * W))
        d.ellipse([(x1 - r) * W, (y1 - r) * W, (x1 + r) * W, (y1 + r) * W], fill=(190, 220, 255, 220))
    # 眼睛
    ex, ey, r = 0.66, 0.44, 0.030
    d.ellipse([(ex - r) * W, (ey - r) * W, (ex + r) * W, (ey + r) * W], fill=(24, 22, 60, 255))
    d.ellipse([(ex - r * 0.35) * W, (ey - r * 0.45) * W, (ex + r * 0.3) * W, (ey - r * 0.1) * W], fill=(255, 255, 255, 255))
    # 背鳍小三角
    fin = [(0.52, 0.26), (0.62, 0.16), (0.64, 0.30)]
    vgrad(d, fin, (140, 100, 235, 255), (110, 80, 210, 255), 0.16, 0.3)
    save(img, "whale")

# --------------------------------------------------------------- 2. 星环猫
def star_cat():
    img, d = new_canvas()
    cx, cy = 0.5, 0.5
    # 星球环
    ring_box = [0.10, 0.42, 0.90, 0.74]
    d.arc([ring_box[0] * W, ring_box[1] * W, ring_box[2] * W, ring_box[3] * W],
          start=200, end=340, fill=(250, 205, 120, 255), width=int(0.030 * W))
    d.arc([ring_box[0] * W, ring_box[1] * W, ring_box[2] * W, ring_box[3] * W],
          start=20, end=160, fill=(240, 180, 95, 255), width=int(0.030 * W))
    # 猫蜷成圆（星球本体）
    body_r = 0.26
    d.ellipse([(cx - body_r) * W, (cy - body_r) * W, (cx + body_r) * W, (cy + body_r) * W],
              fill=(168, 148, 255, 255))
    # 内圈渐层（腹）
    inner = 0.18
    d.ellipse([(cx - inner) * W, (cy - inner + 0.05) * W, (cx + inner) * W, (cy + inner + 0.05) * W],
              fill=(205, 192, 255, 235))
    # 耳朵
    for sx in (-1, 1):
        tri = [(cx + sx * 0.16, cy - 0.18), (cx + sx * 0.26, cy - 0.36), (cx + sx * 0.04, cy - 0.26)]
        d.polygon([(x * W, y * W) for x, y in tri], fill=(150, 128, 240, 255))
        tri2 = shrink_poly(tri, cx, cy, 0.86)
        d.polygon([(x * W, y * W) for x, y in tri2], fill=(255, 190, 200, 255))
    # 尾巴绕一圈（弧线）
    d.arc([(cx - 0.20) * W, (cy + 0.02) * W, (cx + 0.20) * W, (cy + 0.42) * W],
          start=180, end=400, fill=(130, 108, 230, 255), width=int(0.035 * W))
    # 闭眼 + 腮红
    for sx in (-1, 1):
        ex = cx + sx * 0.11
        ey = cy + 0.02
        d.arc([(ex - 0.045) * W, (ey - 0.035) * W, (ex + 0.045) * W, (ey + 0.035) * W],
              start=20, end=160, fill=(60, 40, 110, 255), width=int(0.014 * W))
    d.ellipse([(cx - 0.20) * W, (cy + 0.06) * W, (cx - 0.12) * W, (cy + 0.13) * W], fill=(255, 160, 180, 170))
    d.ellipse([(cx + 0.12) * W, (cy + 0.06) * W, (cx + 0.20) * W, (cy + 0.13) * W], fill=(255, 160, 180, 170))
    # 鼻子
    d.polygon([(cx - 0.020) * W, (cy + 0.045) * W, (cx + 0.020) * W, (cy + 0.045) * W, cx * W, (cy + 0.075) * W],
              fill=(255, 140, 160, 255))
    # 星星点缀
    for x, y, r in [(0.20, 0.22, 0.020), (0.78, 0.20, 0.024), (0.84, 0.78, 0.018), (0.16, 0.74, 0.016)]:
        d.ellipse([(x - r) * W, (y - r) * W, (x + r) * W, (y + r) * W], fill=(255, 224, 150, 230))
    # 前环（穿过星球前方的部分最后画）
    d.arc([ring_box[0] * W, ring_box[1] * W, ring_box[2] * W, ring_box[3] * W],
          start=205, end=335, fill=(255, 214, 130, 255), width=int(0.036 * W))
    save(img, "star_cat")

# --------------------------------------------------------------- 3. 折纸狐狸
def origami_fox():
    img, d = new_canvas()
    # 头（大三角）
    head = [(0.22, 0.42), (0.78, 0.42), (0.50, 0.82)]
    vgrad(d, head, (255, 158, 74, 255), (240, 110, 40, 255), 0.4, 0.85)
    # 左右折面（亮/暗）
    left = [(0.22, 0.42), (0.50, 0.42), (0.50, 0.82)]
    d.polygon([(x * W, y * W) for x, y in left], fill=(255, 190, 120, 90))
    # 耳朵
    for sx, col in [(-1, (255, 178, 96, 255)), (1, (235, 120, 40, 255))]:
        ear = [(0.50 + sx * 0.30, 0.44), (0.50 + sx * 0.16, 0.12), (0.50 + sx * 0.04, 0.40)]
        d.polygon([(x * W, y * W) for x, y in ear], fill=col)
        earin = [(0.50 + sx * 0.24, 0.38), (0.50 + sx * 0.16, 0.20), (0.50 + sx * 0.08, 0.36)]
        d.polygon([(x * W, y * W) for x, y in earin], fill=(255, 224, 210, 255))
    # 脸部白色折面（下颌）
    jaw = [(0.36, 0.56), (0.64, 0.56), (0.50, 0.82)]
    d.polygon([(x * W, y * W) for x, y in jaw], fill=(255, 246, 238, 245))
    # 鼻尖
    d.polygon([(0.462 * W, 0.70 * W), (0.538 * W, 0.70 * W), (0.50 * W, 0.76 * W)], fill=(70, 50, 45, 255))
    # 眼睛：几何菱形
    for sx in (-1, 1):
        ex, ey = 0.50 + sx * 0.115, 0.50
        r = 0.028
        d.polygon([(ex * W, (ey - r) * W), ((ex + r * 0.7) * W, ey * W), (ex * W, (ey + r) * W), ((ex - r * 0.7) * W, ey * W)],
                  fill=(50, 34, 30, 255))
    # 身体（小三角）+ 尾巴（大折三角）
    body = [(0.62, 0.70), (0.86, 0.86), (0.58, 0.88)]
    vgrad(d, body, (250, 140, 60, 255), (230, 105, 35, 255), 0.7, 0.9)
    tail = [(0.62, 0.86), (0.88, 0.66), (0.92, 0.86), (0.78, 0.94)]
    vgrad(d, tail, (255, 168, 90, 255), (240, 125, 50, 255), 0.62, 0.95)
    d.polygon([(0.84 * W, 0.72 * W), (0.92 * W, 0.86 * W), (0.80 * W, 0.90 * W)], fill=(255, 244, 234, 240))
    # 折痕线
    for a, b in [((0.50, 0.42), (0.50, 0.82)), ((0.36, 0.56), (0.64, 0.56))]:
        d.line([(a[0] * W, a[1] * W), (b[0] * W, b[1] * W)], fill=(200, 110, 50, 120), width=int(0.008 * W))
    save(img, "origami_fox")

# --------------------------------------------------------------- 4. 齿轮蜗牛
def gear_snail():
    img, d = new_canvas()
    cx, cy = 0.52, 0.44
    # 壳：同心齿轮
    def gear(r_out, r_in, teeth, rot, col):
        pts = []
        for i in range(teeth * 2):
            ang = rot + i * math.pi / teeth
            r = r_out if i % 2 == 0 else r_in
            for da in (-0.5 / teeth * math.pi, 0.5 / teeth * math.pi):
                pts.append((cx + r * math.cos(ang + da), cy + r * math.sin(ang + da)))
        d.polygon([(x * W, y * W) for x, y in pts], fill=col)
    gear(0.30, 0.255, 10, 0.15, (222, 168, 86, 255))
    gear(0.24, 0.20, 8, 0.5, (238, 190, 110, 255))
    d.ellipse([(cx - 0.155) * W, (cy - 0.155) * W, (cx + 0.155) * W, (cy + 0.155) * W], fill=(196, 140, 70, 255))
    # 螺旋线
    pts = []
    for i in range(120):
        t = i / 119.0
        ang = 0.4 + t * 6.5 * math.pi
        r = 0.02 + t * 0.135
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    d.line([(x * W, y * W) for x, y in pts], fill=(255, 226, 170, 220), width=int(0.016 * W), joint="curve")
    # 铆钉
    for ang in (0.6, 2.3, 4.1, 5.6):
        x, y = cx + 0.20 * math.cos(ang), cy + 0.20 * math.sin(ang)
        r = 0.022
        d.ellipse([(x - r) * W, (y - r) * W, (x + r) * W, (y + r) * W], fill=(120, 84, 40, 255))
        d.ellipse([(x - r * 0.4) * W, (y - r * 0.4) * W, (x + r * 0.2) * W, (y + r * 0.1) * W], fill=(255, 230, 180, 200))
    # 身体
    body = [(0.16, 0.72), (0.86, 0.72), (0.82, 0.84), (0.20, 0.84)]
    body_arc_r = 0.13
    d.rounded_rectangle([0.16 * W, 0.66 * W, 0.88 * W, 0.84 * W], radius=int(body_arc_r * W), fill=(244, 224, 196, 255))
    # 头 + 触角
    d.ellipse([0.10 * W, 0.58 * W, 0.34 * W, 0.82 * W], fill=(248, 230, 204, 255))
    for sx in (0.16, 0.26):
        d.line([(sx * W, 0.62 * W), (sx * W - 0.02 * W, 0.48 * W)], fill=(90, 70, 50, 255), width=int(0.014 * W))
        r = 0.020
        d.ellipse([(sx - 0.02 - r) * W, (0.48 - r) * W, (sx - 0.02 + r) * W, (0.48 + r) * W], fill=(226, 120, 70, 255))
    # 眼睛
    ex, ey = 0.19, 0.66
    r = 0.026
    d.ellipse([(ex - r) * W, (ey - r) * W, (ex + r) * W, (ey + r) * W], fill=(50, 36, 26, 255))
    d.ellipse([(ex - r * 0.4) * W, (ey - r * 0.5) * W, (ex + r * 0.3) * W, (ey - r * 0.05) * W], fill=(255, 255, 255, 255))
    # 微笑
    d.arc([(ex - 0.05) * W, (ey + 0.01) * W, (ex + 0.05) * W, (ey + 0.07) * W], start=10, end=150,
          fill=(90, 66, 46, 255), width=int(0.010 * W))
    # 蒸汽小管道
    d.line([(0.36 * W, 0.70 * W), (0.44 * W, 0.70 * W)], fill=(200, 150, 90, 255), width=int(0.018 * W))
    save(img, "gear_snail")

# --------------------------------------------------------------- 5. 霓虹水母
def neon_jelly():
    img, d = new_canvas()
    cx, cy = 0.5, 0.40
    # 伞面（半圆）
    dome = [(cx - 0.30, cy), (cx - 0.28, cy - 0.16), (cx - 0.16, cy - 0.26),
            (cx, cy - 0.30), (cx + 0.16, cy - 0.26), (cx + 0.28, cy - 0.16), (cx + 0.30, cy)]
    dome += [(cx + 0.30 - i * 0.05, cy + 0.045) for i in range(13)]
    vgrad(d, dome, (255, 130, 220, 235), (110, 150, 255, 235), cy - 0.30, cy)
    # 内层发光
    inner = [(cx - 0.18, cy + 0.02), (cx - 0.14, cy - 0.12), (cx, cy - 0.18),
             (cx + 0.14, cy - 0.12), (cx + 0.18, cy + 0.02)]
    inner += [(cx + 0.18 - i * 0.036, cy + 0.06) for i in range(11)]
    d.polygon([(x * W, y * W) for x, y in inner], fill=(255, 210, 245, 160))
    # 裙边波浪
    wave = []
    for i in range(0, 61):
        x = cx - 0.30 + i * 0.01
        wave.append((x, cy + 0.05 + math.sin(i * 1.1) * 0.018))
    d.line([(x * W, y * W) for x, y in wave], fill=(255, 190, 240, 220), width=int(0.016 * W), joint="curve")
    # 触须：渐变波浪线
    for k, (x0, amp, phase, col) in enumerate([
        (0.36, 0.030, 0.0, (140, 160, 255, 220)),
        (0.44, 0.038, 1.2, (180, 140, 255, 210)),
        (0.52, 0.034, 2.4, (255, 150, 210, 220)),
        (0.60, 0.042, 3.6, (130, 200, 255, 210)),
        (0.66, 0.030, 4.8, (170, 160, 255, 200)),
    ]):
        pts = []
        for i in range(41):
            t = i / 40.0
            y = cy + 0.06 + t * 0.42
            x = x0 + math.sin(t * 7 + phase) * amp * t
            pts.append((x, y))
        d.line([(x * W, y * W) for x, y in pts], fill=col, width=int(0.013 * W), joint="curve")
    # 发光点
    for x, y, r in [(0.40, 0.30, 0.014), (0.54, 0.26, 0.011), (0.47, 0.55, 0.012), (0.58, 0.66, 0.010), (0.42, 0.72, 0.009)]:
        d.ellipse([(x - r * 2.4) * W, (y - r * 2.4) * W, (x + r * 2.4) * W, (y + r * 2.4) * W], fill=(255, 190, 250, 70))
        d.ellipse([(x - r) * W, (y - r) * W, (x + r) * W, (y + r) * W], fill=(255, 235, 252, 235))
    save(img, "neon_jelly")

whale(); star_cat(); origami_fox(); gear_snail(); neon_jelly()
print("done")
