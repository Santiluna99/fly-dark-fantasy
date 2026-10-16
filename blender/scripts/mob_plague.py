import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
random.seed(81)
reset()
RB = (.06, .055, .06); LE = (.2, .14, .09); BEAK = (.46, .4, .3)
N = {"hip": (0, 0, .95, .14, .1), "chest": (0, 0, 1.32, .16, .1), "neck": (0, 0, 1.5, .05, .05), "head": (0, .02, 1.62, .06, .06)}
mirror(N, "sh", .22, 0, 1.43, .055, .055); mirror(N, "el", .3, .03, 1.15, .045, .045); mirror(N, "ha", .33, .08, .9, .042, .042)
mirror(N, "hj", .1, 0, .92, .075, .075); mirror(N, "kn", .1, .03, .5, .055, .055); mirror(N, "an", .1, 0, .1, .045, .045); mirror(N, "to", .1, .09, .04, .045, .055)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
body = skin_body("p_body", N, E, sub=1, fn=lambda p: LE if (p.z < .15 or (abs(p.x) > .29 and p.z < 1.05)) else RB, amp=.008)
P = []
coat = tube("abrigo", (0, 0, 1.45), (0, 0, .3), .22, .42, 14, col=RB, cap=False, amp=.02)
P.append(jag(coat, .45, .12, 8, 1.0))
P.append(blob("hombros", (0, 0, 1.46), (.28, .15, .09), col=(.08, .075, .08), amp=.012))
P.append(tube("cinto", (0, 0, 1.05), (0, 0, 1.1), .2, .2, 12, col=LE, cap=False, amp=0))
P.append(slab("hebilla", (0, .2, 1.07), (.05, .02, .05), col=(.55, .45, .2), bev=.004, amp=0))
for sx, nm in ((-1, "a"), (1, "b")):
    P.append(blob(f"bolsa{nm}", (sx * .22, .1, .98), (.06, .05, .08), col=LE))
for s, b in (("l", "arm_l"), ("r", "arm_r")):
    sg = -1 if s == "l" else 1
    P.append(tube(f"manga{s}", (sg * .25, 0, 1.43), (sg * .32, .05, .95), .075, .095, 8, bone=b, col=RB, cap=False, amp=.01))
    P.append(blob(f"guante{s}", (sg * .33, .08, .88), (.05, .065, .06), bone=b, col=LE))
# capucha + máscara de pico + lentes + sombrero ancho
hc = V((0, .03, 1.68))
P.append(blob("capucha", hc, (.115, .125, .13), bone="head", col=RB, amp=.006))
P.append(blob("mascara", hc + V((0, .07, -.01)), (.08, .08, .1), bone="head", col=BEAK, amp=.005))
P.append(tube("pico", hc + V((0, .1, -.02)), hc + V((0, .42, -.12)), .055, .008, 8, bone="head", col=BEAK, amp=.004))
P.append(tube("pico2", hc + V((0, .12, -.05)), hc + V((0, .3, -.13)), .04, .01, 8, bone="head", col=(.38, .33, .25), amp=.003))
for sx in (-1, 1):
    P.append(tube(f"aro{sx}", hc + V((sx * .05, .115, .03)), hc + V((sx * .05, .13, .03)), .036, .036, 10, bone="head", col=(.2, .16, .1), cap=False, amp=0))
    P.append(blob(f"lente{sx}", hc + V((sx * .05, .123, .03)), (.028, .01, .028), bone="head", col=(1.0, .62, .15), emit=True))
P.append(tube("ala", hc + V((0, 0, .09)), hc + V((0, 0, .11)), .24, .22, 14, bone="head", col=RB, amp=.01))
P.append(tube("copa", hc + V((0, 0, .11)), hc + V((0, 0, .27)), .115, .09, 12, bone="head", col=RB, amp=.006))
P.append(tube("cinta", hc + V((0, 0, .115)), hc + V((0, 0, .15)), .118, .118, 12, bone="head", col=LE, cap=False, amp=0))
# bastón con farol encendido
P.append(tube("baston", (.35, .1, 1.75), (.35, .1, .0), .018, .022, 6, bone="arm_r", col=(.22, .15, .09)))
P.append(tube("gancho", (.35, .1, 1.75), (.35, .22, 1.7), .014, .014, 6, bone="arm_r", col=(.2, .13, .08)))
P.append(blob("farol", (.35, .22, 1.58), (.05, .05, .07), bone="arm_r", col=(1.0, .62, .2), emit=True))
P.append(tube("farolm", (.35, .22, 1.67), (.35, .22, 1.5), .06, .06, 6, bone="arm_r", col=(.15, .1, .06), cap=False, amp=0))
B = std_bones({"hip": (0, 0, .95), "neck": (0, 0, 1.5), "headtop": (0, 0, 1.95), "sh_l": (-.22, 0, 1.43), "sh_r": (.22, 0, 1.43),
               "hand_l": (-.33, .08, .9), "hand_r": (.33, .08, .9), "hipj_l": (-.1, 0, .92), "hipj_r": (.1, 0, .92), "foot_l": (-.1, 0, .06), "foot_r": (.1, 0, .06)})
export("mob_plague", body, P, B, std_anims(.5, .3))
