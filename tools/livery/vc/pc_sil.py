"""Percheron: Geometrie-Auswahl (DAE-Knoten) fuer Silhouette und Positionskarten.
HB_PC_SRC = entpacktes livery_src_percheron.zip (vehicles/percheron/*.dae), HB_PC_WORK = Arbeitsordner (Caches, Knotenlisten)."""
import sys, os, pickle, numpy as np, re
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..'))
from lxml import etree
from daeload import load
from PIL import Image
S=os.environ.get('HB_PC_WORK','work_pc'); os.makedirs(S,exist_ok=True)
P=os.path.join(os.environ.get('HB_PC_SRC','src_pc'),'vehicles','percheron')+'/'
def mats(f): return sorted(set(m.replace('-material','') for m in re.findall(r'<material id="([^"]*)"', open(f,errors='ignore').read())))
NS='{http://www.collada.org/2005/11/COLLADASchema}'
def nodes(dae, cache):
    if not os.path.exists(cache):
        from lxml import etree
        with open(cache,'w') as f:
            for n in etree.parse(dae).getroot().iter(NS+'node'):
                for ig in n.findall(NS+'instance_geometry'): f.write('%s %s\n'%(n.get('id'),ig.get('url')[1:]))
    d={}
    for l in open(cache): a,b=l.split(); d.setdefault(a,b)
    return d
def get(dae,key,want):
    pk=S+'/'+key+'_all.pkl'
    tris=load(P+dae, mats(P+dae), pk)
    nm=nodes(P+dae, S+'/'+key+'_nodes.txt'); ids={nm[w] for w in want if w in nm}
    return [t for t in tris if t['name'] in ids]
CAB=['percheron_cab_S','percheron_cab_S_frame','percheron_door_L','percheron_door_R','percheron_door_glass_L','percheron_door_glass_R','percheron_cab_windshield','percheron_cab_windshield_frame',
     'percheron_bumper_grille','percheron_bumper_lower_L','percheron_bumper_lower_R','percheron_bumper_mount','percheron_cab_frontpanel','percheron_cab_cornerpanel_L','percheron_cab_cornerpanel_R',
     'percheron_grille_badge','percheron_cab_step_L','percheron_cab_step_R','percheron_mirror_L','percheron_mirror_R','percheron_mirror_mounts_L','percheron_mirror_mounts_R','percheron_mirror_glass_L','percheron_mirror_glass_R',
     'percheron_headlight_L','percheron_headlight_R','percheron_headlight_glass_L','percheron_headlight_glass_R','percheron_door_L_handle','percheron_door_R_handle','percheron_fueltank_R_370','percheron_cab_storage_L','percheron_cab_storage_R']
BOX=['percheron_cargobox_wall_L_a','percheron_cargobox_wall_R_a','percheron_cargobox_roof_a','percheron_cargobox_headboard_a','percheron_cargobox_reardoor_L','percheron_cargobox_reardoor_R','percheron_cargobox_frame_2axl','percheron_cargobox_frame_R']
if __name__=='__main__':
    T=get('percheron.dae','cab',CAB)+get('percheron_upfits.dae','upfit',BOX)
    pickle.dump(T,open(S+'/truck_sel.pkl','wb'))
    for t in T: print(t['name'],t['mat'],len(t['P']),t['P'].reshape(-1,3).min(0).round(2),t['P'].reshape(-1,3).max(0).round(2))
