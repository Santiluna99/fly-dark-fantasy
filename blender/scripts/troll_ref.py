# Troll de Colina ajustado a la hoja. Exporta out/troll_ref.glb/.blend
import sys; sys.path.insert(0,"/home/claude/blender")
from charlib import *
H=2.8
img=load("troll_vistas.png"); bg=img[5:30,5:30].reshape(-1,3).mean(0)*255; print("bg",bg)
vs=masks(img,bg,22,[(0,545),(545,745),(750,1100)])
F=View(img,vs[0],H); S=View(img,vs[1],H); Bk=View(img,vs[2],H)
print([ (v.x0,v.x1,v.y0,v.y1) for v in (F,S,Bk)])
cxF=(F.x0+F.x1)/2; cxB=(Bk.x0+Bk.x1)/2
# centro de profundidad en la vista lateral: media de la silueta en las filas del torso
rows=range(int(S.y0+0.3*(S.y1-S.y0)),int(S.y0+0.6*(S.y1-S.y0)))
cxS=np.mean([ (S.row_extent(r)[0]+S.row_extent(r)[1])/2 for r in rows])
res=0.055
G,xs,ys,zs=hull(F,S,H,cxF,cxS,res=res,side_dir=-1,pow_=2.4,arm_depth=0.55)
V,Fc=mesh_from_grid(G,xs,ys,zs,res,smooth=2)
print("verts",len(V),"tris",len(Fc))
# la malla de marching cubes tiene la orientacion invertida respecto a Blender: se corrige el orden
Fc=[(a,c,b) for a,b,c in Fc]
N=normals(V,Fc)
proj=Proj(F,Bk,S,cxF,cxB,cxS,side_dir=-1,gain=1.0)
col=np.clip(proj(V,N),0,1)**2.2
def bone_of(c):
    x,y,z=c; r=z/H
    if r>0.80: return "head"
    if r<0.40: return "leg_l" if x<0 else "leg_r"
    if abs(x)>0.30 and 0.38<r<=0.80 and abs(x)>0.28+0.1*(0.8-r): return "arm_l" if x<0 else "arm_r"
    return "spine"
bpy.ops.wm.read_factory_settings(use_empty=True)
P=split_by_bone(V,Fc,col,bone_of,"troll")
# ojos cian brillantes
ez=(F.y1-135)*F.sc
for sx in (-1,1):
    ex=sx*(30)*F.sc*1.0
    near=V[(abs(V[:,0]-ex)<0.05)&(abs(V[:,2]-ez)<0.05)]
    ey=near[:,1].max()-0.005 if len(near) else 0.2
    P.append(eye_sphere(f"ojo{sx}",(ex,ey,ez),0.03,(0.3,1.0,0.9),(1.3,0.4,0.8)))
zt=lambda py:(F.y1-py)*F.sc
B={"root":((0,0,0),(0,0,0.9),None),"spine":((0,0,0.9),(0,0,zt(150)),"root"),"head":((0,0,zt(150)),(0,0,H),"spine"),
   "arm_l":((-0.5,0,zt(190)),(-0.7,0.1,zt(480)),"spine"),"arm_r":((0.5,0,zt(190)),(0.7,0.1,zt(480)),"spine"),
   "leg_l":((-0.3,0,0.9),(-0.3,0,0),"root"),"leg_r":((0.3,0,0.9),(0.3,0,0),"root")}
s_=0.5
A={"idle":{1:{"spine":(0,0,0)},30:{"spine":(0.03,0,0),"head":(0.03,0,0)},60:{"spine":(0,0,0),"head":(0,0,0)}},
   "walk":{1:{"leg_l":(s_,0,0),"leg_r":(-s_,0,0),"arm_l":(-s_*.6,0,0),"arm_r":(s_*.6,0,0)},15:{"leg_l":(-s_,0,0),"leg_r":(s_,0,0),"arm_l":(s_*.6,0,0),"arm_r":(-s_*.6,0,0)},30:{"leg_l":(s_,0,0),"leg_r":(-s_,0,0),"arm_l":(-s_*.6,0,0),"arm_r":(s_*.6,0,0)}},
   "attack":{1:{"arm_r":(0,0,0)},8:{"arm_r":(-1.8,0,0)},16:{"arm_r":(0.4,0,0)},24:{"arm_r":(0,0,0)}}}
finish(P,B,A,"troll_ref",H)
print("LISTO")
