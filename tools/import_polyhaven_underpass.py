#!/usr/bin/env python3
"""Import curated Poly Haven CC0 GLB assets for the Yaba underpass."""
import hashlib,json,shutil,subprocess,urllib.request,zipfile
from pathlib import Path,PurePosixPath
from urllib.parse import urlparse
OUT=Path(__file__).resolve().parents[1]/"assets/models/lagos_underpass"
API="https://api.polyhaven.com"; UA="LagosGTA-AssetImporter/1.0 (https://github.com/johnAyodele1/lagos-gta)"
MAX=90*1024*1024
ASSETS={"modular_factory_facade":"mechanic workshop frontage","concrete_road_barrier":"weathered roadside barrier","portable_generator":"roadside generator","modular_industrial_pipes_01":"workshop pipework"}
def get(url,limit=MAX):
 r=urllib.request.Request(url,headers={"User-Agent":UA})
 with urllib.request.urlopen(r,timeout=90) as f:
  size=f.headers.get("Content-Length")
  if size and int(size)>limit: raise RuntimeError("Download exceeds size budget: "+url)
  data=f.read(limit+1)
 if len(data)>limit: raise RuntimeError("Download exceeds size budget: "+url)
 return data
def entries(v,path=()):
 out=[]
 if isinstance(v,dict):
  if isinstance(v.get("url"),str) and isinstance(v.get("size"),int): out.append({"url":v["url"],"size":v["size"],"md5":v.get("md5"),"path":"/".join(path).lower()})
  for k,x in v.items(): out+=entries(x,path+(str(k),))
 elif isinstance(v,list):
  for i,x in enumerate(v): out+=entries(x,path+(str(i),))
 return out
def extract(z,d):
 with zipfile.ZipFile(z) as f:
  for x in f.infolist():
   if not (d.resolve()/x.filename).resolve().is_relative_to(d.resolve()): raise RuntimeError("Unsafe ZIP path: "+x.filename)
  f.extractall(d)
def resolve(scene,metadata):
 doc=json.loads(scene.read_text()); by_name={}
 for x in entries(metadata): by_name.setdefault(PurePosixPath(urlparse(x["url"]).path).name,[]).append(x)
 for section in ("buffers","images"):
  for item in doc.get(section,[]):
   uri=item.get("uri","")
   if not uri or uri.startswith("data:"): continue
   target=(scene.parent/uri).resolve()
   if not target.is_relative_to(scene.parent.resolve()): raise RuntimeError("Unsafe glTF URI: "+uri)
   if target.is_file(): continue
   matches=by_name.get(PurePosixPath(uri).name,[])
   if not matches: raise RuntimeError("Missing glTF dependency: "+uri)
   x=min(matches,key=lambda a:a["size"]); data=get(x["url"])
   if x["md5"] and hashlib.md5(data).hexdigest().lower()!=str(x["md5"]).lower(): raise RuntimeError("MD5 mismatch: "+uri)
   target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
def import_one(asset):
 meta=json.loads(get(f"{API}/files/{asset}",12*1024*1024))
 choices=[x for x in entries(meta) if "gltf" in x["path"] and urlparse(x["url"]).path.lower().endswith((".zip",".gltf",".glb")) and x["size"]<=MAX]
 if not choices: raise RuntimeError("No glTF package <=90MiB: "+asset)
 choices.sort(key=lambda x:(0 if "1k" in x["path"] else 1 if "2k" in x["path"] else 2,x["size"]))
 x=choices[0]; data=get(x["url"])
 if x["md5"] and hashlib.md5(data).hexdigest().lower()!=str(x["md5"]).lower(): raise RuntimeError("Source checksum mismatch: "+asset)
 stage=OUT/(".stage-"+asset)
 if stage.exists(): shutil.rmtree(stage)
 stage.mkdir(parents=True); suffix=PurePosixPath(urlparse(x["url"]).path).suffix.lower(); src=stage/("source"+suffix); src.write_bytes(data)
 scene=None
 if suffix==".zip":
  extracted=stage/"extracted"; extracted.mkdir(); extract(src,extracted)
  scenes=list(extracted.rglob("*.glb"))+list(extracted.rglob("*.gltf"))
  if not scenes: raise RuntimeError("ZIP has no glTF: "+asset)
  scenes.sort(key=lambda p:(p.suffix!=".glb",len(p.parts))); scene=scenes[0]
 elif suffix==".glb":
  (OUT/(asset+".glb")).write_bytes(data)
 elif suffix==".gltf":
  scene=src
 else: raise RuntimeError("Unsupported glTF package: "+suffix)
 if scene is not None and scene.suffix==".gltf":
  resolve(scene,meta); target=OUT/(asset+".glb")
  subprocess.run(["gltf-transform","copy",str(scene),str(target)],check=True)
 if scene is not None and scene.suffix==".glb": shutil.copy2(scene,OUT/(asset+".glb"))
 target=OUT/(asset+".glb")
 if not target.is_file() or target.read_bytes()[:4]!=b"glTF": raise RuntimeError("Invalid GLB: "+asset)
 shutil.rmtree(stage,ignore_errors=True)
 print(f"{asset}: {target.stat().st_size:,} bytes")
def main():
 OUT.mkdir(parents=True,exist_ok=True); manifest={"source":"Poly Haven","license":"CC0 1.0","runtime_network_dependency":False,"assets":[]}
 for asset,purpose in ASSETS.items():
  import_one(asset); manifest["assets"].append({"id":asset,"purpose":purpose,"source":f"https://polyhaven.com/a/{asset}","license":"CC0 1.0"})
 (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
if __name__=="__main__": main()
