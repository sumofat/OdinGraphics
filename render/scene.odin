package render

import D3D11 "vendor:directx/d3d11"
import D3D12 "vendor:directx/d3d12"
import DXGI  "vendor:directx/dxgi"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import runtime "core:runtime"
import la "core:math/linalg"
import m "core:math/linalg/hlsl"
import fmt "core:fmt"
import con "../containers"
import camera "../render/camera"
import cgltf "../libs/odin_cgltf"


Scene :: struct 
{
    name : string,
    buffer : con.Buffer(u64),
    state_flags : SceneState,
    //lights : con.Buffer(Light),
};

SceneState :: enum
{
    default,//default state nothing happened
    loading,
    loaded,
    unloading,
    unloaded,
    serializing,
    serialized,
};

SceneStatus :: struct
{
    state_flags : u32,
    object_count : u32,
};


SceneObjectType :: enum {
	Empty,
	Mesh,
}

SceneObject :: struct{
    name : string,//for editor only
    transform : Transform,
    children : con.Buffer(u64),
    m_id : u64,//matrix id refers to asset table matrix buffer
    import_type : SceneObjectType,//user defined type
    type : SceneObjectType,
    data : rawptr,//user defined data typically ptr to a game object etcc...
    primitives_range : m.float2,
}

scene_object_init :: proc(name : string) -> SceneObject{
    result : SceneObject
    ot := transform_init()
    
    result.transform = ot
    result.name = name
    result.children = con.buf_init(1,u64)
    return result
}


scene_add_so :: proc(scene_object_buffer : ^con.Buffer(u64),p : m.float3,q : la.Quaternionf32,s : m.float3,name : string) -> u64{
    using con;        
    assert(scene_object_buffer != nil);

    new_so := scene_object_init("New Scene Object");
	new_so.m_id = cpu_matrix_buffer->add_matrix(new_so.transform.mat)
    //new_so.m_id = buf_push(&cpu_matrix_buffer,new_so.transform.mat);
    new_so.transform.p = p;
    new_so.transform.r = q;
    new_so.transform.s = s;
    
    so_id := buf_push(&asset_table.scene_objects,new_so);

    buf_push(scene_object_buffer,so_id);
    return so_id;
}

//NOTE(Ray):When adding a chid ot p is local position and p is offset from parents ot p.
add_child_to_scene_object_with_transform :: proc(ctx : ^AssetContext,parent_so_id : u64,new_child : ^Transform,data : ^rawptr,name : string) -> u64
{
    using con;
    assert(ctx != nil);
    assert(new_child != nil);
    //and the local p is the absolute p relative to the parent p.
    new_child.local_p = new_child.p;
    new_child.local_s = new_child.s;
    new_child.local_r = new_child.r;
    
    //New child p in this contex is the local p relative to the parent p reference frame
//		new_child->p  += rotate(so->transform.r, new_child->p);
    //Rotations add
//		new_child->r = so->transform.r * new_child->r;
//		new_child->s = so->transform.s * new_child->s;
    //SceneObject* new_so = AddSceneObject(&so->children, new_child);
    
    new_so : SceneObject;
    new_so.children = buf_init(1,u64);
    new_so.transform = new_child^;
	new_so.m_id = cpu_matrix_buffer->add_matrix(new_so.transform.mat)
    //new_so.m_id = buf_push(&asset_tables.matrix_buffer,new_so.transform.m);
    new_so.name = name;
    //new_so.parent = so;
    if data != nil
    {
	new_so.data = data^;	
    }
    
    so_id := buf_push(&ctx.scene_objects,new_so);

    parent_so := buf_chk_out(&ctx.scene_objects,parent_so_id);
    if len(parent_so.children.buffer) == 0
    {
        parent_so.children = buf_init(1,u64);
    }
    
    buf_push(&parent_so.children,so_id);
    buf_chk_in(&ctx.scene_objects);
    
    return so_id;
}

//NOTE(Ray):When adding a chid ot p is local position and p is offset from parents ot p.
add_new_child_to_scene_object :: proc(ctx : ^AssetContext,parent_so_id : u64,p : m.float3,r : la.Quaternionf32,s : m.float3,data : ^rawptr,name : string) -> u64{
    assert(ctx != nil);
    new_child := transform_init();
    new_child.p = p;
    new_child.r = r;
    new_child.s = s;
    transform_update(&new_child);
    return add_child_to_scene_object_with_transform(ctx,parent_so_id,&new_child,data,name);
}

add_child_to_scene_object :: proc(ctx : ^AssetContext,parent_so_id : u64,child_so_id : u64,transform : Transform)
{
    using con;
    assert(ctx != nil);    
        //and the local p is the absolute p relative to the parent p.
    t := transform;
    t.local_p = transform.p;
    t.local_s = transform.s;
    t.local_r = transform.r;

    //get the model so
    buf_chk_out(&ctx.scene_objects,child_so_id).transform = t;
    child_so := buf_get(&ctx.scene_objects,child_so_id);

//    assert(child_so != nil);
//    child_so.transform = t;
    buf_chk_in(&ctx.scene_objects);

    //Add this instance to the children of the parent so 
    parent := buf_chk_out(&ctx.scene_objects,parent_so_id);
    handle := buf_push(&parent.children,child_so_id);
    buf_chk_in(&ctx.scene_objects);
}

//NOTE(Ray):For updating all scenes?
update_scene :: proc(ctx : ^AssetContext,scene : ^Scene){
    assert(ctx != nil);    
    product := la.QUATERNIONF32_IDENTITY;
    sum := m.float3{};
    update_scene_objects(ctx,&scene.buffer,&sum,&product);
}

update_scene_objects :: proc(ctx : ^AssetContext,scene_objects_buffer : ^con.Buffer(u64), position_sum : ^m.float3, rotation_product : ^la.Quaternionf32){
    using con;
	scene_objects_buffer_ptr := scene_objects_buffer

    for i := 0;i < cast(int)buf_len(scene_objects_buffer_ptr^);i+=1{
        child_so_index := buf_chk_out(scene_objects_buffer_ptr,cast(u64)i);        
        so := buf_chk_out(&ctx.scene_objects,child_so_index^);
        buf_chk_in(scene_objects_buffer_ptr);
        parent_ot := &so.transform;
        transform_update(parent_ot);
        current_p_sum := position_sum^;
        current_p_sum = current_p_sum + parent_ot.p;
        rotation_product^ = la.quaternion_inverse(parent_ot.local_r);
        update_children(ctx,so, &current_p_sum, rotation_product);
        buf_chk_in(&ctx.scene_objects);
    }
}

update_children :: proc( ctx : ^AssetContext,parent_so : ^SceneObject,position_sum : ^m.float3,rotation_product : ^la.Quaternionf32){
    using con;
    child_so : ^SceneObject;
    for i := 0;i < cast(int)buf_len(parent_so.children);i+=1{
        child_so_index := buf_chk_out(&parent_so.children,cast(u64)i);
        child_so = buf_chk_out(&ctx.scene_objects,child_so_index^);        
        ot := &child_so.transform;
        current_p_sum := position_sum^;
        current_r_product := (rotation_product^);

//        ot.s = parent_so.transform.s;//ot.local_s;

        ot.s = parent_so.transform.s * ot.local_s;
        
        test := (ot.local_p * parent_so.transform.s);
        current_p_sum = current_p_sum + rotate(current_r_product,test);
	    ot.p = current_p_sum;

	    
        ot.r = la.mul(current_r_product,ot.local_r);//(quaternion_mul(current_r_product,ot.local_r));
	    current_r_product = ot.r;
        
        
        update_children(ctx,child_so, &current_p_sum, &current_r_product);
        buf_chk_in(&parent_so.children.buffer);
        buf_chk_in(&ctx.scene_objects);
    }
}

