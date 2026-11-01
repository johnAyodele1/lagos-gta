extends RefCounted
class_name LagosUnderpassSetpiece
const Bounds=preload("res://scripts/model_bounds.gd")
const ROOT="res://assets/models/lagos_underpass/"
static func build(parent:Node3D,roads:Array[Dictionary])->int:
 var count:=0
 for road in roads:
  var tags:Dictionary=road.get("tags",{})
  var highway:=str(road.get("highway",""))
  if highway not in ["primary","secondary","tertiary","motorway","trunk"]: continue
  var bridge:=str(tags.get("bridge","no")).to_lower()
  if bridge in ["","no","false","0"]: continue
  var points:Array=road.get("coordinates",[])
  if points.size()<2: continue
  _build_bridge(parent,points,float(road.get("width_m",8.0)))
  if count==0: _build_mechanic_bay(parent,points,float(road.get("width_m",8.0)))
  count+=1
 return count
static func _build_bridge(parent:Node3D,raw:Array,width:float)->void:
 var pts:Array[Vector2]=[]
 for p in raw: pts.append(Vector2(float(p[0]),float(p[1])))
 var concrete:=_mat(Color(0.34,0.34,0.32))
 for i in range(pts.size()-1):
  var delta:=pts[i+1]-pts[i]; var length:=delta.length()
  if length<3.0: continue
  var mid:Vector2=(pts[i]+pts[i+1])*0.5
  var yaw:=atan2(delta.x,delta.y)
  _box(parent,Vector3(width+2.4,0.24,length+0.4),Vector3(mid.x,4.88,mid.y),yaw,concrete,"BridgeDeckCollision")
  _box(parent,Vector3(width+2.4,0.9,length+0.4),Vector3(mid.x,4.48,mid.y),yaw,concrete,"BridgeUnderside")
  if i%2==0:
   var side:=Vector2(-delta.y,delta.x).normalized()
   for sign in [-1.0,1.0]:
    var p:Vector2=mid+side*(width*0.5+0.7)*sign
    _box(parent,Vector3(0.85,4.45,0.85),Vector3(p.x,2.225,p.y),0.0,concrete,"BridgePier")
    _box(parent,Vector3(1.3,0.24,1.3),Vector3(p.x,4.45,p.y),0.0,concrete,"PierCapital")
static func _build_mechanic_bay(parent:Node3D,points:Array,width:float)->void:
 var segment_index:=1 if points.size()>2 else 0
 var a:=Vector2(float(points[segment_index][0]),float(points[segment_index][1]))
 var b:=Vector2(float(points[segment_index+1][0]),float(points[segment_index+1][1]))
 var direction:Vector2=(b-a).normalized(); var side:=Vector2(-direction.y,direction.x)
 var span_midpoint:Vector2=(a+b)*0.5+direction*minf(a.distance_to(b)*0.25,8.0)
 var centre:Vector2=span_midpoint+side*(width*0.5+1.5)
 var bay:=Node3D.new(); bay.name="YabaUnderpassMechanicBay"
 bay.position=Vector3(centre.x,0,centre.y); bay.rotation.y=atan2(direction.x,direction.y); parent.add_child(bay)
 var wall:=_mat(Color(0.42,0.37,0.29)); var dark:=_mat(Color(0.12,0.13,0.12)); var yellow:=_mat(Color(0.94,0.68,0.08))
 _box(bay,Vector3(8,3.4,0.35),Vector3(0,1.7,0),0,wall,"WorkshopWall")
 _box(bay,Vector3(8.4,0.22,3.5),Vector3(0,3.48,1.55),0,dark,"CorrugatedCanopy")
 _box(bay,Vector3(5.8,0.85,0.12),Vector3(0,2.78,-0.22),0,yellow,"AutoElectricSign")
 var sign:=Label3D.new(); sign.name="YabaMechanicSign"; sign.text="AUTO ELECTRICAL  •  YABA"
 sign.font=load("res://assets/fonts/Roboto.ttf"); sign.font_size=42; sign.pixel_size=0.012
 sign.position=Vector3(0,2.72,-0.145); sign.modulate=Color(0.08,0.08,0.06); bay.add_child(sign)
 _box(bay,Vector3(2.7,2.45,0.16),Vector3(-2.25,1.22,-0.24),0,dark,"RollerDoor")
 _model(bay,"modular_factory_facade",Vector3(0,0,0.65),4.2)
 _model(bay,"portable_generator",Vector3(3,0,2.2),0.95)
 _model(bay,"concrete_road_barrier",Vector3(-4.7,0,2),0.8)
 _model(bay,"modular_industrial_pipes_01",Vector3(4.5,0,0.8),1.2)
static func _model(parent:Node3D,id:String,pos:Vector3,height:float)->void:
 if DisplayServer.get_name()=="headless": return
 var path:=ROOT+id+".glb"
 if not ResourceLoader.exists(path): return
 var packed:=load(path) as PackedScene
 if packed==null: return
 var node:=packed.instantiate() as Node3D
 if node==null: return
 node.name="PolyHaven_"+id; node.position=pos; parent.add_child(node); Bounds.fit_height(node,height)
static func _mat(color:Color)->StandardMaterial3D:
 var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=0.96; return m
static func _box(parent:Node3D,size:Vector3,pos:Vector3,yaw:float,material:Material,node_name:String)->void:
 var mesh:=MeshInstance3D.new(); mesh.name=node_name
 var shape_mesh:=BoxMesh.new(); shape_mesh.size=size; mesh.mesh=shape_mesh
 mesh.material_override=material; mesh.position=pos; mesh.rotation.y=yaw
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mesh)
 var body:=StaticBody3D.new(); body.name=node_name+"Collision"; body.position=pos; body.rotation.y=yaw
 var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape
 body.add_child(collision); parent.add_child(body)
