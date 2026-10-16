import sys; sys.path.insert(0, "/home/claude/blender")
from mobgen import *
# Aldeano (3 variantes de paleta/peinado). Uso: python mob_human.py N
IDX = int(sys.argv[-1]) if sys.argv[-1].isdigit() else 0
random.seed(20 + IDX)
reset()
PAL = [dict(tun=(.3, .26, .2), pan=(.2, .17, .13), skin=(.66, .53, .43), hair=(.14, .1, .07), sh=(.34, .3, .24), hat="cap"),
       dict(tun=(.26, .31, .25), pan=(.24, .19, .14), skin=(.54, .42, .34), hair=(.5, .4, .28), sh=(.3, .24, .17), hat="hood"),
       dict(tun=(.4, .22, .19), pan=(.18, .17, .15), skin=(.74, .62, .52), hair=(.55, .53, .48), sh=(.22, .2, .17), hat="straw")][IDX]
N = {"hip": (0, 0, .95, .15, .1), "chest": (0, 0, 1.3, .17, .1), "neck": (0, 0, 1.5, .05, .05), "head": (0, .01, 1.62, .06, .06)}
mirror(N, "sh", .22, 0, 1.43, .06, .06); mirror(N, "el", .3, .02, 1.15, .045, .045); mirror(N, "ha", .33, .05, .88, .04, .04)
mirror(N, "hj", .1, 0, .92, .085, .085); mirror(N, "kn", .1, .03, .5, .06, .06); mirror(N, "an", .1, 0, .1, .05, .05); mirror(N, "to", .1, .1, .04, .05, .06)
E = [("hip", "chest"), ("chest", "neck"), ("neck", "head"), ("hip", "hj_l"), ("hip", "hj_r"), ("chest", "sh_l"), ("chest", "sh_r")]
for s in "lr":
    E += [(f"sh_{s}", f"el_{s}"), (f"el_{s}", f"ha_{s}"), (f"hj_{s}", f"kn_{s}"), (f"kn_{s}", f"an_{s}"), (f"an_{s}", f"to_{s}")]
def reg(p):
    if p.z < .13: return (.12, .09, .07)          # botas
    if p.z < .95 and abs(p.x) < .25: return PAL["pan"]
    if p.z > 1.55: return PAL["skin"]
    if abs(p.x) > .27 and p.z < 1.1: return PAL["skin"]   # manos
    return PAL["tun"]
body = skin_body("h_body", N, E, sub=1, fn=reg, amp=.008)
P = []
human_head(P, (0, .03, 1.68), PAL["skin"], PAL["hair"] if PAL["hat"] != "hood" else None, scale=1.0)
# túnica larga hasta medio muslo, cinturón y bolsa
P.append(jag(tube("tunica", (0, 0, 1.0), (0, 0, .62), .21, .26, 12, col=PAL["tun"], cap=False, amp=.01), .72, .06, 7, 1.0))
P.append(tube("cinto", (0, 0, 1.02), (0, 0, 1.06), .19, .19, 12, col=(.16, .1, .06), cap=False, amp=0))
P.append(blob("bolsa", (.2, .05, .9), (.07, .05, .08), col=(.22, .15, .09)))
P.append(blob("cuello", (0, .03, 1.5), (.09, .09, .03), col=tuple(x * .85 for x in PAL["tun"])))
if PAL["hat"] == "hood":
    P.append(blob("capucha", (0, -.01, 1.7), (.12, .13, .12), bone="head", col=PAL["tun"], amp=.008))
    P.append(blob("capuchon", (0, .02, 1.56), (.17, .15, .06), bone="spine", col=PAL["tun"]))
elif PAL["hat"] == "straw":
    P.append(tube("ala", (0, .02, 1.77), (0, .02, 1.79), .21, .2, 12, bone="head", col=(.45, .38, .2)))
    P.append(tube("copa", (0, .02, 1.79), (0, .02, 1.86), .1, .085, 10, bone="head", col=(.42, .35, .18)))
else:
    P.append(blob("gorro", (0, -.01, 1.75), (.1, .11, .06), bone="head", col=(.3, .22, .15)))
B = std_bones({"hip": (0, 0, .95), "neck": (0, 0, 1.5), "headtop": (0, 0, 1.8), "sh_l": (-.22, 0, 1.43), "sh_r": (.22, 0, 1.43),
               "hand_l": (-.33, .05, .88), "hand_r": (.33, .05, .88), "hipj_l": (-.1, 0, .92), "hipj_r": (.1, 0, .92), "foot_l": (-.1, 0, .06), "foot_r": (.1, 0, .06)})
export(f"mob_human_{IDX}", body, P, B, std_anims(.55, .4))
