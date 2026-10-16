# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(51)
reset()
ROBE = (.1, .14, .36); ROBE2 = (.07, .1, .26); FUR = (.55, .52, .46); TRIM = (.5, .4, .17)
N = {"hip": (0, 0, .95, .14, .1), "chest": (0, 0, 1.3, .16, .1), "neck": (0, .02, 1.5, .06, .06), "head": (0, .06, 1.62, .06, .06)}
mirror(N, "sh", .22, 0, 1.43, .055, .055); mirror(N, "el", .3, .03, 1.15, .045, .045); mirror(N, "ha", .32, .08, .9, .04, .04)
mirror(N, "hj", .1, 0, .9, .07, .07); mirror(N, "kn", .1, .03, .5, .05, .05); mirror(N, "an", .1, 0, .1, .04, .04); mirror(N, "to", .1, .08, .04, .04, .05)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
body = skin_body("c_body", N, E, sub=1, fn=lambda p: ROBE if p.z > .15 and p.z < 1.52 and abs(p.x) < .27 else ((.2, .17, .14) if p.z < .15 else FUR), amp=.008)
P = []
rb = tube("tunica", (0, 0, 1.45), (0, 0, .08), .21, .46, 14, col=ROBE, cap=False, amp=.02)
P.append(jag(rb, .22, .08, 7, 1.0))
P.append(tube("cintur", (0, 0, 1.08), (0, 0, 1.12), .2, .2, 12, col=TRIM, cap=False, amp=0))
P.append(blob("hombros", (0, 0, 1.45), (.27, .14, .08), col=ROBE, amp=.01))
for s, b in (("l", "arm_l"), ("r", "arm_r")):
    sg = -1 if s == "l" else 1
    P.append(tube(f"manga{s}", (sg * .25, 0, 1.42), (sg * .31, .05, .95), .08, .12, 8, bone=b, col=ROBE, cap=False, amp=.01))
    P.append(blob(f"mano{s}", (sg * .32, .08, .88), (.045, .06, .05), bone=b, col=FUR))
# cabeza de cabra: cráneo, hocico alargado, mandíbula, barba, orejas, cuernos curvos, ojos de pupila horizontal
hc = V((0, .07, 1.7))
P.append(blob("crane", hc, (.095, .12, .11), bone="head", col=FUR, amp=.006))
P.append(blob("hocico", hc + V((0, .14, -.05)), (.06, .13, .06), (12, 0, 0), bone="head", col=tuple(x * 1.05 for x in FUR), amp=.004))
P.append(blob("morro", hc + V((0, .26, -.075)), (.05, .04, .045), bone="head", col=(.25, .2, .2)))
P.append(blob("mandi", hc + V((0, .15, -.1)), (.045, .12, .035), (8, 0, 0), bone="head", col=tuple(x * .9 for x in FUR)))
P.append(tube("barba", hc + V((0, .2, -.12)), hc + V((0, .15, -.34)), .03, .004, 6, bone="head", col=(.6, .57, .5)))
for sx in (-1, 1):
    P.append(blob(f"orej{sx}", hc + V((sx * .13, -.03, .0)), (.08, .03, .035), (0, 0, sx * 12), bone="head", col=FUR))
    pts = [(.05, -.01, .09), (.1, -.05, .2), (.14, -.12, .3), (.12, -.2, .36), (.07, -.22, .34)]
    for i in range(len(pts) - 1):
        a, bb = pts[i], pts[i + 1]
        P.append(tube(f"cuerno{sx}{i}", hc + V((sx * a[0], a[1], a[2])), hc + V((sx * bb[0], bb[1], bb[2])), .035 - i * .007, .03 - i * .007, 7, bone="head", col=(.35, .3, .22), amp=.003))
    P.append(blob(f"ojo{sx}", hc + V((sx * .06, .1, .035)), (.025, .012, .02), bone="head", col=(1.0, .8, .2), emit=True))
    P.append(blob(f"pup{sx}", hc + V((sx * .06, .112, .035)), (.02, .004, .004), bone="head", col=(.02, .02, .02), emit=True))
# bastón con luna creciente
P.append(tube("baston", (.33, .1, 1.7), (.33, .1, -.0), .018, .022, 6, bone="arm_r", col=(.22, .15, .09)))
for i in range(6):
    a = math.radians(-60 + i * 24)
    P.append(blob(f"luna{i}", V((.33, .1, 1.78)) + V((math.sin(a) * .09, 0, math.cos(a) * .09 - .06)), (.022, .022, .022), bone="arm_r", col=(.8, .78, .6), emit=True))
B = std_bones({"hip": (0, 0, .95), "neck": (0, .02, 1.5), "headtop": (0, .06, 1.85), "sh_l": (-.22, 0, 1.43), "sh_r": (.22, 0, 1.43),
               "hand_l": (-.32, .08, .9), "hand_r": (.32, .08, .9), "hipj_l": (-.1, 0, .9), "hipj_r": (.1, 0, .9), "foot_l": (-.1, 0, .06), "foot_r": (.1, 0, .06)})
export("mob_goat", body, P, B, std_anims(.45, .3))
