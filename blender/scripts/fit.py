# Reconstruccion a partir de la hoja: cuerpo = anillos superelipticos con anchos de la silueta frontal y profundidad de la lateral;
# cabeza esculpida escalada a las medidas de la hoja; color por vertice PROYECTADO desde las vistas frente / espalda / lado.
import bpy, math, sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from mathutils import Vector

REF="/home/claude/blender/ref/"
def load(n): return np.asarray(Image.open(REF+n).convert('RGB')).astype(np.float32)/255.0

def masks(img, bg, t, bounds):
    """Silueta binaria por distancia de color al fondo, y recorte por vista (x0,x1)."""
    d=np.sqrt(((img*255-bg)**2).sum(2)); sc=ndi.gaussian_filter(d,2)
    m=sc>t; m=ndi.binary_closing(m,iterations=3); m=ndi.binary_fill_holes(m); m=ndi.binary_opening(m,iterations=3)
    out=[]
    for (a,b) in bounds:
        mm=np.zeros_like(m); mm[:,a:b]=m[:,a:b]
        lab,n=ndi.label(mm); 
        if n>1:
            sz=ndi.sum(mm,lab,range(1,n+1)); mm=lab==(1+int(np.argmax(sz)))
        ys,xs=np.where(mm); out.append((mm,xs.min(),xs.max(),ys.min(),ys.max()))
    return out

class View:
    """Una vista ortografica: mascara + imagen + escala px->metros (por la altura de su bbox)."""
    def __init__(s,img,m,H):
        s.img=img; s.m,s.x0,s.x1,s.y0,s.y1=m; s.sc=H/(s.y1-s.y0); s.H=H
    def z_to_row(s,z): return s.y1 - z/s.sc
    def row_extent(s,row):
        r=int(np.clip(round(row),0,s.m.shape[0]-1)); xs=np.where(s.m[r])[0]
        return (xs.min(),xs.max()) if len(xs) else (None,None)
    def sample(s,col,row):
        c=np.clip(col,0,s.img.shape[1]-1.001); r=np.clip(row,0,s.img.shape[0]-1.001)
        c0=np.floor(c).astype(int); r0=np.floor(r).astype(int); fc=(c-c0)[:,None]; fr=(r-r0)[:,None]
        I=s.img; return (I[r0,c0]*(1-fc)*(1-fr)+I[r0,c0+1]*fc*(1-fr)+I[r0+1,c0]*(1-fc)*fr+I[r0+1,c0+1]*fc*fr)
