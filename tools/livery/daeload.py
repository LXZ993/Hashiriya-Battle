import numpy as np, pickle, sys, os
from lxml import etree
NS='{http://www.collada.org/2005/11/COLLADASchema}'
def load(path, mats, cache=None):
    if cache and os.path.exists(cache): return pickle.load(open(cache,'rb'))
    tree = etree.parse(path); root = tree.getroot()
    # node transforms per geometry
    xf = {}
    def walk(node, M):
        m = node.find(NS+'matrix')
        if m is not None:
            M = M @ np.array(m.text.split(), float).reshape(4,4)
        for t in node.findall(NS+'translate'):
            T=np.eye(4); T[:3,3]=np.array(t.text.split(),float); M=M@T
        for ig in node.findall(NS+'instance_geometry'):
            xf.setdefault(ig.get('url')[1:], []).append(M)
        for c in node.findall(NS+'node'): walk(c, M)
    for vs in root.iter(NS+'visual_scene'):
        for n in vs.findall(NS+'node'): walk(n, np.eye(4))
    out=[]
    for g in root.iter(NS+'geometry'):
        gid=g.get('id'); mesh=g.find(NS+'mesh')
        if mesh is None: continue
        src={}
        for s in mesh.findall(NS+'source'):
            fa=s.find(NS+'float_array')
            if fa is None: continue
            st=int(s.find('.//'+NS+'accessor').get('stride'))
            src[s.get('id')]=np.array((fa.text or '').split(),np.float32).reshape(-1,st)
        vert={}
        for v in mesh.findall(NS+'vertices'):
            for i in v.findall(NS+'input'):
                if i.get('semantic')=='POSITION': vert[v.get('id')]=src[i.get('source')[1:]]
        for tri in list(mesh.findall(NS+'triangles'))+list(mesh.findall(NS+'polylist')):
            base=(tri.get('material') or '').replace('-material','')
            if base not in mats: continue
            inputs=tri.findall(NS+'input'); stride=max(int(i.get('offset'))for i in inputs)+1
            p=np.array(tri.find(NS+'p').text.split(),np.int64).reshape(-1,stride)
            if tri.tag.endswith('polylist'):
                vc=np.array(tri.find(NS+'vcount').text.split(),int)
                if (vc!=3).any(): print('non-tri polylist', gid); continue
            P=None; tcs={}
            for i in inputs:
                sem=i.get('semantic'); o=int(i.get('offset')); s=i.get('source')[1:]
                if sem=='VERTEX': P=vert[s][p[:,o]]
                elif sem=='TEXCOORD': tcs[int(i.get('set',0))]=src[s][p[:,o]][:,:2]
            ks=sorted(tcs)
            if len(ks)<2:
                if not base.endswith('glass'): print('no uv1',gid,base); continue
                tcs[1]=tcs[ks[0]]; ks=[ks[0],1]
            Ms = xf.get(gid, [np.eye(4)])
            for M in Ms:
                PP = (np.c_[P, np.ones(len(P))] @ M.T)[:,:3]
                out.append(dict(name=gid, mat=base, P=PP.reshape(-1,3,3).astype(np.float32), U1=tcs[ks[1]].reshape(-1,3,2), U0=tcs[ks[0]].reshape(-1,3,2), inst=gid in xf))
    if cache: pickle.dump(out, open(cache,'wb'))
    return out
if __name__ == '__main__':
    o = load(sys.argv[1], sys.argv[2].split(','), sys.argv[3])
    print(len(o), sum(len(x['P']) for x in o), 'not instanced', sum(not x['inst'] for x in o))
    allP = np.concatenate([x['P'].reshape(-1,3) for x in o]); print('bbox', allP.min(0), allP.max(0))
    for x in o:
        p=x['P'].reshape(-1,3); u=x['U1'].reshape(-1,2); print(x['name'], x['mat'], len(x['P']), p.min(0).round(2), p.max(0).round(2), 'uv1', u.min(0).round(2), u.max(0).round(2))
