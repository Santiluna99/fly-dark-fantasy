import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(61)
reset()
SK = (.46, .5, .42); SKD = (.3, .33, .28); CLO = (.18, .15, .11)
# encorvado: la columna se inclina hacia delante, los brazos casi arrastran
N = {"hip": (0, -.06, .86, .13, .09), "chest": (0, .12, 1.18, .17, .1), "neck": (0, .3, 1.3, .06, .06), "head": (0, .4, 1.34, .06, .06)}
mirror(N, "sh", .26, .2, 1.28, .06, .06); mirror(N, "el", .33, .3, .9, .05, .05); mirror(N, "ha", .35, .4, .5, .045, .045)
mirror(N, "hj", .11, -.04, .84, .075, .075); mirror(N, "kn", .12, .08, .46, .055, .055); mirror(N, "an", .11, -.02, .09, .045, .045); mirror(N, "to", .11, .08, .03, .045, .05)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
def reg(p):
    if .3 < p.z < .8 and abs(p.x) < .2 and p.y < .2: return CLO if p.z < .7 else SKD
    return SK if p.z > .3 else SKD
body = skin_body("gh_body", N, E, sub=1, fn=reg, amp=.012)
P = []
# espinazo con vértebras visibles y costillas marcadas
for i in range(7):
    t = i / 6.0
    P.append(blob(f"vert{i}", (0, -.04 + t * .27, 1.0 + t * .3), (.025, .03, .03), bone="spine", col=SKD))
for i in range(4):
    for sx in (-1, 1):
        P.append(tube(f"cost{i}{sx}", (sx * .06, .2 + i * .01, 1.28 - i * .07), (sx * .17, .24 + i * .01, 1.2 - i * .07), .014, .01, 5, bone="spine", col=SKD))
# cabeza adelantada: cráneo alargado, mandíbula caída con colmillos, orejas puntiagudas, ojos amarillos hundidos
hc = V((0, .43, 1.36))
P.append(blob("crane", hc, (.1, .12, .1), bone="head", col=SK, amp=.007))
P.append(blob("frente", hc + V((0, .06, .05)), (.095, .07, .05), bone="head", col=SKD))
P.append(blob("mandi", hc + V((0, .09, -.1)), (.075, .09, .05), (-15, 0, 0), bone="head", col=SKD, amp=.006))
P.append(blob("boca", hc + V((0, .1, -.06)), (.06, .08, .02), bone="head", col=(.1, .02, .02), emit=True))
P.append(blob("nariz", hc + V((0, .12, -.01)), (.02, .02, .02), bone="head", col=(.05, .04, .04), emit=True))
for t in range(5):
    x = (t - 2) * .022
    P.append(tube(f"col_s{t}", hc + V((x, .13, -.06)), hc + V((x, .135, -.11)), .01, .002, 4, bone="head", col=(.78, .72, .5)))
    P.append(tube(f"col_i{t}", hc + V((x, .17, -.1)), hc + V((x, .17, -.05)), .01, .002, 4, bone="head", col=(.78, .72, .5)))
for sx in (-1, 1):
    P.append(blob(f"ojh{sx}", hc + V((sx * .05, .095, .025)), (.03, .02, .026), bone="head", col=(.03, .03, .02), emit=True))
    P.append(blob(f"oj{sx}", hc + V((sx * .05, .108, .025)), (.014, .008, .01), bone="head", col=(1.0, .85, .25), emit=True))
    P.append(tube(f"oreja{sx}", hc + V((sx * .09, -.02, .03)), hc + V((sx * .22, -.08, .09)), .03, .004, 5, bone="head", col=SK))
    b = "arm_l" if sx < 0 else "arm_r"
    P.append(blob(f"mano{sx}", (sx * .35, .42, .48), (.055, .07, .07), bone=b, col=SKD))
    for t in range(4):
        P.append(tube(f"garra{sx}{t}", (sx * .35 + (t - 1.5) * .025, .45, .45), (sx * .35 + (t - 1.5) * .03, .54, .36), .012, .002, 5, bone=b, col=(.75, .7, .5)))
# pantalón hecho jirones y trapo en la cintura
for sx in (-1, 1):
    P.append(jag(tube(f"pant{sx}", (sx * .11, -.02, .82), (sx * .12, .08, .42), .1, .085, 8, bone="leg_l" if sx < 0 else "leg_r", col=CLO, cap=False, amp=.008), .55, .06, 6, 1.0 + sx))
P.append(jag(tube("trapo", (0, -.04, .9), (0, -.04, .55), .15, .2, 10, col=(.14, .11, .08), cap=False, amp=.01), .7, .1, 8, 2.0))
B = std_bones({"hip": (0, -.06, .86), "neck": (0, .3, 1.3), "headtop": (0, .45, 1.5), "sh_l": (-.26, .2, 1.28), "sh_r": (.26, .2, 1.28),
               "hand_l": (-.35, .4, .5), "hand_r": (.35, .4, .5), "hipj_l": (-.11, -.04, .84), "hipj_r": (.11, -.04, .84), "foot_l": (-.11, 0, .06), "foot_r": (.11, 0, .06)})
export("mob_ghoul", body, P, B, std_anims(.5, .35))
