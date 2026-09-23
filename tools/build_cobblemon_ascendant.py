# Ascendant-authored Bedrock cube models. Palette material cells are generated
# directly as renderer data; no source artwork is modified or projected flat.
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description="Build original Ascendant Bedrock cube models")
p.add_argument("--output",type=Path,default=Path(__file__).resolve().parents[1]/"assets/cobblemon-ascendant")
args=p.parse_args()
import json,math,struct,zlib,hashlib
OUT=args.output; OUT.mkdir(parents=True,exist_ok=True)
COL={'black':'252634','white':'f4efdc','cream':'eedab0','orange':'dd742c','yellow':'e9c04c','brown':'805337','dark':'46332b','red':'b73d3f','blue':'316bad','cyan':'63b7cd','purple':'8263a1','green':'83bd64','lime':'aec96a','gray':'8b9fa8','pink':'d477a1','teal':'428e83','navy':'27374f','eye':'cf4648','silver':'bdc6cd','gold':'cfa345','pale':'d5e5de','lightblue':'a1d3d9'}
COLORS=list(COL); palette=[]
for color in COL.values():palette+=list(bytes.fromhex(color))+[255]
def png():
 def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',len(COL),1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0'+bytes(palette)))+chunk(b'IEND',b'')
(OUT/'palette.png').write_bytes(png())
class Model:
 def __init__(self,dex,name):self.dex=dex;self.name=name;self.bones=[{'name':name,'pivot':[0,0,0]}];self.current=self.bones[0]
 def bone(self,name,pivot,parent=None):
  self.current={'name':name,'parent':parent or self.name,'pivot':list(pivot),'cubes':[]};self.bones.append(self.current);return self
 def cube(self,c,center,size,rot=None):
  p=[center[i]-size[i]/2 for i in range(3)];u=COLORS.index(c)
  x={'origin':p,'size':list(size),'uv':{n:{'uv':[u,0],'uv_size':[1,1]}for n in ['north','south','east','west','up','down']}}
  if rot:x.update(pivot=list(center),rotation=list(rot))
  self.current.setdefault('cubes',[]).append(x);return self
 def round(self,c,center,size):
  x,y,z=center;w,h,d=size
  self.cube(c,(x,y,z),(w*.75,h,d*.75));self.cube(c,(x,y,z),(w,h*.72,d*.8));self.cube(c,(x,y,z),(w*.8,h*.72,d));return self
 def eyes(self,x,y,z,iris='black',s=1):
  for sign in [-1,1]:self.cube('white',(sign*x,y,z),(s*1.4,s*1.4,.35)).cube(iris,(sign*x,y,z-.2),(s*.7,s,.2))
  return self
 def save(self):
  raw={'format_version':'1.12.0','minecraft:geometry':[{'description':{'identifier':'geometry.ascendant_'+self.name,'texture_width':len(COL),'texture_height':1},'bones':self.bones}]}
  (OUT/(self.name+'.geo.json')).write_text(json.dumps(raw,separators=(',',':')))
  group='ascendant_'+self.name
  idle={self.name:{'position':[0,'math.sin(q.anim_time * 180) * 0.18',0]}}
  walk={self.name:{'position':[0,'math.abs(math.sin(q.anim_time * 360)) * 0.35',0]}}
  for i,b in enumerate(self.bones):
   if any(part in b['name'] for part in ['leg','arm','wing']):walk[b['name']]={'rotation':['math.sin(q.anim_time * 360) * '+str(12 if i%2 else -12),0,0]}
  def clip(seconds,bones,loop=True):return {'animation_length':seconds,'loop':loop,'bones':bones}
  clips={'ground_idle':clip(2,idle),'battle_idle':clip(2,idle),'ground_walk':clip(1,walk),
    'physical':clip(.6,{self.name:{'rotation':{'0':[0,0,0],'.2':[-9,0,0],'.35':[12,0,0],'.6':[0,0,0]}}},False),
    'recoil':clip(.4,{self.name:{'rotation':{'0':[0,0,0],'.12':[-6,0,0],'.4':[0,0,0]}}},False),
    'faint':clip(.8,{self.name:{'rotation':{'0':[0,0,0],'.8':[0,0,75]}}},False)}
  anim={'format_version':'1.8.0','animations':{'animation.'+group+'.'+k:v for k,v in clips.items()}}
  expr=lambda n:"q.bedrock('"+group+"', '"+n+"')"
  poser={'rootBone':self.name,'poses':{'standing':{'poseTypes':['STAND'],'animations':[expr('ground_idle')]},'walking':{'poseTypes':['WALK'],'animations':[expr('ground_walk')]},'battle-standing':{'poseTypes':['STAND'],'isBattle':True,'animations':[expr('battle_idle')]}},'animations':{k:expr(k)for k in ['physical','recoil','faint']}}
  (OUT/(self.name+'.animation.json')).write_text(json.dumps(anim,separators=(',',':')))
  (OUT/(self.name+'.poser.json')).write_text(json.dumps(poser,separators=(',',':')))
  return {'dex':self.dex,'name':self.name,'path':'assets/cobblemon-ascendant/'+self.name+'.geo.json','bones':len(self.bones),'cubes':sum(len(b.get('cubes',[]))for b in self.bones)}
models=[]
# Gorochu: three horns, cheek pouches, fangs, lightning tail and back stripes.
m=Model(1026,'gorochu');m.bone('body',(0,8,0)).round('orange',(0,9,0),(10,13,7)).round('cream',(0,8,-3.4),(7,9,1))
for y in [6,9,12]:m.cube('dark',(-1 if y==9 else 1,y,3.55),(5,1,0.4),(0,0,(-1 if y==9 else 1)*25))
m.bone('head',(0,15,0),'body').round('orange',(0,16,-.5),(9,8,7)).eyes(2,17,-4,'black',1.1)
for s in [-1,1]:
 m.cube('yellow',(s*3.6,15.5,-3.5),(2.2,2.8,.8)).cube('orange',(s*3.7,20,.3),(2.2,5,1.8),(0,0,s*22)).cube('cream',(s*3.5,21,.3),(1.2,2.5,1.9))
 m.cube('dark',(s*5.1,18.5,0),(1.8,5,1.8),(0,0,-s*44)).cube('cream',(s*6.4,20,0),(1,2,1),(0,0,-s*44))
 m.cube('white',(s*1.3,13.8,-4.1),(.8,1.5,.5))
m.cube('black',(0,14,-4),(3.5,1.7,.4)).cube('dark',(0,21,-.4),(2.5,5,2)).cube('cream',(0,23.2,-.4),(1.3,2,1.3))
for s,n in [(-1,'left'),(1,'right')]:
 m.bone('arm_'+n,(s*4,12,0),'body').round('orange',(s*5.5,10,-1),(3,6,3)).cube('dark',(s*6,7.4,-1.3),(3.5,2,3.8))
 m.bone('leg_'+n,(s*3,4,0),'body').cube('dark',(s*3,2,-1),(3.5,4,5))
m.bone('tail',(0,5,3),'body')
for center,size,rot in [((2,3,5),(2,2,5),None),((5,4,7),(6,2,2),(0,0,25)),((8,7,7),(2,7,2),(0,0,-15))]:m.cube('dark',center,size,rot)
m.cube('orange',(9,13,7),(3,9,1.5),(0,0,25)).cube('yellow',(10,15.5,7),(3,6,1.6),(0,0,-25)).cube('cream',(9,18.2,7),(1.5,3,1.7),(0,0,-25));models.append(m.save())
# Sludge family: differentiated squat blob / tall diamond-patterned body.
for dex,name,color,w,h in [(316,'gulpin','lime',10,9),(317,'swalot','purple',14,17)]:
 m=Model(dex,name);m.bone('body',(0,h/2,0)).round(color,(0,h/2,0),(w,h,w*.8))
 m.bone('head',(0,h*.65,0),'body')
 for s in [-1,1]:m.cube('black',(s*w*.22,h*.68,-w*.39),(2,.45,.3))
 m.cube('pink' if dex==316 else 'black',(0,h*.47,-w*.42),(3.5,1.4,.65))
 if dex==316:m.cube('yellow',(0,h+.6,0),(2,4,1),(0,0,-20))
 else:
  for s in [-1,1]:m.cube('black',(s*4.5,9,-5.8),(4,.55,.6),(0,0,s*15))
  for x,y in [(-3,5),(0,7),(3,5)]:m.cube('gold',(x,y,-5.4),(1.8,1.8,.6),(0,0,45))
  for s in [-1,1]:m.bone('arm_'+str(s),(s*6,7,0),'body').round(color,(s*7,6,0),(4,4,3))
 models.append(m.save())
# Castform's normal water-droplet/cloud body.
m=Model(351,'castform');m.bone('body',(0,5,0)).round('pale',(-2,3,0),(5,5,5)).round('pale',(2,3,0),(5,5,5));m.bone('head',(0,7,0),'body').round('gray',(0,8,0),(8,8,7)).eyes(1.9,8.3,-3.65,'black',1.15);models.append(m.save())
# Celebi: leaf crest, long antennae, compact fairy body and separate wings.
m=Model(251,'celebi');m.bone('body',(0,7,0)).round('green',(0,6,0),(4,7,4));m.bone('head',(0,10,0),'body').round('lime',(0,12,-.5),(8,8,6)).cube('green',(0,16,1),(4,5,4),(30,0,0)).eyes(2.1,12.5,-3.5,'blue',1.5)
for s,n in [(-1,'left'),(1,'right')]:
 m.cube('green',(s*2,16,-2),(.7,5,.7),(0,0,s*20));m.bone('arm_'+n,(s*2,8,0),'body').cube('green',(s*3,7,0),(1.6,4,1.8),(0,0,s*25));m.bone('leg_'+n,(s*1.2,3,0),'body').cube('green',(s*1.2,2,0),(1.8,3,2));m.bone('wing_'+n,(s*1.5,9,2),'body').round('pale',(s*4,10,2),(5,7,.65))
models.append(m.save())
# Weather trio silhouettes: floating whale, armored reptile, wish star.
m=Model(382,'kyogre');m.bone('body',(0,6,0)).round('blue',(0,7,0),(12,9,22)).round('white',(0,3.7,-2),(10,2,18));m.bone('head',(0,7,-6),'body').round('blue',(0,7,-8),(13,8,10)).eyes(4,7,-13,'yellow',.9)
for s,n in [(-1,'left'),(1,'right')]:
 m.bone('wing_'+n,(s*5,6,-1),'body').cube('blue',(s*12,6,-1),(15,2,11),(0,s*18,0)).cube('red',(s*12,7.1,-1),(10,.3,1),(0,s*18,0))
 for z in [-4,0,4]:m.cube('white',(s*19,6,z),(3,1.5,2.2))
 m.bone('tail_'+n,(s*2,6,10),'body').cube('blue',(s*4.5,6,14),(7,1.8,8),(0,s*25,0)).cube('red',(s*4.5,7,14),(1,.2,6),(0,s*25,0))
models.append(m.save())
m=Model(383,'groudon');m.bone('body',(0,10,0)).round('red',(0,11,0),(13,16,10)).round('cream',(0,10,-4.6),(9,12,1))
for y in [5,8,11,14]:m.cube('black',(0,y,-5.2),(8,.55,.3))
m.bone('head',(0,18,-1),'body').round('red',(0,19,-3),(10,8,9)).cube('red',(0,17,-8),(10,3,6)).cube('cream',(0,15.5,-8),(9,1.2,5)).eyes(3,19,-7.6,'yellow',.85)
for s,n in [(-1,'left'),(1,'right')]:
 for y in [9,13,17]:m.cube('white',(s*7,y,1),(4,2,3),(0,0,s*25))
 m.bone('arm_'+n,(s*6,15,0),'body').cube('red',(s*8,11,-3),(5,8,5),(15,0,s*10))
 for x in [-1.6,0,1.6]:m.cube('white',(s*8+x,7,-6),(1.1,2,3))
 m.bone('leg_'+n,(s*4,5,0),'body').round('red',(s*4,3,-1),(6,6,8))
 for x in [-1.7,0,1.7]:m.cube('white',(s*4+x,1,-5),(1.3,2,3))
m.bone('tail',(0,7,4),'body')
for i in range(4):m.cube('red',(0,6-i,7+i*3),(9-i*1.8,4,5)).cube('black',(0,8-i,8+i*3),(8-i*1.6,.3,.6))
models.append(m.save())
m=Model(385,'jirachi');m.bone('body',(0,6,0)).round('white',(0,6,0),(5,7,4));m.bone('head',(0,11,0),'body').round('yellow',(0,12,0),(8,7,4)).cube('yellow',(0,17,0),(3.5,6,3)).eyes(2,12.5,-2.3,'black',1)
for s,n in [(-1,'left'),(1,'right')]:
 m.cube('yellow',(s*5,13,0),(6,3.5,3),(0,0,s*20)).cube('teal',(s*6.4,10,-.4),(1.5,5,.6))
 m.bone('arm_'+n,(s*2,7,0),'body').cube('white',(s*3.5,7,0),(4,1.8,2),(0,0,s*15));m.bone('leg_'+n,(s*1.3,3,0),'body').cube('white',(s*1.4,2,0),(2,3,2))
m.cube('teal',(0,17,-1.8),(1.5,3,.4));models.append(m.save())
# Deoxys: separate paired helix arm bones, chest core, angular head.
m=Model(386,'deoxys');m.bone('body',(0,12,0)).round('orange',(0,12,0),(7,10,4)).cube('purple',(0,14,-2.3),(3,3,1),(0,0,45));m.bone('head',(0,19,0),'body').round('orange',(0,20,0),(7,6,5)).cube('teal',(0,20,-2.6),(4,4,.7)).eyes(1.2,21,-3,'white',.6)
for s,n in [(-1,'left'),(1,'right')]:
 m.cube('orange',(s*3,23,0),(1.5,4,2),(0,0,-s*15));m.bone('arm_'+n,(s*4,16,0),'body')
 for i in range(4):
  x=s*(5+math.sin(i*1.7));m.cube('orange',(x,15-i*2.4,-.4),(1.4,3,1.5),(0,0,s*25)).cube('teal',(s*(6-math.sin(i*1.7)),15-i*2.4,.7),(1.4,3,1.5),(0,0,-s*25))
 m.bone('leg_'+n,(s*2,8,0),'body').cube('orange',(s*2.5,4.5,0),(2.5,9,3),(0,0,-s*8)).cube('teal',(s*2.8,1,-1),(2,2,4))
models.append(m.save())
# Legendary beasts share a quadruped rig but individually authored crests,
# manes, markings and tails; no species is an alias to another model.
for dex,name,color,mane in [(243,'raikou','yellow','purple'),(244,'entei','brown','cream'),(245,'suicune','cyan','purple')]:
 m=Model(dex,name);m.bone('body',(0,9,0)).round(color,(0,9,1),(8,8,15))
 for s in [-1,1]:
  for z,n in [(-5,'front'),(6,'rear')]:m.bone('leg_'+n+str(s),(s*3,8,z),'body').cube(color,(s*3,4,z),(2.5,8,3)).cube('dark'if dex!=245 else 'pale',(s*3,1,z-1),(3,2,4))
 m.bone('head',(0,12,-6),'body').round(color,(0,13,-7),(8,8,7)).round('cream',(0,11,-11),(5,3,3)).eyes(2.1,14,-10.7,'red',.8)
 if dex==243:
  m.cube('black',(0,16,-8),(2.5,2,3));m.cube('gray',(0,18,-7),(7,2,4))
  for s in [-1,1]:
   m.cube('white',(s*1.8,9.5,-12),(1,3,1));m.cube('yellow',(s*3,18,-6),(2,3,2))
  m.bone('mane',(0,12,-3),'body').round(mane,(0,13,3),(9,6,15))
  for s in [-1,1]:
   for z in [-3,1,5]:m.cube('black',(s*4.1,9,z),(.3,5,1.5),(s*20,0,0))
  m.bone('tail',(0,11,8),'body')
  for i in range(5):m.cube('blue',((1 if i%2 else -1)*2,11+i,10+i*2),(5,.8,1.5),(0,(1 if i%2 else -1)*35,0))
 elif dex==244:
  m.cube('yellow',(0,18,-8),(7,3,2));m.cube('yellow',(0,20,-7),(3,4,2))
  for s in [-1,1]:m.cube('red',(s*3.8,13,-9),(3,5,1),(0,0,s*20)).cube('gray',(s*4,17,-5),(2,5,4),(0,0,-s*20))
  m.bone('mane',(0,12,-3),'body').round('white',(0,14,1),(11,7,13))
  for s in [-1,1]:
   for z in [0,4,8]:m.cube('gray',(s*4.8,10,z),(2,5,3),(0,0,-s*30))
  m.bone('tail',(0,10,8),'body').cube('brown',(0,11,13),(3,2,9),(20,0,0))
 else:
  m.cube('blue',(0,21,-7),(5,5,2),(0,0,45)).cube('cyan',(0,21,-8.05),(2.5,2.5,.15),(0,0,45))
  m.bone('mane',(0,15,-4),'body').round(mane,(0,16,2),(10,9,16))
  for s in [-1,1]:
   for z in [-1,4]:m.cube('white',(s*4.05,9,z),(.35,2.5,2.5),(25,0,0))
   m.bone('tail_'+str(s),(s*2,10,8),'body')
   for i in range(5):m.cube('white',(s*(3+i),10+math.sin(i)*2,10+i*2),(1.2,1.2,3),(0,s*25,0))
 models.append(m.save())
# Darkrai: floating ragged torso, red collar and white swept crest.
m=Model(491,'darkrai');m.bone('body',(0,11,0)).round('black',(0,11,0),(8,12,5))
for x in [-3,0,3]:m.cube('black',(x,4,0),(2,7,3),(0,0,x*8))
m.bone('head',(0,17,0),'body').round('black',(0,18,0),(5,6,5)).cube('cyan',(-1.2,18.5,-2.6),(1.6,.8,.3)).cube('white',(0,21,.2),(6,5,4),(0,0,-25)).cube('white',(3,24,1),(3,5,3),(0,0,-40))
for s,n in [(-1,'left'),(1,'right')]:
 m.cube('red',(s*3.7,16,-1),(3,5,4),(0,0,-s*25));m.bone('arm_'+n,(s*4,14,0),'body').cube('black',(s*6,10,0),(3,9,3),(0,0,s*20))
 for f in [-1,0,1]:m.cube('black',(s*7+f,5,-.6),(1,4,2),(0,0,f*12))
models.append(m.save())
# Genesect: mechanical bug and distinct shoulder-mounted cannon.
m=Model(649,'genesect');m.bone('body',(0,10,0)).round('purple',(0,10,0),(7,9,5)).cube('gray',(0,9,-2.6),(4,5,.8));m.bone('head',(0,16,0),'body').round('purple',(0,17,-1),(10,6,5)).cube('pink',(0,17,-3.6),(7,1.5,.5))
m.bone('cannon',(0,16,3),'body').cube('purple',(0,20,3),(5,4,9)).cube('black',(0,20,-1.8),(3,2,.6)).cube('orange',(0,22.1,4),(2,.4,2))
for s,n in [(-1,'left'),(1,'right')]:
 m.bone('arm_'+n,(s*4,13,0),'body').cube('purple',(s*6,10,-1),(2,7,3),(0,0,s*30)).cube('gray',(s*7,7,-2),(2.5,2,4))
 m.bone('leg_'+n,(s*2,7,0),'body').cube('purple',(s*3,4,1),(3,7,3),(0,0,-s*18)).cube('gray',(s*4,1,-1),(3,2,5))
models.append(m.save())
# Zygarde 10%: the actual dog form, not the 50% serpent.
m=Model(718,'zygarde_10');m.bone('body',(0,8,0)).round('black',(0,8,1),(6,6,12))
for s in [-1,1]:
 for z,n in [(-4,'front'),(5,'rear')]:m.bone('leg_'+n+str(s),(s*2,7,z),'body').cube('black',(s*2,3.5,z),(1.8,7,2)).cube('green',(s*2,.7,z-.5),(2,1.5,3))
m.bone('head',(0,12,-4),'body').round('black',(0,13,-6),(6,6,5)).cube('black',(0,11,-9),(4,3,4)).eyes(1.7,14,-8.6,'white',.7)
for s in [-1,1]:m.cube('black',(s*2,17,-5),(2,5,2),(0,0,-s*10)).cube('green',(s*2,17,-6.1),(1,3,.3))
m.bone('scarf',(0,11,-3),'body').cube('green',(0,11,-3),(7,2,6)).cube('green',(3,9,0),(2,5,3),(0,0,-20))
m.bone('tail',(0,10,7),'body').cube('black',(0,12,10),(2,2,8),(-25,0,0)).cube('green',(0,13.5,13),(2,2,3))
for s in [-1,1]:
 for z in [0,3]:m.bone('mark_'+str(s)+'_'+str(z),(0,0,0),'body').cube('green',(s*3.1,8,z),(.3,1.7,1.7),(25,0,0))
models.append(m.save())
(OUT/'models.json').write_text(json.dumps(models,indent=2))
print('authored',len(models),'models',sum(m['cubes']for m in models),'cubes')
