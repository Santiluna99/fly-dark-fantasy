import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(31)
reset()
ST = (.36, .37, .4); STD = (.22, .22, .25); RED = (.32, .07, .07)
N = {"hip": (0, 0, .97, .16, .11), "chest": (0, 0, 1.33, .2, .12), "neck": (0, 0, 1.52, .06, .06), "head": (0, .01, 1.64, .06, .06)}
mirror(N, "sh", .25, 0, 1.45, .07, .07); mirror(N, "el", .33, .02, 1.17, .055, .055); mirror(N, "ha", .35, .06, .9, .05, .05)
mirror(N, "hj", .11, 0, .94, .09, .09); mirror(N, "kn", .11, .04, .52, .07, .07); mirror(N, "an", .11, 0, .1, .055, .055); mirror(N, "to", .11, .11, .045, .055, .07)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
body = skin_body("k_body", N, E, sub=1, fn=lambda p: (.17, .15, .14) if p.z < 1.5 else STD, amp=.006)   # cota de malla oscura debajo
P = []
# peto con quilla, faldón de placas, hombreras, brazales, grebas, guanteletes
P.append(blob("peto", (0, .01, 1.33), (.215, .14, .21), col=ST, amp=.01))
P.append(slab("quilla", (0, .14, 1.33), (.03, .03, .34), (-8, 0, 0), col=(.45, .45, .5), bev=.008))
P.append(tube("faldon", (0, 0, 1.08), (0, 0, .72), .2, .25, 10, col=ST, cap=False, amp=.008))
for i in range(4):
    P.append(tube(f"plc{i}", (0, 0, 1.06 - i * .1), (0, 0, .97 - i * .1), .2 + i * .014, .21 + i * .014, 10, col=tuple(x * (1.1 - i * .06) for x in ST), cap=False, amp=0))
for s, b in (("l", "arm_l"), ("r", "arm_r")):
    sg = -1 if s == "l" else 1
    P.append(blob(f"hombrera{s}", (sg * .27, 0, 1.46), (.12, .11, .09), bone=b, col=ST, amp=.01))
    P.append(blob(f"hombrera2{s}", (sg * .28, 0, 1.5), (.09, .09, .05), bone=b, col=(.4, .4, .43)))
    P.append(tube(f"brazal{s}", (sg * .3, .02, 1.3), (sg * .33, .03, 1.03), .062, .06, 8, bone=b, col=ST))
    P.append(blob(f"codera{s}", (sg * .33, .0, 1.17), (.065, .07, .07), bone=b, col=(.4, .4, .43)))
    P.append(blob(f"guante{s}", (sg * .35, .06, .9), (.065, .08, .075), bone=b, col=STD))
    lg = f"leg_{s}"
    P.append(tube(f"greba{s}", (sg * .11, .04, .66), (sg * .11, .0, .15), .08, .068, 8, bone=lg, col=ST))
    P.append(blob(f"rodillera{s}", (sg * .11, .06, .52), (.08, .08, .08), bone=lg, col=(.42, .42, .45)))
    P.append(tube(f"muslo{s}", (sg * .11, 0, .92), (sg * .11, .04, .56), .1, .082, 8, bone=lg, col=(.3, .3, .33)))
    P.append(slab(f"bota{s}", (sg * .11, .07, .05), (.12, .27, .09), bone=lg, col=STD))
# capa raída
cape = tube("capa", (0, -.13, 1.5), (0, -.2, .5), .24, .34, 10, col=RED, cap=False, amp=.015)
jag(cape, .8, .16, 9, 1.0)
P.append(cape)
# tabardo frontal
P.append(slab("tabardo", (0, .15, .98), (.22, .02, .5), (-4, 0, 0), col=RED, bev=.006))
P.append(slab("tabardo_c", (0, .165, 1.1), (.07, .01, .46), (-4, 0, 0), col=(.5, .42, .2), bev=.003, amp=0))
# gran yelmo con visera en cruz y penacho
P.append(blob("yelmo", (0, .02, 1.7), (.125, .14, .15), bone="head", col=ST, amp=.006))
P.append(blob("yelmo2", (0, -.0, 1.76), (.115, .13, .1), bone="head", col=(.4, .4, .43)))
P.append(slab("visera_h", (0, .13, 1.69), (.16, .03, .028), bone="head", col=(.02, .02, .025), bev=.004, amp=0, emit=True))
P.append(slab("visera_v", (0, .135, 1.64), (.03, .03, .16), bone="head", col=(.02, .02, .025), bev=.004, amp=0, emit=True))
for sx in (-1, 1):
    P.append(blob(f"ojo{sx}", (sx * .04, .14, 1.69), (.014, .008, .01), bone="head", col=(.6, .9, .85), emit=True))
P.append(blob("penacho", (0, -.02, 1.86), (.03, .14, .09), (-20, 0, 0), bone="head", col=RED, amp=.008))
P.append(tube("gola", (0, 0, 1.5), (0, 0, 1.58), .1, .08, 10, bone="head", col=STD, cap=False, amp=0))
# espada (brazo derecho) y escudo (brazo izquierdo)
P.append(slab("hoja", (.35, .36, .88), (.05, .85, .012), (-8, 0, 0), bone="arm_r", col=(.55, .55, .58), bev=.004))
P.append(slab("guarda", (.35, .06, .92), (.24, .04, .035), bone="arm_r", col=(.35, .3, .2)))
P.append(tube("empu", (.35, .02, .9), (.35, -.1, .88), .02, .02, 6, bone="arm_r", col=(.15, .1, .07)))
P.append(blob("pomo", (.35, -.11, .88), (.03, .03, .03), bone="arm_r", col=(.4, .35, .2)))
sh = blob("escudo", (-.43, .12, 1.05), (.04, .3, .4), (0, 0, 0), bone="arm_l", col=(.3, .06, .06), amp=.01)
P.append(sh)
P.append(blob("escudo_b", (-.46, .14, 1.05), (.03, .1, .1), bone="arm_l", col=(.5, .5, .55)))
P.append(slab("escudo_v", (-.46, .13, 1.05), (.025, .04, .5), bone="arm_l", col=(.45, .37, .18), bev=.003, amp=0))
B = std_bones({"hip": (0, 0, .97), "neck": (0, 0, 1.52), "headtop": (0, 0, 1.9), "sh_l": (-.25, 0, 1.45), "sh_r": (.25, 0, 1.45),
               "hand_l": (-.35, .06, .9), "hand_r": (.35, .06, .9), "hipj_l": (-.11, 0, .94), "hipj_r": (.11, 0, .94), "foot_l": (-.11, 0, .06), "foot_r": (.11, 0, .06)})
export("mob_knight", body, P, B, std_anims(.5, .3))
