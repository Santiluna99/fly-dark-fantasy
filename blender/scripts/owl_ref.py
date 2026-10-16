# Mago Buho ajustado a la hoja. Cuerpo = casco por silueta frontal (sin chispas doradas) con profundidad por proporcion
# (la hoja no trae perfil puro); cabeza esculpida head_owl.mdl; libro, chispas y garras anadidos. Exporta out/buho_ref.glb/.blend
import sys; sys.path.insert(0,"/home/claude/blender")
from charlib import *
H=2.5
img=load("buho_vistas.png"); bg=np.array([16.,17.,21.])
# imagen para mascara: los pixeles amarillos/dorados (chispas, libro, ojos) se tratan como fondo
Rr,Gg,Bb=img[...,0],img[...,1],img[...,2]
yel=ndi.binary_dilation((Rr>0.45)&(Gg>0.3)&(Bb<0.35),iterations=6)
mimg=img.copy(); mimg[yel]=bg/255.0
vs=masks(mimg,bg,24,[(0,470),(480,760),(780,1100),(1090,1440)])
F=View(img,vs[0],H); Bk=View(img,vs[2],H)
cxF=(F.x0+F.x1)/2; cxB=(Bk.x0+Bk.x1)/2
print("front",F.x0,F.x1,F.y0,F.y1)
zt=lambda py:(F.y1-py)*F.sc
res=0.05
G,xs,ys,zs=hull(F,None,H,cxF,0,res=res,depth_ratio=0.62,pow_=2.4,zmax=zt(236))
V,Fc=mesh_from_grid(G,xs,ys,zs,res,smooth=2)
Fc=[(a,c,b) for a,b,c in Fc]
N=normals(V,Fc)
proj=Proj(F,Bk,None,cxF,cxB,0,gain=1.0)
col=np.clip(proj(V,N),0,1)
# El libro y el brillo dorado del frente se cuelan en la proyeccion: se sustituye por azul de tunica donde el pixel es dorado
gold=(col.max(1)<0.13)|((col[:,0]>0.10)&(col[:,0]>col[:,2]*0.8))|((col[:,0]>0.30)&(col[:,1]>0.25))
nz=ndi.gaussian_filter(np.random.default_rng(1).random(len(col)),1.0)
col[gold]=np.array([0.10,0.20,0.62])[None,:]*(0.55+0.9*np.random.default_rng(2).random(int(gold.sum())))[:,None]
col=np.clip(col,0,1)**2.2   # sRGB -> lineal (Godot/Blender)
def bone_of(c):
    x,y,z=c; r=z/H
    if r>0.72 and abs(x)<0.3: return "spine"
    if abs(x)>0.28 and 0.40<r<=0.82: return "arm_l" if x<0 else "arm_r"
    return "spine"
bpy.ops.wm.read_factory_settings(use_empty=True)
P=split_by_bone(V,Fc,col,bone_of,"buho")

# ---- cabeza esculpida ----
def load_head():
    MDL="/mnt/user-data/outputs/nocturnia/assets/models/head_owl.mdl"
    Vv=[];Ff=[]
    for l in open(MDL):
        p=l.split()
        if p and p[0]=='v': Vv.append(list(map(float,p[1:4])))
        elif p and p[0]=='f': Ff.append([int(i)-1 for i in p[1:4]])
    Vv=np.array(Vv); B=np.stack([Vv[:,0],-Vv[:,2],Vv[:,1]],1); Ff=[(a,c,b) for a,b,c in Ff]
    mn=B.min(0);mx=B.max(0)
    hh=(zt(82)-zt(245)); ww=(320-155)*F.sc; dd=ww*0.95
    s=np.array([ww/(mx[0]-mn[0]),dd/(mx[1]-mn[1]),hh/(mx[2]-mn[2])])
    B=(B-(mn+mx)/2)*s+np.array([0,0.02,(zt(82)+zt(245))/2])
    return B,Ff
HV,HF=load_head(); HN=normals(HV,HF)
hc=np.clip(proj(HV,HN),0,1)**2.2
# la cabeza sculpt ya trae colores propios; se mezcla con la proyeccion para dar el plumaje blanco-gris de la hoja
own=np.zeros_like(HV)
for i,l in enumerate([l for l in open("/mnt/user-data/outputs/nocturnia/assets/models/head_owl.mdl") if l.startswith('v ')]):
    own[i]=list(map(float,l.split()[4:7]))
P.append(mk("cabeza",HV,HF,np.clip(0.85*hc+0.15*own**2.2,0,1)*1.35,"head"))
# ojos naranjas brillantes
HVa=np.array(HV)
for sx in (-1,1):
    ex=sx*34*F.sc; ez=zt(167)
    near=HVa[(abs(HVa[:,0]-ex)<0.04)&(abs(HVa[:,2]-ez)<0.04)]
    ey=near[:,1].max()-0.005 if len(near) else 0.2
    P.append(eye_sphere(f"ojo{sx}",(ex,ey,ez),0.05,(1.0,0.55,0.05),(1.0,0.35,1.0)))
# ---- libro dorado abierto delante del pecho ----
bw=(350-140)*F.sc
def slab(name,x0,x1,tilt):
    """Pagina del libro: losa fina inclinada hacia el lector."""
    y_lo=0.34; z_lo=zt(418); y_hi=0.20; z_hi=zt(338); t=0.035
    Vq=[(x0,y_lo,z_lo),(x1,y_lo-tilt,z_lo),(x1,y_hi-tilt,z_hi),(x0,y_hi,z_hi)]
    Vq=Vq+[(x,y,z+t) for x,y,z in Vq]
    Fq=[(0,2,1),(0,3,2),(4,5,6),(4,6,7),(0,1,5),(0,5,4),(1,2,6),(1,6,5),(2,3,7),(2,7,6),(3,0,4),(3,4,7)]
    return mk(name,Vq,Fq,[(0.30,0.15,0.015)]*8,"arm_r")
P.append(slab("libro_izq",-bw/2,0.0,0.05)); P.append(slab("libro_der",0.0,bw/2,0.05))
bk=None
# chispas doradas
rng=np.random.default_rng(3)
for i,(px,py) in enumerate([(60,325),(85,395),(425,222),(395,300),(365,310),(390,448),(150,330),(330,320)]):
    P.append(eye_sphere(f"chispa{i}",((px-cxF)*F.sc,0.2,zt(py)),0.025,(1.0,0.8,0.15),(1,1,1),"spine"))
# ---- garras (pies) ----
for sx in (-1,1):
    P.append(foot_mesh(f"pie{sx}",sx*80*F.sc,0.14,0.16,0.28,0.06,(0.33,0.27,0.22)))
    for i in range(3): P.append(claw(f"garra{sx}{i}",sx*80*F.sc+(i-1)*0.06,0.12+0.2,0.02,0.12,0.015,(0.4,0.22,0.1)))
B={"root":((0,0,0),(0,0,0.5),None),"spine":((0,0,0.5),(0,0,zt(236)),"root"),"head":((0,0,zt(236)),(0,0,H),"spine"),
   "arm_l":((-0.45,0,zt(260)),(-0.5,0.3,zt(420)),"spine"),"arm_r":((0.45,0,zt(260)),(0.5,0.3,zt(420)),"spine")}
A={"idle":{1:{"spine":(0,0,0),"head":(0,0,0)},30:{"spine":(0.03,0,0),"head":(-0.05,0.04,0)},60:{"spine":(0,0,0),"head":(0,0,0)}},
   "walk":{1:{"root":(0,0,0.05),"arm_l":(-0.3,0,0),"arm_r":(0.1,0,0)},15:{"root":(0,0,-0.05),"arm_l":(0.3,0,0),"arm_r":(-0.1,0,0)},30:{"root":(0,0,0.05),"arm_l":(-0.3,0,0),"arm_r":(0.1,0,0)}},
   "attack":{1:{"arm_r":(0,0,0)},8:{"arm_r":(-1.4,0,0)},16:{"arm_r":(0.3,0,0)},24:{"arm_r":(0,0,0)}}}
finish(P,B,A,"buho_ref",H)
print("LISTO")
