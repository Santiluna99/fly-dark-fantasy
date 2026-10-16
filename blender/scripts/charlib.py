# Libreria comun: reconstruye un personaje a partir de una hoja de vistas (frente / espalda / lateral).
#  - Cuerpo: casco visual (voxels) con secciones elipticas por tramo de la silueta frontal; marching cubes -> malla low-poly.
#  - Color por vertice proyectado desde las vistas de la hoja.  - Rig simple + animaciones + exporta .glb y .blend
import bpy, math, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure
sys.path.insert(0,"/home/claude/blender")
from fit import load, masks, View

sm1=lambda a,s=2.0: ndi.gaussian_filter1d(a,s,mode='nearest')

def runs(row_mask):
    """Tramos continuos [a,b] de una fila booleana."""
    d=np.diff(np.concatenate([[0],row_mask.astype(int),[0]])); a=np.where(d==1)[0]; b=np.where(d==-1)[0]-1
    return list(zip(a,b))

def hull(F,S,H,cxF,cxS,res=0.035,side_dir=1,depth_ratio=None,side_off=0.0,pow_=2.5,minrun=3,arm_depth=0.55,max_depth_ratio=2.4,zmax=None):
    """Voxeliza: por fila de altura, cada tramo de la silueta frontal -> elipse (x) con profundidad de la lateral (y).
    Si no hay vista lateral (S=None) la profundidad = depth_ratio * ancho."""
    W=F.m.shape[1]; xs=np.arange(-0.9*H*0.5-0.3, 0.9*H*0.5+0.3, res)
    ys=np.arange(-0.6,0.9,res); zs=np.arange(0.0,(zmax or H),res)
    G=np.zeros((len(xs),len(ys),len(zs)),bool)
    for k,z in enumerate(zs):
        rowF=int(np.clip(round(F.z_to_row(z)),0,F.m.shape[0]-1))
        rr=[r for r in runs(F.m[rowF]) if r[1]-r[0]>=minrun]
        if not rr: continue
        if S is not None:
            rowS=int(np.clip(round(S.z_to_row(z)),0,S.m.shape[0]-1)); sr=runs(S.m[rowS])
            if sr: a0=min(r[0] for r in sr); b0=max(r[1] for r in sr)
            else: continue
            # lateral en metros (adelante = +y)
            if side_dir>0: ya=(a0-cxS)*S.sc; yb=(b0-cxS)*S.sc
            else: ya=-(b0-cxS)*S.sc; yb=-(a0-cxS)*S.sc
            ycen=(ya+yb)/2+side_off; yhalf=(yb-ya)/2
        widest=max(rr,key=lambda r:r[1]-r[0])
        for (a,b) in rr:
            cx=((a+b)/2-cxF)*F.sc; ax=(b-a)/2*F.sc
            if ax<res*0.5: continue
            if S is not None:
                by=yhalf*(1.0 if (a,b)==widest else arm_depth); by=min(by,ax*max_depth_ratio); cy=ycen
            else:
                by=ax*depth_ratio; cy=0.0
            X=(xs-cx)/ax; Y=(ys-cy)/max(by,res*0.5)
            m=(np.abs(X)[:,None]**pow_+np.abs(Y)[None,:]**pow_)<=1.0
            G[:,:,k]|=m
    return G,xs,ys,zs

def mesh_from_grid(G,xs,ys,zs,res,smooth=2):
    Gp=np.pad(G.astype(float),1)
    Gs=ndi.gaussian_filter(Gp,0.7)
    v,f,n,_=measure.marching_cubes(Gs,0.5)
    v=v-1
    V=np.stack([xs[0]+v[:,0]*res, ys[0]+v[:,1]*res, zs[0]+v[:,2]*res],1)
    # suavizado laplaciano ligero
    nb=[set() for _ in range(len(V))]
    for a,b,c in f:
        nb[a]|={b,c}; nb[b]|={a,c}; nb[c]|={a,b}
    for _ in range(smooth):
        V2=V.copy()
        for i,s in enumerate(nb): V2[i]=0.5*V[i]+0.5*V[list(s)].mean(0)
        V=V2
    return V,f

def normals(V,Fc):
    V=np.asarray(V);N=np.zeros_like(V)
    for f in Fc:
        a,b,c=f[0],f[1],f[2]; n=np.cross(V[b]-V[a],V[c]-V[a]); N[a]+=n;N[b]+=n;N[c]+=n
    return N/(np.linalg.norm(N,axis=1,keepdims=True)+1e-9)

class Proj:
    """Proyeccion de color desde las vistas. side_dir=+1 si en la vista lateral el personaje mira a la derecha."""
    def __init__(s,F,Bk,S,cxF,cxB,cxS,side_dir=1,gain=0.95,side_fallback=True):
        s.F,s.Bk,s.S,s.cxF,s.cxB,s.cxS,s.sd,s.gain,s.fb=F,Bk,S,cxF,cxB,cxS,side_dir,gain,side_fallback
    def __call__(s,P,N):
        P=np.asarray(P);N=np.asarray(N); F,Bk,S=s.F,s.Bk,s.S
        Cf=F.sample(s.cxF+P[:,0]/F.sc, F.y1-P[:,2]/F.sc)
        Cb=Bk.sample(s.cxB-P[:,0]/Bk.sc, Bk.y1-P[:,2]/Bk.sc)
        wf=np.clip(N[:,1],0,1)**2; wb=np.clip(-N[:,1],0,1)**2; ws=np.abs(N[:,0])**2*1.3
        if S is not None:
            Cs=S.sample(s.cxS+s.sd*P[:,1]/S.sc, S.y1-P[:,2]/S.sc)
        else:
            # sin perfil: los costados toman la vista frontal o la trasera segun el lado hacia el que miran
            Cs=np.where((P[:,1]>0)[:,None],Cf,Cb)
        w=wf+wb+ws+1e-6
        C=(Cf*wf[:,None]+Cb*wb[:,None]+Cs*ws[:,None])/w[:,None]
        return np.clip(C*s.gain,0,1)

def mk(name,V,Fc,col=None,bone="spine",smooth=False):
    me=bpy.data.meshes.new(name); me.from_pydata([tuple(map(float,v)) for v in V],[],[tuple(map(int,f)) for f in Fc]); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth=smooth
    if col is not None:
        ca=me.color_attributes.new("Col",'FLOAT_COLOR','POINT')
        for i,c in enumerate(col): ca.data[i].color=(float(c[0]),float(c[1]),float(c[2]),1)
    o["bone"]=bone; return o

def split_by_bone(V,Fc,col,bone_fn,name="cuerpo"):
    """Divide la malla en piezas segun el hueso de cada triangulo (por centroide) para pesos rigidos por pieza."""
    V=np.asarray(V); groups={}
    for f in Fc:
        c=V[list(f)].mean(0); groups.setdefault(bone_fn(c),[]).append(f)
    objs=[]
    for b,fl in groups.items():
        used=sorted({i for f in fl for i in f}); remap={i:k for k,i in enumerate(used)}
        objs.append(mk(f"{name}_{b}",V[used],[[remap[i] for i in f] for f in fl],np.asarray(col)[used],b))
    return objs

def eye_sphere(name,loc,r,col,scale=(1,0.5,0.7),bone="head"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6,ring_count=4,radius=r,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o["bone"]=bone
    ca=o.data.color_attributes.new("Col",'FLOAT_COLOR','POINT')
    for d in ca.data: d.color=(*col,1)
    return o

def finish(P,bones,anims,out,H):
    """Aplica transformaciones, crea armadura con pesos 100% por pieza, animaciones, guarda .blend y exporta .glb."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in P: o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.armature_add(); arm=bpy.context.object; arm.name="Rig"
    bpy.ops.object.mode_set(mode='EDIT'); eb=arm.data.edit_bones
    for b in list(eb): eb.remove(b)
    for n,(h,t,p) in bones.items():
        e=eb.new(n); e.head=h; e.tail=t
        if p: e.parent=eb[p]
    bpy.ops.object.mode_set(mode='OBJECT')
    m=bpy.data.materials.new("vc"); m.use_nodes=True; nt=m.node_tree; bs=nt.nodes["Principled BSDF"]
    vc=nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name="Col"; nt.links.new(vc.outputs["Color"],bs.inputs["Base Color"])
    for o in P:
        o.data.materials.append(m)
        vg=o.vertex_groups.new(name=o["bone"]); vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
        o.modifiers.new("Arm",'ARMATURE').object=arm; o.parent=arm
    for name,fr in anims.items():
        arm.animation_data_create(); act=bpy.data.actions.new(name); arm.animation_data.action=act
        bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='POSE')
        for f,d in fr.items():
            for b,r in d.items():
                pb=arm.pose.bones[b]; pb.rotation_mode='XYZ'; pb.rotation_euler=r; pb.keyframe_insert("rotation_euler",frame=f)
        bpy.ops.object.mode_set(mode='OBJECT')
        tr=arm.animation_data.nla_tracks.new(); tr.name=name; tr.strips.new(name,0,act); arm.animation_data.action=None
    bpy.ops.wm.save_as_mainfile(filepath=f"/home/claude/blender/out/{out}.blend")
    bpy.ops.object.select_all(action='DESELECT')
    for o in P+[arm]: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f"/home/claude/blender/out/{out}.glb",export_format='GLB',use_selection=True,export_animations=True,export_nla_strips=True,export_vertex_color='ACTIVE')

def foot_mesh(name,cx,cy,sx,sy,sz,col,bone="root"):
    V=[];Fc=[];n=10
    for k,(zf,rr) in enumerate([(0.0,0.8),(0.5,1.0),(1.0,0.7)]):
        for s_ in range(n):
            a=2*math.pi*s_/n; V.append((cx+math.cos(a)*sx*rr,cy+math.sin(a)*sy*rr,0.01+zf*sz*2))
    for k in range(2):
        for s_ in range(n):
            a=k*n+s_;b=k*n+(s_+1)%n; Fc.append((a,a+n,b+n,b))
    V.append((cx,cy,0.0));V.append((cx,cy,0.01+sz*2)); t=2*n
    for s_ in range(n): Fc.append((len(V)-2,(s_+1)%n,s_)); Fc.append((len(V)-1,t+s_,t+(s_+1)%n))
    return mk(name,V,Fc,[col]*len(V),bone)

def claw(name,x,y,z,length,w,col,bone="root"):
    W=[(x-w,y,z+w),(x+w,y,z+w),(x,y+length,z-w*0.5),(x,y,z+2.5*w)]
    return mk(name,W,[(0,1,2),(0,3,1),(1,3,2),(0,2,3)],[col]*4,bone)
