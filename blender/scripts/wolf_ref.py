# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
# Lobo Hechicero ajustado a la hoja de personajes. Exporta out/lobo_ref.glb
import sys; sys.path.insert(0,"/home/claude/blender")
from fit import *
H=2.6
img=load("lobo_vistas.png")
vs=masks(img,np.array([16,17,21.]),18,[(0,470),(500,750),(750,1140)])
F=View(img,vs[0],H); S=View(img,vs[1],H); Bk=View(img,vs[2],H)
cxF=(F.x0+F.x1)/2; cxB=(Bk.x0+Bk.x1)/2; cxS=616.0
zF=lambda py:(F.y1-py)*F.sc            # fila frontal -> altura en metros
sm=lambda a,s=2.0: ndi.gaussian_filter1d(a,s,mode='nearest')

# ---------- 1. perfil del cuerpo (anillos) ----------
NR=64; SEG=32
zs=np.linspace(0.03,zF(185),NR)
hw=np.zeros(NR); yb=np.zeros(NR); yf=np.zeros(NR)
for i,z in enumerate(zs):
    a,b=F.row_extent(F.z_to_row(z)); hw[i]=(b-a)/2*F.sc
    a,b=S.row_extent(S.z_to_row(z)); yb[i]=(a-cxS)*S.sc; yf[i]=(b-cxS)*S.sc
# quitar manos del ancho: entre filas 440 y 548 se usa el ancho de la tunica a la fila 548
r548=int(np.argmin(abs(F.z_to_row(zs)-548)))
for i in range(NR):
    if 440<=F.z_to_row(zs[i])<=548: hw[i]=min(hw[i],hw[r548])
hw=sm(hw,1.5); yb=sm(yb,2); yf=sm(yf,2)
yf=np.minimum(yf,yb+0.48)
# remata los hombros: los ultimos anillos se estrechan hacia el cuello
for k in range(7):
    f=1-0.5*((k+1)/7)**1.5; i=NR-7+k; hw[i]*=f; cy_=(yf[i]+yb[i])/2; hd=(yf[i]-yb[i])/2*f; yf[i]=cy_+hd; yb[i]=cy_-hd   # recorta el hocico que asoma en la silueta lateral
print("anchura max",hw.max()*2,"prof max",(yf-yb).max())

# ---------- 2. malla del cuerpo ----------
def build_body():
    V=[];Fc=[]
    for i,z in enumerate(zs):
        ay=(yf[i]-yb[i])/2; cy=(yf[i]+yb[i])/2; ax=hw[i]
        for s in range(SEG):
            a=2*math.pi*s/SEG; c=math.cos(a); sn=math.sin(a); e=2/2.6
            x=ax*np.sign(c)*abs(c)**e; y=cy+ay*np.sign(sn)*abs(sn)**e
            V.append((x,y,z))
    for i in range(NR-1):
        for s in range(SEG):
            a=i*SEG+s; b=i*SEG+(s+1)%SEG; Fc.append((a,a+SEG,b+SEG,b))
    V.append((0,(yf[0]+yb[0])/2,zs[0])); V.append((0,(yf[-1]+yb[-1])/2,zs[-1]+0.04))
    t=(NR-1)*SEG
    for s in range(SEG):
        Fc.append((len(V)-2,(s+1)%SEG,s)); Fc.append((len(V)-1,t+s,t+(s+1)%SEG))
    return V,Fc

# ---------- 3. proyeccion de color ----------
def project(P,N):
    """Color por vertice: mezcla de frente/espalda/lado segun la normal. P en metros (x der, y adelante, z arriba)."""
    P=np.asarray(P);N=np.asarray(N)
    cf=cxF+P[:,0]*1.0/F.sc; rf=F.y1-P[:,2]/F.sc
    cb=cxB-P[:,0]/Bk.sc; rb=Bk.y1-P[:,2]/Bk.sc
    # lado: mira a la derecha (adelante=+y). La cara -x se toma como espejo de la +x (simetria).
    cs=cxS+P[:,1]/S.sc; rs=S.y1-P[:,2]/S.sc
    Cf=F.sample(cf,rf); Cb=Bk.sample(cb,rb); Cs=S.sample(cs,rs)
    wf=np.clip(N[:,1],0,1)**2; wb=np.clip(-N[:,1],0,1)**2; ws=np.abs(N[:,0])**2*1.3
    w=wf+wb+ws+1e-6
    C=(Cf*wf[:,None]+Cb*wb[:,None]+Cs*ws[:,None])/w[:,None]
    return np.clip(C*0.95,0,1)**2.2

def normals(V,Fc):
    V=np.array(V);N=np.zeros_like(V)
    for f in Fc:
        a,b,c=f[0],f[1],f[2]
        n=np.cross(V[b]-V[a],V[c]-V[a]); N[a]+=n;N[b]+=n;N[c]+=n
    l=np.linalg.norm(N,axis=1,keepdims=True)+1e-9; return N/l

def mk(name,V,Fc,col=None,bone="spine",smooth=False):
    me=bpy.data.meshes.new(name); me.from_pydata([tuple(map(float,v)) for v in V],[],[tuple(map(int,f)) for f in Fc]); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth=smooth
    if col is not None:
        ca=me.color_attributes.new("Col",'FLOAT_COLOR','POINT')
        for i,c in enumerate(col): ca.data[i].color=(float(c[0]),float(c[1]),float(c[2]),1)
    o["bone"]=bone; return o

def load_head():
    """Cabeza esculpida .mdl -> escalada por eje a las medidas de la cabeza en la hoja."""
    MDL="/mnt/user-data/outputs/hollowfly/assets/models/head_wolf.mdl"
    V=[];Fc=[]
    for l in open(MDL):
        p=l.split()
        if p and p[0]=='v': V.append(list(map(float,p[1:4])))
        elif p and p[0]=='f': Fc.append([int(i)-1 for i in p[1:4]])
    V=np.array(V)
    # Godot (y arriba, adelante -z) -> Blender (z arriba, adelante +y)
    B=np.stack([V[:,0],-V[:,2],V[:,1]],1)
    Fc=[(a,c,b) for a,b,c in Fc]
    mn=B.min(0);mx=B.max(0)
    # medidas de la cabeza en la hoja (px frontal): orejas arriba fila 18, barbilla fila 232; ancho 170..300; profundidad lateral 590..725
    hh=(zF(18)-zF(232))*1.18; ww=(300-170)*F.sc*1.3; dd=(725-590)*S.sc*1.3
    s=np.array([ww/(mx[0]-mn[0]), dd/(mx[1]-mn[1]), hh/(mx[2]-mn[2])])
    B=(B-(mn+mx)/2)*s
    cx=0.0; cy=((725+590)/2-cxS)*S.sc; cz=(zF(18)+zF(232))/2-0.03
    B+=np.array([cx,cy,cz])
    return B,Fc

def fingers(side,wx,wz,wy,bone,K=1.55):
    """Mano: palma + 4 dedos largos + garras; coordenadas de la hoja."""
    objs=[]
    for i in range(4):
        x=wx+(i-1.5)*0.03*side*K
        V=[];Fc=[]
        pts=[(x,wy,wz),(x+0.005*side,wy+0.012*K,wz-0.07*K),(x+0.01*side,wy+0.03*K,wz-0.14*K),(x+0.012*side,wy+0.05*K,wz-0.2*K)]
        rad=[0.024*K,0.02*K,0.016*K,0.008*K]; seg=5
        for p,r in zip(pts,rad):
            for s_ in range(seg):
                a=2*math.pi*s_/seg; V.append((p[0]+math.cos(a)*r,p[1]+math.sin(a)*r,p[2]))
        for k in range(3):
            for s_ in range(seg):
                a=k*seg+s_;b=k*seg+(s_+1)%seg; Fc.append((a,a+seg,b+seg,b))
        V.append(pts[-1][:2]+(pts[-1][2]-0.05*K,)); t=3*seg
        for s_ in range(seg): Fc.append((len(V)-1,t+(s_+1)%seg,t+s_))
        V=np.array(V); col=np.tile(np.array([0.10,0.12,0.22]),(len(V),1))*(0.8+0.3*np.random.rand(len(V),1))
        objs.append(mk(f"dedo{side}{i}",V,Fc,col,bone))
    # palma
    V=[];Fc=[]; seg=8
    for k,(dz,rx,ry) in enumerate([(0.0,0.07*K,0.04*K),(-0.06*K,0.085*K,0.045*K),(-0.12*K,0.07*K,0.04*K)]):
        for s_ in range(seg):
            a=2*math.pi*s_/seg; V.append((wx+math.cos(a)*rx*1.0,wy+math.sin(a)*ry,wz+dz))
    for k in range(2):
        for s_ in range(seg):
            a=k*seg+s_;b=k*seg+(s_+1)%seg; Fc.append((a,a+seg,b+seg,b))
    V.append((wx,wy,wz+0.02)); V.append((wx,wy,wz-0.14*K)); t=2*seg
    for s_ in range(seg): Fc.append((len(V)-2,(s_+1)%seg,s_)); Fc.append((len(V)-1,t+s_,t+(s_+1)%seg))
    V=np.array(V); col=np.tile(np.array([0.09,0.11,0.20]),(len(V),1))
    objs.append(mk(f"palma{side}",V,Fc,col,bone))
    return objs

def foot(side,bone):
    """Pie con garras anaranjadas, asomando bajo el dobladillo."""
    V=[];Fc=[]
    cx=side*85*F.sc; cy=((640-cxS))*S.sc
    sx,sy,sz=0.11,0.26,0.07
    n=10
    for k,(zf,rr) in enumerate([(0.0,0.8),(0.5,1.0),(1.0,0.7)]):
        for s_ in range(n):
            a=2*math.pi*s_/n; V.append((cx+math.cos(a)*sx*rr,cy+math.sin(a)*sy*rr,0.01+zf*sz*2))
    for k in range(2):
        for s_ in range(n):
            a=k*n+s_;b=k*n+(s_+1)%n; Fc.append((a,a+n,b+n,b))
    V.append((cx,cy,0.0));V.append((cx,cy,0.01+sz*2)); t=2*n
    for s_ in range(n): Fc.append((len(V)-2,(s_+1)%n,s_)); Fc.append((len(V)-1,t+s_,t+(s_+1)%n))
    V=np.array(V); col=np.tile(np.array([0.14,0.15,0.20]),(len(V),1))
    objs=[mk(f"pie{side}",V,Fc,col,"root")]
    for i in range(3):
        x=cx+(i-1)*0.05; y0=cy+sy*0.85
        W=[(x-0.012,y0,0.03),(x+0.012,y0,0.03),(x,y0+0.1,0.012),(x,y0,0.06)]
        objs.append(mk(f"garra{side}{i}",W,[(0,1,2),(0,3,1),(1,3,2),(0,2,3)],[(0.7,0.35,0.15)]*4,"root"))
    return objs

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    P=[]
    V,Fc=build_body(); N=normals(V,Fc); P.append(mk("tunica",V,Fc,project(V,N),"spine"))
    HV,HF=load_head(); HN=normals(HV,HF); P.append(mk("cabeza",HV,HF,project(HV,HN),"head"))
    # ojos brillantes: se colocan sobre la superficie frontal de la cabeza en la posicion de la hoja
    HVa=np.array(HV)
    for sx in (-1,1):
        ex=sx*38*F.sc; ez=zF(132)
        near=HVa[(abs(HVa[:,0]-ex)<0.035)&(abs(HVa[:,2]-ez)<0.035)]
        ey=near[:,1].max()-0.01 if len(near) else HVa[:,1].max()*0.7
        bpy.ops.mesh.primitive_uv_sphere_add(segments=6,ring_count=4,radius=0.028,location=(ex,ey,ez))
        o=bpy.context.object;o.name=f"ojo{sx}";o.scale=(1.3,0.5,0.6);o["bone"]="head"
        ca=o.data.color_attributes.new("Col",'FLOAT_COLOR','POINT')
        for d in ca.data: d.color=(0.85,0.95,1,1)
        P.append(o)
    # manos (posiciones de la hoja: fila ~455, x +-175 px del eje)
    for side,bn in ((-1,"arm_l"),(1,"arm_r")):
        P+=fingers(side,side*185*F.sc,zF(445),0.07,bn)
        P+=foot(side,"root")
    # transformaciones aplicadas
    bpy.ops.object.select_all(action='DESELECT')
    for o in P: o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # armadura
    Hh=H
    B={"root":((0,0,0),(0,0,0.5),None),"spine":((0,0,0.5),(0,0,zF(200)),"root"),"head":((0,0,zF(200)),(0,0,Hh),"spine"),
       "arm_l":((-0.45,0,zF(200)),(-0.5,0.07,zF(500)),"spine"),"arm_r":((0.45,0,zF(200)),(0.5,0.07,zF(500)),"spine")}
    bpy.ops.object.armature_add(); arm=bpy.context.object; arm.name="Rig"
    bpy.ops.object.mode_set(mode='EDIT'); eb=arm.data.edit_bones
    for b in list(eb): eb.remove(b)
    for n,(h,t,p) in B.items():
        e=eb.new(n); e.head=h; e.tail=t
        if p: e.parent=eb[p]
    bpy.ops.object.mode_set(mode='OBJECT')
    m=bpy.data.materials.new("vc"); m.use_nodes=True; nt=m.node_tree; bs=nt.nodes["Principled BSDF"]
    vc=nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name="Col"; nt.links.new(vc.outputs["Color"],bs.inputs["Base Color"])
    for o in P:
        o.data.materials.append(m)
        vg=o.vertex_groups.new(name=o["bone"]); vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
        o.modifiers.new("Arm",'ARMATURE').object=arm; o.parent=arm
    def anim(name,fr):
        arm.animation_data_create(); act=bpy.data.actions.new(name); arm.animation_data.action=act
        bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='POSE')
        for f,d in fr.items():
            for b,r in d.items():
                pb=arm.pose.bones[b]; pb.rotation_mode='XYZ'; pb.rotation_euler=r; pb.keyframe_insert("rotation_euler",frame=f)
        bpy.ops.object.mode_set(mode='OBJECT')
        tr=arm.animation_data.nla_tracks.new(); tr.name=name; tr.strips.new(name,0,act); arm.animation_data.action=None
    anim("idle",{1:{"spine":(0,0,0)},30:{"spine":(0.03,0,0),"head":(-0.04,0.03,0)},60:{"spine":(0,0,0),"head":(0,0,0)}})
    anim("walk",{1:{"root":(0,0,0.05),"arm_l":(-0.4,0,0),"arm_r":(0.4,0,0)},15:{"root":(0,0,-0.05),"arm_l":(0.4,0,0),"arm_r":(-0.4,0,0)},30:{"root":(0,0,0.05),"arm_l":(-0.4,0,0),"arm_r":(0.4,0,0)}})
    anim("attack",{1:{"arm_r":(0,0,0)},8:{"arm_r":(-1.9,0,0)},16:{"arm_r":(0.3,0,0)},24:{"arm_r":(0,0,0)}})
    bpy.ops.object.select_all(action='DESELECT')
    for o in P+[arm]: o.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath="/home/claude/blender/out/lobo_ref.blend")
    bpy.ops.object.select_all(action='DESELECT')
    for o in P+[arm]: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath="out/lobo_ref.glb",export_format='GLB',use_selection=True,export_animations=True,export_nla_strips=True,export_vertex_color='ACTIVE')
main(); print("LISTO")
