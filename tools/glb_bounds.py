"""Calcula o bounding box (em metros/studs importados) de arquivos GLB. Uso: python -I glb_bounds.py arquivo.glb ..."""
import json, struct, sys, itertools

def mat_from_node(n):
    if 'matrix' in n:
        m = n['matrix']  # column-major
        return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t = n.get('translation', [0,0,0]); q = n.get('rotation', [0,0,0,1]); s = n.get('scale', [1,1,1])
    x,y,z,w = q
    R = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
         [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
         [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    M = [[R[r][c]*s[c] for c in range(3)] + [t[r]] for r in range(3)] + [[0,0,0,1]]
    return M

def mul(a, b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def bounds(path):
    data = open(path, 'rb').read()
    clen, ctype = struct.unpack_from('<II', data, 12)
    js = json.loads(data[20:20+clen])
    lo = [1e9]*3; hi = [-1e9]*3
    def visit(idx, parent):
        n = js['nodes'][idx]
        m = mul(parent, mat_from_node(n))
        if 'mesh' in n:
            for prim in js['meshes'][n['mesh']]['primitives']:
                acc = js['accessors'][prim['attributes']['POSITION']]
                for corner in itertools.product(*zip(acc['min'], acc['max'])):
                    p = [sum(m[r][c]*(corner[c] if c < 3 else 1) for c in range(4)) for r in range(3)]
                    for i in range(3):
                        lo[i] = min(lo[i], p[i]); hi[i] = max(hi[i], p[i])
        for c in n.get('children', []):
            visit(c, m)
    ident = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    for s in js['scenes'][js.get('scene', 0)]['nodes']:
        visit(s, ident)
    return [round(h-l, 2) for l, h in zip(lo, hi)]

if __name__ == '__main__':
    for f in sys.argv[1:]:
        import os
        print(os.path.basename(f), bounds(f))
