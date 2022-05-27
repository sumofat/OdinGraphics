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
import mem "core:mem"
import strings "core:strings"
import stbi "vendor:stb/image"
import hash "core:hash"

Alpha_Mode :: enum{
	opaque,
	mask,
	blend,
}

Component_Type :: enum{
	invalid,
	r_8,   /*BYTE */
	r_8u,  /*UNSIGNED_BYTE */
	r_16,  /*SHORT */
	r_16u, /*UNSIGNED_SHORT */
	r_32u, /*UNSIGNED_INT */
	r_32f, /*FLOAT */
}

AP_GLTF_Version :: struct{
	no : int,
}

//Seperate cpu and gpu mesh even if we have to duplicate some 
//struct properties.

//An instance of an imported mesh 
//has a reference via gpu loaded imported mesh
AP_Render_Mesh_Instance :: struct{
	imported_mesh : ^AP_Imported_Mesh,
	//gpu stuff
}

AP_Imported_Mesh_Property_Type :: union{
	rawptr,
	Component_Type,
	uint,
	int,
	u16,
	u32,
	u64,
	m.float,
	m.float4,
	con.Buffer(f32),
	con.Buffer(u64),
	con.Buffer(u32),
}

AP_Imported_Material_Property_Type :: union{
	bool,
	m.float,
	m.float4,
	string,
	Alpha_Mode,
	//texture etc..
}

AP_Imported_Material_Property :: struct{
	name : string,
	prop : AP_Imported_Material_Property_Type,
}

AP_Imported_Mesh_Property :: struct{
	name : string,
	prop : AP_Imported_Mesh_Property_Type,
}

AP_Imported_Material :: struct{
	name : string,
	properties : map[string]AP_Imported_Material_Property,
}

//Ground truth mesh
AP_Imported_Mesh :: struct{
	id : int,
	name : string,
	properties : map[string]AP_Imported_Mesh_Property,
	material_name : string,
	primitives : con.Buffer(AP_Imported_Mesh),
}

AP_Imported_Texture :: struct{
	id : int,
	name : string,
	dim : m.float2,
	byte_size : int,
	texels : rawptr,
	sampler : AP_Imported_Sampler,
}

AP_Imported_Sampler :: struct{
	id : int,
	name : string,
}

Asset_Pipeline :: struct{
	meshes : con.Buffer(AP_Imported_Mesh),
	materials : con.Buffer(AP_Imported_Material),
	textures : con.Buffer(AP_Imported_Texture),
//	animations : con.Buffer(AP_Animation),
//	skins : con.Buffer(AP_Skins),

}

//Asset runtime is our runtime loaded assets that we have access too.
//Instances will be loaded from to and off based on need from scene.
//Imported assets are the disk deserialized master
//we than reference them from the runtime here.
//NOTE(RAY):The below is an idea that I have thrown but leaving this commen here 
//for follow up maybe?
//If we dont need them anymore we remove them from the APImported master list
//them from runtime access here.  We need to set instance to be destroyed
//and those who ave references to them can get an "event" or know it will soon 
//dissapear by having a callback that will run before destruction so that 
//it may dissapear gracefully.  Or assert if its too early.
AssetRuntime :: struct{
	mesh_instances : con.Buffer(MeshInstance),
}

//Will remove callback will be called several frames before actually removed.
//so that we can react ahead of time if wish to do.
MeshInstance :: struct{
	mesh : ^AP_Imported_Mesh,
	material : ^AP_Imported_Material,
}

//Mesh component has an array of all meshes to be renderered
//so equivalent to a given gltf mesh and all of its primitives.
//When attaching a Mesh component you just need to set its mesh 
//instance id to a valid instance id of a mesh
//api should be add mesh which should be a full array of submeshes.
//in other words a mesh is not just one but many primitives/submeshes.
MeshComponent :: struct{
	id : int,
	//mesh : MeshInstance,
	mesh : AP_Imported_Mesh,
}

SceneComponent :: union{
	MeshComponent,
}

SceneNode :: struct{
	name : string,
	transform : Transform,
	m_id : u64,
	children : con.Buffer(SceneNode),
	component : con.Buffer(SceneComponent),
}

asset_pipeline : Asset_Pipeline
scene_nodes : con.Buffer(SceneNode)
ap_texture_cache : con.AnyCache(u64,AP_Imported_Texture)

init_asset_pipeline :: proc(){
	using con
	asset_pipeline.meshes = buf_init(1,AP_Imported_Mesh)
	scene_nodes = buf_init(1,SceneNode)
	asset_pipeline.textures = buf_init(1,AP_Imported_Texture)
	asset_pipeline.materials = buf_init(1,AP_Imported_Material)
	ap_texture_cache = anycache_init(u64,AP_Imported_Texture,false)
}

load_node :: proc(gltf_node : ^cgltf.node,list : ^con.Buffer(SceneNode)){
	using con
	assert(list != nil)
	node := SceneNode{}
	node.name = string(gltf_node.name)
	node.component = buf_init(1,SceneComponent)
	node.children = buf_init(1,SceneNode)
	node.transform = transform_init()			

	fmt.println("Loading node with name : ",node.name)
	children := gltf_node.children[:gltf_node.children_count]
	for child in children{
		load_node(child,&node.children)
	}

	if gltf_node.mesh != nil{
		//loadmeshes and all submeshes recursively
		//add a scene node with a mesh component
		mesh_result := load_mesh(gltf_node.mesh)
		mesh_comp := MeshComponent{0,mesh_result}
		buf_push(&node.component,mesh_comp)
	}
	buf_push(list,node)
}

load_scene :: proc(path : string) -> (bool){
	using con
	using asset_pipeline
	using fmt

	//get file extension
	//load mesh based on extension
	//for now supporting glb /gltf files only

	//get meshes and all neccessary properties
    options : cgltf.options
    cgltf_data : ^cgltf.data
    aresult := cgltf.parse_file(&options,strings.clone_to_cstring(path), &cgltf_data)    
    assert(aresult == cgltf.result.success)

	if aresult == cgltf.result.success{
        for i : int = 0;i < int(cgltf_data.buffers_count);i += 1{
            uri := cgltf_data.buffers[i].uri
            rs := cgltf.load_buffers(&options, cgltf_data, uri)
            assert(rs == cgltf.result.success)
        }

		if cgltf_data.nodes_count == 0{return false}
		println("Loading Asset: ",path)
		println("CGLTF Asset VERSION : ",cgltf_data.asset.version)

		assert(cgltf_data.scenes_count == 1)
		scenes := cgltf_data.scenes[:cgltf_data.scenes_count]
		for scene in scenes{
			nodes := scene.nodes[:scene.nodes_count]
			for node in nodes{
				println(scene)
				root_node := SceneNode{}
				root_node.name = "root"
				root_node.component = buf_init(1,SceneComponent)
				root_node.children = buf_init(1,SceneNode)
				root_node.transform = transform_init()			
				buf_push(&scene_nodes,root_node)
				load_node(node,&root_node.children)
			}
		}
		load_all_materials(cgltf_data)
		load_all_textures(cgltf_data)
	}
	return true
}

get_texture :: proc(uri : string,ptr : ^u8,size : int) -> (AP_Imported_Texture,bool){
    result : AP_Imported_Texture
    using con

    lookup_key := u64(hash.murmur64(transmute([]u8)uri))
    if anycache_exist(&ap_texture_cache,lookup_key){
        t := anycache_get(&ap_texture_cache,lookup_key)
            return t,true
    }else{
		desired_channels : i32 = 4
        tex_loaded_result :=  texture_from_mem(ptr,i32(size),4)   
		if tex_loaded_result.texels == nil{
			return result,false
		}

        anycache_add(&ap_texture_cache,lookup_key,result)
        
		return result,true
    }
}

get_texture_id :: proc(texture : ^cgltf.texture)->string{
	assert(texture != nil)
	offset := cast(u64)texture.image.buffer_view.offset
	to_image_path : string
	if texture.image.uri != ""{
		to_image_path = string(texture.image.uri)
	}else{
		to_image_path = fmt.tprintf("%d",offset + 1)
	}

	//fmt.printf("Image URI: %s",image_uri)
	//we will use the path to the mesh + the name of the texture to get lookup key using path.
	//this is ok but stil requires the namem to bbe unique inside the gltf file
	slice_path_name := []string{to_image_path}
	path_and_texture_name := strings.concatenate(slice_path_name,context.temp_allocator)
	return path_and_texture_name
}

load_all_textures :: proc(cgltf_data : ^cgltf.data){
	textures := cgltf_data.textures[:cgltf_data.textures_count]
	for texture in &textures{
		new_texture : AP_Imported_Texture
		new_texture.name = string(texture.name)

		if texture.image == nil{continue}
		offset := cast(u64)texture.image.buffer_view.offset
		tex_data := mem.ptr_offset(cast(^u8)texture.image.buffer_view.buffer.data,cast(int)offset)
		fmt.println(offset)
		assert(tex_data != nil)
		data_size := cast(u64)texture.image.buffer_view.size

		//TODO(Ray):Revisit this texture stuff seems like a bit of nonsense.
		if t,ok := get_texture(get_texture_id(&texture),tex_data,int(data_size));ok{
			new_texture.dim = t.dim
			new_texture.byte_size = int(t.byte_size)
			new_texture.texels = t.texels
			con.buf_push(&asset_pipeline.textures,new_texture)
		}else{
			assert(false)
		}
	}
}

load_all_materials :: proc(cgltf_data : ^cgltf.data){
	materials := cgltf_data.materials[:cgltf_data.materials_count]
	for material in materials{
		using material

		fmt.println("Loading material : ", material.name)
		new_material : AP_Imported_Material
		new_material.properties = make(map[string]AP_Imported_Material_Property)
		new_material.name = string(name)

		//get and load textures on material
		if has_pbr_metallic_roughness{
			//get texture from glb or directory
		fmt.println(material.pbr_metallic_roughness)
			if pbr_metallic_roughness.base_color_texture.texture != nil{
				id := get_texture_id(pbr_metallic_roughness.base_color_texture.texture)
				fmt.println("Material has base texture : ",id)
				new_material.properties["base_texture_id"] = {"base_texture_id",id}
			}
			new_material.properties["base_color_factor"] = {"base_color_factor",m.float4(material.pbr_metallic_roughness.base_color_factor)}
			if pbr_metallic_roughness.metallic_roughness_texture.texture != nil{
				new_material.properties["mettalic_rougness_texture_id"] = {"mettalic_rougness_texture_id",get_texture_id(pbr_metallic_roughness.metallic_roughness_texture.texture)}
			}
			new_material.properties["metallic_factor"] = {"metallic_factor",pbr_metallic_roughness.metallic_factor}
			new_material.properties["roughness_factor"] = {"roughness_factor",pbr_metallic_roughness.roughness_factor}
			//extras? 
		}
//TODO(Ray):Add these in later 
		if has_pbr_specular_glossiness{
			//specular texture
			//glossinesss
			//diffuse factor
			//specular 
			//glossiness
		}
		//normal texture
		if pbr_metallic_roughness.base_color_texture.texture != nil{
			new_material.properties["base_texture_id"] = {"base_texture_id",get_texture_id(pbr_metallic_roughness.base_color_texture.texture)}
		}

		//emiisive texture
		//emmisive factor

		//ignore others for now

		//properties
		new_prop : AP_Imported_Material_Property
		new_prop.name = "alpha_mode"
		new_prop.prop = Alpha_Mode(alpha_mode) 
		new_material.properties["alpha_mode"] = new_prop

		new_prop.name = "alpha_cutoff"
		new_prop.prop = m.float(alpha_cutoff) 
		new_material.properties["alpha_cutoff"] = new_prop

		new_prop.name = "double_sided"
		new_prop.prop = bool(double_sided) 
		new_material.properties["double_sided"] = new_prop

		new_prop.name = "unlit"
		new_prop.prop = bool(unlit) 
		new_material.properties["unlit"] = new_prop

		//etc...
	}
}

load_primitive :: proc(primitive : cgltf.primitive)-> (AP_Imported_Mesh,bool){
	mesh : AP_Imported_Mesh
	if primitive.type != .triangles{return mesh,false}
	if primitive.indices != nil{
		using primitive
		istart_offset := indices.offset + indices.buffer_view.offset
		ibuf := indices.buffer_view.buffer                

		if indices.component_type == .r_16u{

			indices_size :=  cast(u64)indices.count * size_of(u16)
			indices_buffer := cast(^u16)mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset)
			outindex_f := cast(^u16)mem.alloc(cast(int)indices_size)

			mem.copy(outindex_f,indices_buffer,cast(int)indices_size)
			mesh.properties["index_type"] = AP_Imported_Mesh_Property{"index_type",.r_16u}
			mesh.properties["index_data"] = AP_Imported_Mesh_Property{"index_data",rawptr(outindex_f)}
			mesh.properties["index_size"] = AP_Imported_Mesh_Property{"index_size",size_of(u16) * cast(u64)indices.count}
			mesh.properties["index_count"] = AP_Imported_Mesh_Property{"index_count",indices.count}
			//con.buf_push(&mesh.properties,AP_Imported_Material_Property{"indices",rawptr(outindex_f)})
			//mesh.index_16_data = outindex_f
			//mesh.index_16_data_size = size_of(u16) * cast(u64)indices.count
			//mesh.index16_count = cast(u64)indices.count                    
		}else if primitive.indices.component_type == .r_32u{

			indices_size :=  cast(u64)indices.count * size_of(u32)
			indices_buffer := cast(^u32)(mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset))
			outindex_f := cast(^u32)mem.alloc(cast(int)indices_size)

			mem.copy(outindex_f,indices_buffer,cast(int)indices_size)
			
			mesh.properties["index_type"] = AP_Imported_Mesh_Property{"index_type",.r_32u}
			mesh.properties["index_data"] = AP_Imported_Mesh_Property{"index_data",rawptr(outindex_f)}
			mesh.properties["index_size"] = AP_Imported_Mesh_Property{"index_size",size_of(u32) * cast(u64)indices.count}
			mesh.properties["index_count"] = AP_Imported_Mesh_Property{"index_count",indices.count}
		}
	}

	attributes := primitive.attributes[:primitive.attributes_count]
	tex_i : int
	for attribute in attributes{
		accessor := attribute.data
		count := accessor.count
		buffer_view := accessor.buffer_view
		using attribute

		start_offset := buffer_view.offset
		stride := buffer_view.stride
		buffer := buffer_view.buffer
		buffer_ptr := (^f32)(mem.ptr_offset(cast(^u8)buffer.data,cast(int)start_offset))
		if accessor.is_sparse{
			//If we get data like this stop and think
			assert(false)
		}

		num_floats := accessor.count * cgltf.num_components(accessor.type)
		num_bytes := size_of(f32) * num_floats                
		outf := cast(^cgltf.cgltf_float)mem.alloc(cast(int)num_bytes)
		csize := cgltf.accessor_unpack_floats(accessor,outf,num_floats)

		if type == .position{
			mesh.properties["position_data"] = AP_Imported_Mesh_Property{"position_data",rawptr(outf)}
			mesh.properties["position_size"] = AP_Imported_Mesh_Property{"position_size",num_bytes}
			mesh.properties["position_count"] = AP_Imported_Mesh_Property{"position_count",count}
		}

		if type == .normal{
			mesh.properties["normal_data"] = AP_Imported_Mesh_Property{"normal_data",rawptr(outf)}
			mesh.properties["normal_size"] = AP_Imported_Mesh_Property{"normal_size",num_bytes}
			mesh.properties["normal_count"] = AP_Imported_Mesh_Property{"normal_count",count}
		}

		if type == .tangent{
			mesh.properties["tangent_data"] = AP_Imported_Mesh_Property{"tangent_data",rawptr(outf)}
			mesh.properties["tangent_size"] = AP_Imported_Mesh_Property{"tangent_size",num_bytes}
			mesh.properties["tangent_count"] = AP_Imported_Mesh_Property{"tangent_count",count}
		}

		if type == .texcoord{
			//NOTE(RAY):We only support one set of texcoords right now
			assert(tex_i < 1)

			mesh.properties["tex_coord"] = AP_Imported_Mesh_Property{"texcoord",rawptr(outf)}
			mesh.properties["tex_coord_size"] = AP_Imported_Mesh_Property{"tex_coord_size",num_bytes}
			mesh.properties["tex_coord__count"] = AP_Imported_Mesh_Property{"tex_coord_count",count}

			tex_i += 1
		}
	}
	return mesh,true
}


load_mesh :: proc(using mesh : ^cgltf.mesh) -> AP_Imported_Mesh{
	result : AP_Imported_Mesh
	prims := primitives[:primitives_count]
	result.primitives = con.buf_init(u64(primitives_count),AP_Imported_Mesh)
	for primitive in prims{
		if primitive_mesh,ok := load_primitive(primitive);ok{
			con.buf_push(&result.primitives,primitive_mesh)
		}
	}
	return result
}

unload_imported_mesh :: proc()-> bool{
	return false
}

//CPULOADING PROCEDURES
load_glb_scene :: proc(){

}

load_gltf_scene :: proc(){

}
/*
load_meshes :: proc(){

}
*/

//GPU LOADING PROCs
//Loads things into gpu for by the renderer also aloow these to be implemented 
//by a specific renderer for custom uses.





