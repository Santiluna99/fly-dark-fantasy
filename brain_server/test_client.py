# Hollowfly - Copyright (C) 2026 Santiluna99
# Software libre bajo la GNU GPL v3 (ver LICENSE y NOTICE).
"""Prueba del servidor: escenarios de estimulo y lectura de giro/avance."""
import socket, json, time, sys
s=socket.create_connection(("127.0.0.1",9009)); f=s.makefile("rwb")
def ask(q):
    f.write((json.dumps(q)+"\n").encode()); f.flush(); return json.loads(f.readline())
def scen(name,q,secs=3.0):
    ask({**q,"reset":True}); t0=time.time(); r=None
    while time.time()-t0<secs: r=ask(q); time.sleep(0.05)
    print(f"{name:26s} turn={r['turn']:+.2f} fwd={r['fwd']:.2f} gf={r['gf']:.2f} kc={r['kc']:.3f} raw={r['raw']}")
    return r
scen("sin estimulo",{"orn":[0,0],"loom":[0,0]})
scen("fruta a la izquierda",{"orn":[0.8,0],"loom":[0,0]})
scen("fruta a la derecha",{"orn":[0,0.8],"loom":[0,0]})
scen("fruta en ambos lados",{"orn":[0.8,0.8],"loom":[0,0]})
scen("amenaza izquierda",{"orn":[0,0],"loom":[0.9,0]})
scen("amenaza derecha",{"orn":[0,0],"loom":[0,0.9]})
scen("amenaza ambos",{"orn":[0,0],"loom":[0.9,0.9]})
scen("fruta izq + hambre",{"orn":[0.8,0],"loom":[0,0],"hunger":1.0})
