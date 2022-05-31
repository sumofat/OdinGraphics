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
import camera "camera"
import intrinsics "core:intrinsics"

base_list : BaseRenderCommandList

RenderCommand :: struct{
	geometry : RenderGeometry,
	material : AP_Imported_Material,
	model_matrix : m.float4x4,
	//camera_matrix :      m.float4x4,
	//perspective_matrix : m.float4x4,
	texture_range : m.int2, 
	is_indexed:bool,
	material_name:string,
}

RenderGeometryBufferType :: enum{
	position,
	normal,
	texcoords,
	tangent,
	bitangent,
}

RenderGeometryBuffer :: struct{
	type : RenderGeometryBufferType,
	buffer : rawptr,
	size : int,
	count : int,
	stride : int,
	vertex_buffer : VertexBuffer,
}

RenderGeometry :: union{
	RenderGeometryIndexed,
	RenderGeometryNonIndexed,
}

RenderGeometryIndexed :: struct {
	index_buffer: rawptr,
	buffers_info : con.Buffer(RenderGeometryBuffer),
	buffers : con.Buffer(rawptr),
	buffers_strides : con.Buffer(u32),
	buffers_offsets : con.Buffer(u32),
	count:           int,
	offset:          int,
	index_count:     int,
	is_indexed:      bool,
	base_color:      m.float4,
}

RenderGeometryNonIndexed :: struct {
	buffers_info : con.Buffer(RenderGeometryBuffer),
	buffers : con.Buffer(rawptr),
	buffers_strides : con.Buffer(u32),
	buffers_offsets : con.Buffer(u32),
	count:           int,
	offset:          int,
	index_id:        int,
	index_count:     int,
	is_indexed:      bool,
	base_color:      m.float4,
}

create_list :: proc()-> BaseRenderCommandList{
	return {con.buf_init(1,RenderCommand)}
}

ReadMeshAttributeResult :: struct{
	p_data : rawptr,
	p_size : int,
	p_count : int,
	p_stride : int,

	n_data : rawptr,
	n_size : int,
	n_count : int,
	n_stride : int,

	t_data : rawptr,
	t_size : int,
	t_count : int,
	t_stride : int,

	tc_data : rawptr,
	tc_size : int,
	tc_count : int,
	tc_stride : int,
}

read_mesh_attributes :: proc(using prim : AP_Imported_Mesh,geo : ^$T)where RenderGeometryIndexed == T || RenderGeometryNonIndexed == T{
	using con
	using result : ReadMeshAttributeResult

	if geo.buffers.is_init == false{
		geo.buffers = buf_init(1,rawptr)
		geo.buffers_strides = buf_init(1,u32)
		geo.buffers_offsets = buf_init(1,u32)
	}

	p_data = properties["position_data"].prop.(rawptr)
	p_size = properties["position_size"].prop.(int)
	p_count = properties["position_count"].prop.(int)
	p_stride = properties["position_stride"].prop.(int)
	vb := init_vertex_buffer(render_device,p_data,u32(p_size))
	buf_push(&geo.buffers,vb.ptr)
	buf_push(&geo.buffers_strides,u32(p_stride))
	buf_push(&geo.buffers_offsets,0)

	//new_buffer : RenderGeometryBuffer = {.position,p_data,p_size,p_count,p_stride,vb}
	//buf_push(buf,new_buffer)

	n_data = properties["normal_data"].prop.(rawptr)
	n_size = properties["normal_size"].prop.(int)
	n_count = properties["normal_count"].prop.(int)
	n_stride = properties["normal_stride"].prop.(int)
	vb = init_vertex_buffer(render_device,n_data,u32(n_size))
	buf_push(&geo.buffers,vb.ptr)
	buf_push(&geo.buffers_strides,u32(n_stride))
	buf_push(&geo.buffers_offsets,0)
//	new_buffer = {.normal,n_data,n_size,n_count,n_stride,vb}
//	buf_push(buf,new_buffer)

	t_data = properties["tangent_data"].prop.(rawptr)
	t_size = properties["tangent_size"].prop.(int)
	t_count = properties["tangent_count"].prop.(int)
	t_stride = properties["tangent_stride"].prop.(int)
	vb = init_vertex_buffer(render_device,t_data,u32(t_size))
	buf_push(&geo.buffers,vb.ptr)
	buf_push(&geo.buffers_strides,u32(t_stride))
	buf_push(&geo.buffers_offsets,0)
//	new_buffer = {.tangent,t_data,t_size,t_count,t_stride,vb}
//	buf_push(buf,new_buffer)

	tc_data = properties["tex_coord"].prop.(rawptr)
	tc_size = properties["tex_coord_size"].prop.(int)
	tc_count = properties["tex_coord_count"].prop.(int)
	tc_stride = properties["tex_coord_stride"].prop.(int)
	vb = init_vertex_buffer(render_device,tc_data,u32(tc_size))
	buf_push(&geo.buffers,vb.ptr)
	buf_push(&geo.buffers_strides,u32(tc_stride))
	buf_push(&geo.buffers_offsets,0)

//	buf_push(buf,new_buffer)
}

read_node :: proc(parent_node : ^SceneNode){
	fmt.println("NODE : ",parent_node.name)
	for node in &parent_node.children.buffer{
		read_node(&node)
	}

	for comp in parent_node.component.buffer{
		if mesh_component,ok := comp.(MeshComponent);ok{
			mesh : AP_Imported_Mesh = mesh_component.mesh
			fmt.println("Mesh Found : ",mesh.name)
			for primitive_mesh in mesh.primitives.buffer{
				new_com : RenderCommand
				new_com.is_indexed = primitive_mesh.is_indexed
				if_geo : bool
				if primitive_mesh.is_indexed{
					if_geo = true
					new_geo : RenderGeometryIndexed
					index_type := primitive_mesh.properties["index_type"].prop
					using primitive_mesh
					if index_type.(Component_Type) == .r_16u{
						new_geo.index_buffer = properties["index_data"].prop.(rawptr)
						new_geo.index_count = properties["index_count"].prop.(int)
					}else if index_type.(Component_Type) == .r_32u{
						new_geo.index_buffer = properties["index_data"].prop.(rawptr)
						new_geo.index_count = properties["index_count"].prop.(int)
					}else{
						fmt.println("ERROR: NO proper component type on indexed mesh")
					}
					read_mesh_attributes(primitive_mesh,&new_geo)
					new_com.geometry = new_geo
				}else{
					new_geo : RenderGeometryNonIndexed
					read_mesh_attributes(primitive_mesh,&new_geo)
					new_com.geometry = new_geo
				}

				mat_name := primitive_mesh.properties["material_id"].prop.(string)

				mat_name_id := con.hash_get_from_string(mat_name)
				new_com.material = con.anycache_get(&ap_material_cache,mat_name_id)
				
				//com.material_name = mesh.material_name
				//com.texture_id = mesh.metallic_roughness_texture_id
				//com.model_matrix_id = child_so.m_id
				//com.camera_matrix_id = c_mat

				//com.perspective_matrix_id = p_mat
	
				if if_geo{
					test_ren_def := get_renderer("deffered",DefferedRenderer)
					con.buf_push(&test_ren_def.gbuff_data.render_commands,new_com)
				}
			}
		}
	}
}

read_nodes :: proc(node : ^SceneNode){
	read_node(node)
}

