import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
IDX = int(sys.argv[-1]) if sys.argv[-1].isdigit() else 0
random.seed(40 + IDX)
reset()
G = [(.34, .4, .2), (.4, .38, .22)][IDX]
CL = [(.25, .17, .1), (.2, .16, .14)][IDX]
N = {"hip": (0, 0, .5, .12, .09), "chest": (0, .05, .72, .13, .09), "neck": (0, .09, .86, .05, .05), "head": (0, .12, .93, .06, .06)}
mirror(N, "sh", .17, .05, .8, .045, .045); mirror(N, "el", .22, .08, .6, .035, .035); mirror(N, "ha", .24, .14, .42, .035, .035)
mirror(N, "hj", .08, 0, .46, .06, .06); mirror(N, "kn", .09, .06, .26, .045, .045); mirror(N, "an", .09, 0, .07, .04, .04); mirror(N, "to", .09, .09, .03, .04, .05)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
body = skin_body("g_body", N, E, sub=1, fn=lambda p: G if p.z > .56 or p.z < .45 else CL, amp=.01)
P = []
hc = V((0, .13, 1.0))
P.append(blob("cabeza", hc, (.12, .12, .115), bone="head", col=G, amp=.008))
P.append(blob("frente", hc + V((0, .06, .05)), (.1, .06, .05), bone="head", col=tuple(x * .85 for x in G)))
P.append(blob("nariz", hc + V((0, .14, -.02)), (.025, .07, .035), (20, 0, 0), bone="head", col=tuple(x * 1.05 for x in G)))
P.append(blob("barbilla", hc + V((0, .09, -.09)), (.05, .05, .035), bone="head", col=G))
P.append(slab("boca", hc + V((0, .1, -.06)), (.1, .02, .015), bone="head", col=(.12, .03, .03), bev=.003, amp=0, emit=True))
for sx in (-1, 1):
    P.append(tube(f"oreja{sx}", hc + V((sx * .1, -.01, .02)), hc + V((sx * .34, -.1, .12)), .045, .006, 6, bone="head", col=G))
    P.append(blob(f"ojb{sx}", hc + V((sx * .05, .105, .035)), (.03, .018, .026), bone="head", col=(.9, .85, .4), emit=True))
    P.append(blob(f"ojp{sx}", hc + V((sx * .05, .12, .035)), (.008, .006, .02), bone="head", col=(.02, .02, .02), emit=True))
    P.append(tube(f"coml{sx}", hc + V((sx * .03, .115, -.075)), hc + V((sx * .035, .125, -.02)), .012, .003, 5, bone="head", col=(.75, .72, .55)))
    P.append(tube(f"garra{sx}", (sx * .24, .15, .4), (sx * .25, .24, .33), .018, .004, 5, bone="arm_l" if sx < 0 else "arm_r", col=(.7, .68, .5)))
P.append(jag(tube("taparrabo", (0, 0, .56), (0, 0, .3), .13, .2, 10, col=CL, cap=False, amp=.01), .4, .08, 8, 1.0))
P.append(tube("cinto", (0, 0, .56), (0, 0, .59), .13, .13, 10, col=(.13, .08, .05), cap=False, amp=0))
P.append(blob("hombro", (0, -.02, .8), (.17, .12, .05), col=CL))
# daga
P.append(slab("daga", (.24, .26, .38), (.03, .26, .008), (-10, 0, 0), bone="arm_r", col=(.4, .34, .3)))
P.append(slab("dag_g", (.24, .14, .4), (.1, .025, .02), bone="arm_r", col=(.2, .13, .08)))
B = std_bones({"hip": (0, 0, .5), "neck": (0, .08, .86), "headtop": (0, .12, 1.1), "sh_l": (-.17, .05, .8), "sh_r": (.17, .05, .8),
               "hand_l": (-.24, .14, .42), "hand_r": (.24, .14, .42), "hipj_l": (-.08, 0, .46), "hipj_r": (.08, 0, .46), "foot_l": (-.09, 0, .05), "foot_r": (.09, 0, .05)})
export(f"mob_goblin_{IDX}", body, P, B, std_anims(.6, .5, hunch=.1))
