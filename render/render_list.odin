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

base_list : BaseRenderCommandList

create_list :: proc()-> BaseRenderCommandList{
	return {con.buf_init(1,RenderCommand)}
}

ReadMeshAttributeResult :: struct{
	p_data : rawptr,
	p_size : int,
	p_count : int,

	n_data : rawptr,
	n_size : int,
	n_count : int,

	t_data : rawptr,
	t_size : int,
	t_count : int,

	tc_data : rawptr,
	tc_size : int,
	tc_count : int,
}

read_mesh_attributes :: proc(using prim : AP_Imported_Mesh,buf : ^con.Buffer(RenderGeometryBuffer)){
	using con
	using result : ReadMeshAttributeResult
	
	if !buf.is_init{
		buf^ = buf_init(1,RenderGeometryBuffer)
	}

	p_data = properties["position_data"].prop.(rawptr)
	p_size = properties["position_size"].prop.(int)
	p_count = properties["position_count"].prop.(int)
	new_buffer : RenderGeometryBuffer = {.position,p_data,p_size,p_count}
	buf_push(buf,new_buffer)

	n_data = properties["normal_data"].prop.(rawptr)
	n_size = properties["normal_size"].prop.(int)
	n_count = properties["normal_count"].prop.(int)
	new_buffer = {.normal,n_data,n_size,n_count}
	buf_push(buf,new_buffer)

	t_data = properties["tangent_data"].prop.(rawptr)
	t_size = properties["tangent_size"].prop.(int)
	t_count = properties["tangent_count"].prop.(int)
	new_buffer = {.tangent,t_data,t_size,t_count}
	buf_push(buf,new_buffer)

	tc_data = properties["tex_coord"].prop.(rawptr)
	tc_size = properties["tex_coord_size"].prop.(int)
	tc_count = properties["tex_coord_count"].prop.(int)
	new_buffer = {.texcoords,tc_data,tc_size,tc_count}
	buf_push(buf,new_buffer)
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
				if primitive_mesh.is_indexed{
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

					read_mesh_attributes(primitive_mesh,&new_geo.buffers)
				}else{
					new_geo : RenderGeometryNonIndexed
					read_mesh_attributes(primitive_mesh,&new_geo.buffers)
				}
			}
		}
	}
}

read_nodes :: proc(node : ^SceneNode){
	read_node(node)
}

