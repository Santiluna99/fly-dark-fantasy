# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(71)
reset()
CL = (.07, .09, .11); CL2 = (.05, .06, .08); BONE = (.48, .5, .46)
# sin piernas: flota; los brazos son huesudos y larguísimos
N = {"hip": (0, 0, 1.0, .1, .08), "chest": (0, 0, 1.35, .1, .08), "neck": (0, 0, 1.52, .04, .04), "head": (0, .02, 1.62, .04, .04)}
mirror(N, "sh", .2, 0, 1.45, .035, .035); mirror(N, "el", .3, .12, 1.12, .028, .028); mirror(N, "ha", .34, .26, .85, .025, .025)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}")]
body = skin_body("w_body", N, E, sub=1, fn=lambda p: BONE if abs(p.x) > .26 else CL, amp=.006)
P = []
# capa principal larga y ancha que flota, con jirones a distinta altura
cape = tube("capa", (0, 0, 1.5), (0, 0, .1), .22, .5, 14, bone="spine", col=CL, cap=False, amp=.03)
jag(cape, .55, .4, 9, 1.0)
P.append(cape)
cape2 = tube("capa2", (0, -.06, 1.46), (0, -.12, .02), .26, .56, 14, bone="spine", col=CL2, cap=False, amp=.035)
jag(cape2, .5, .5, 6, 3.0)
P.append(cape2)
for i in range(10):
    a = i / 10.0 * math.tau
    ln = .35 + random.random() * .35
    P.append(tube(f"jiron{i}", (math.sin(a) * .45, math.cos(a) * .4, .45), (math.sin(a) * .55, math.cos(a) * .5, .45 - ln), .09, .008, 5, bone="spine", col=CL2, amp=.01))
P.append(blob("hombros", (0, 0, 1.46), (.3, .15, .1), col=CL, amp=.012))
# capucha con rostro vacío y ojos fríos
hc = V((0, .03, 1.65))
P.append(blob("capucha", hc, (.15, .17, .17), bone="head", col=CL, amp=.01))
P.append(blob("pico", hc + V((0, -.08, .17)), (.09, .1, .15), (-35, 0, 0), bone="head", col=CL, amp=.008))
P.append(blob("vacio", hc + V((0, .1, -.01)), (.1, .08, .12), bone="head", col=(.005, .005, .01), emit=True))
for sx in (-1, 1):
    P.append(blob(f"oj{sx}", hc + V((sx * .045, .16, .02)), (.026, .01, .018), (0, 0, sx * 15), bone="head", col=(.45, 1.0, .85), emit=True))
    b = "arm_l" if sx < 0 else "arm_r"
    P.append(tube(f"manga{sx}", (sx * .22, 0, 1.45), (sx * .32, .12, 1.1), .09, .05, 8, bone=b, col=CL, cap=False, amp=.008))
    P.append(blob(f"mano{sx}", (sx * .34, .27, .82), (.04, .06, .05), bone=b, col=BONE))
    for t in range(4):
        P.append(tube(f"dedo{sx}{t}", (sx * .34 + (t - 1.5) * .02, .3, .8), (sx * .35 + (t - 1.5) * .03, .46, .7), .009, .002, 5, bone=b, col=BONE))
B = std_bones({"hip": (0, 0, 1.0), "neck": (0, 0, 1.52), "headtop": (0, 0, 1.85), "sh_l": (-.2, 0, 1.45), "sh_r": (.2, 0, 1.45),
               "hand_l": (-.34, .26, .85), "hand_r": (.34, .26, .85)})
A = std_anims(0, .3, legs=False)
A["walk"][1]["spine"] = (0.08, 0, 0.04); A["walk"][15]["spine"] = (0.08, 0, -0.04); A["walk"][30]["spine"] = (0.08, 0, 0.04)
export("mob_wraith", body, P, B, A)
