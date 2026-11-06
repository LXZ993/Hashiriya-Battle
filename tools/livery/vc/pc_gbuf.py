"""Positionskarten (UV1 -> 3D) fuer Percheron Fahrerhaus / Koffer / Tank: python pc_gbuf.py cab box tank"""
import sys, os, pickle, numpy as np
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..'))
from gbuf import gbuffer
from pc_sil import get, S as WORK
from PIL import Image
CABN=['percheron_cab_L','percheron_cab_XL','percheron_cab_S','percheron_door_L','percheron_door_R','percheron_bumper_grille','percheron_bumper_lower_L','percheron_bumper_lower_R',
      'percheron_cab_frontpanel','percheron_cab_cornerpanel_L','percheron_cab_cornerpanel_R','percheron_cab_step_L','percheron_cab_step_R','percheron_cab_storage_L','percheron_cab_storage_R','percheron_door_L_handle','percheron_door_R_handle']
BOXN=['percheron_cargobox_wall_L_b','percheron_cargobox_wall_R_b','percheron_cargobox_roof_b','percheron_cargobox_headboard_b',
      'percheron_cargobox_wall_L_a','percheron_cargobox_wall_R_a','percheron_cargobox_roof_a','percheron_cargobox_headboard_a','percheron_cargobox_reardoor_L','percheron_cargobox_reardoor_R','percheron_cargobox_frame_R']
TANKN=['percheron_tanker_SC','percheron_tanker_SC_top']
def run(key, dae, nk, names, mats, W):
    T=[t for t in get(dae,nk,names) if t['mat'] in mats]
    for t in T:
        u=t['U1'].copy(); f=np.floor(u[:,:,0].mean(1,keepdims=True)+1e-6)
        u[:,:,0]-=f; t['U1']=u     # Kacheln (Tank-UV1 liegt bei u 2..3) auf 0..1
    pos,nrm,mask=gbuffer(T,W,W)
    np.savez_compressed(os.path.join(WORK,f'pc_{key}_gb.npz'),pos=pos,nrm=nrm,mask=mask)
    v=np.zeros((W,W,3),np.uint8); v[mask]=(np.abs(nrm[mask])*255).astype(np.uint8)
    Image.fromarray(v).resize((1024,1024)).save(os.path.join(WORK,f'pc_{key}_gb.png')); print(key,'filled',mask.mean())
which=sys.argv[1:]
if 'cab' in which: run('cab','percheron.dae','cab',CABN,{'percheron_body_paint','percheron_body'},2048)
if 'box' in which: run('box','percheron_upfits.dae','upfit',BOXN,{'percheron_flatbed'},2048)
if 'tank' in which: run('tank','percheron_tanker.dae','tank',TANKN,{'percheron_tanker'},2048)
