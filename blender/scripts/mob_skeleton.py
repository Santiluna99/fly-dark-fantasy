# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(11)
reset()
BONE = (.5, .46, .36)
N = {"hip": (0, 0, .93, .07, .05), "chest": (0, 0, 1.3, .045, .035), "neck": (0, .01, 1.5, .035, .035), "head": (0, .02, 1.62, .03, .03)}
mirror(N, "sh", .2, 0, 1.43, .03, .03)
mirror(N, "el", .27, .02, 1.17, .03, .03)
mirror(N, "ha", .3, .08, .93, .028, .028)
mirror(N, "hj", .1, 0, .9, .05, .05)
mirror(N, "kn", .1, .04, .5, .035, .035)
mirror(N, "an", .1, 0, .09, .03, .03)
mirror(N, "to", .1, .1, .03, .03, .04)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
body = skin_body("sk_body", N, E, sub=1, fn=lambda p: BONE, amp=0.006)
P = []
# costillar: anillos que se estrechan + esternón
for i in range(6):
    z = 1.38 - i * .065
    w = .17 - abs(i - 1.5) * .018
    P.append(blob(f"rib{i}", (0, .012, z), (w, .1 - i * .004, .016), seg=12, rings=3, col=BONE))
P.append(slab("estern", (0, .095, 1.28), (.035, .02, .24), col=BONE))
# clavículas y pelvis
P.append(blob("pelvis", (0, 0, .93), (.17, .09, .08), col=BONE.__class__((.6, .56, .45))))
for s in (-1, 1):
    P.append(tube(f"clav{s}", (0, .03, 1.46), (s * .19, 0, 1.43), .018, .018, 6, col=BONE))
# articulaciones: nudillos de hueso
for s, b in (("l", "arm_l"), ("r", "arm_r")):
    sg = -1 if s == "l" else 1
    P.append(blob(f"codo{s}", (sg * .27, .02, 1.17), (.045, .045, .05), bone=b, col=BONE))
    P.append(blob(f"mano{s}", (sg * .3, .08, .9), (.045, .06, .05), bone=b, col=(.6, .56, .45)))
    for t in range(3):
        P.append(tube(f"dedo{s}{t}", (sg * .3 + (t - 1) * .02, .1, .88), (sg * .3 + (t - 1) * .025, .17, .82), .01, .004, 5, bone=b, col=BONE))
    P.append(blob(f"rod{s}", (sg * .1, .04, .5), (.055, .06, .06), bone=f"leg_{s}", col=BONE))
    P.append(slab(f"pie{s}", (sg * .1, .06, .035), (.07, .2, .05), bone=f"leg_{s}", col=(.55, .5, .4)))
# cráneo: cabeza + mandíbula + cuencas + nariz + dientes
SK = (.55, .5, .4)
P.append(blob("craneo", (0, .02, 1.7), (.115, .13, .13), bone="head", col=SK, amp=.006))
P.append(blob("frente", (0, -.01, 1.75), (.1, .11, .09), bone="head", col=SK))
P.append(blob("mand", (0, .05, 1.6), (.075, .075, .035), bone="head", col=(.62, .58, .46)))
for s in (-1, 1):
    P.append(blob(f"cuenca{s}", (s * .05, .12, 1.7), (.037, .03, .042), bone="head", col=(.03, .03, .035), emit=True))
    P.append(blob(f"ojo{s}", (s * .05, .135, 1.7), (.017, .012, .017), bone="head", col=(.45, 1.0, .65), emit=True))
P.append(blob("nariz", (0, .14, 1.64), (.014, .02, .028), bone="head", col=(.04, .04, .04), emit=True))
for t in range(6):
    P.append(blob(f"dte{t}", ((t - 2.5) * .02, .125, 1.585), (.008, .01, .018), bone="head", col=(.8, .78, .66), emit=True))
# harapos de cadera
sk = tube("harapo", (0, 0, .96), (0, 0, .5), .2, .27, 12, bone="spine", col=(.17, .13, .1), cap=False, amp=.012)
jag(sk, .78, .22, 8, 2.0)
P.append(sk)
# espada oxidada en la mano derecha
RU = (.42, .27, .17)
P.append(slab("hoja", (.3, .3, .82), (.045, .6, .012), (-10, 0, 0), bone="arm_r", col=RU))
P.append(slab("guarda", (.3, .02, .88), (.17, .035, .03), bone="arm_r", col=(.3, .22, .15)))
P.append(tube("empu", (.3, 0, .86), (.3, -.06, .85), .016, .016, 6, bone="arm_r", col=(.2, .15, .1)))
B = std_bones({"hip": (0, 0, .93), "neck": (0, 0, 1.5), "headtop": (0, 0, 1.82), "sh_l": (-.2, 0, 1.43), "sh_r": (.2, 0, 1.43),
               "hand_l": (-.3, .08, .9), "hand_r": (.3, .08, .9), "hipj_l": (-.1, 0, .9), "hipj_r": (.1, 0, .9), "foot_l": (-.1, 0, .06), "foot_r": (.1, 0, .06)})
export("mob_skeleton", body, P, B, std_anims(.5, .35))
