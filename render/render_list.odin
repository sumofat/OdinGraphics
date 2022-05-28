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

read_node :: proc(parent_node : ^SceneNode){
	fmt.println("NODE : ",parent_node.name)
	for node in &parent_node.children.buffer{
		read_node(&node)
	}

	for comp in parent_node.component.buffer{
		if mesh,ok := comp.(MeshComponent);ok{
			fmt.println("Mesh Found : ",mesh.mesh.name)
		}
	}
}

read_nodes :: proc(node : ^SceneNode){
	read_node(node)
}

