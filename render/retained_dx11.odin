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
/*
Create a retained mode renderer 
1. Take in state calls
2. Take in remove state calls
3. Every frame check if state has changed and than remove replace add any state that needs it.
4. Execute the commands on that state.

I like how we structured it in Odin lets replicate that and clean it up here.
*/

//Commands for Renderer
RenderCommand :: struct{
	geometry : RenderGeometry,
	material_id : int,
	model_matrix_id : int,
	camera_matrix_id:      int,
	perspective_matrix_id: int,
	texture_range : m.int2, 
	is_indexed:bool,
	material_name:string,
}

RenderGeometry :: struct {
	buffer_id_range: m.int2,
	count:           int,
	offset:          int,
	index_id:        int,
	index_count:     int,
	is_indexed:      bool,
	base_color:      m.float4,
}

BaseRenderCommandList :: struct{
	list : con.Buffer(RenderCommand),
}

render_commands : con.Buffer(RenderCommand)
render_texture : con.Buffer(int)

RenderTarget :: struct{
	ptr : rawptr,
}

RenderShader :: struct{

}
PrimitiveTopology :: enum{
    topology_undefined	= 0,
    topology_pointlist	= 1,
    topology_linelist	= 2,
    topology_linestrip	= 3,
    topology_trianglelist	= 4,
    topology_trianglestrip	= 5,
} 

VertexBufferView :: struct{
    buffer_location : u64,
    size_in_bytes : int,
    stride_in_bytes : int,
}

CommandBasicDraw :: struct{
	vertex_offset : int,
	count:         int,
	topology:      PrimitiveTopology,
	heap_count:    int,
	buffer_view:   VertexBufferView, // TODO(Ray Garner): add a way to bind multiples
}

DefferedRenderer :: struct{
	gbuff_data : GBufferData,
}

GBufferPass :: struct{
	init_gbuffer_pass : proc(),
	setup_gbuffer_pass : proc(),
	render_gbuffer_pass : proc(),
}

Pass :: struct{
	init : proc(data : rawptr),
	setup : proc(data : rawptr),
	execute : proc(data : rawptr),
}

Renderer :: struct{
	passes : con.Buffer(Pass),
}

//renderers : con.Buffer(Renderer)
create_renderer ::  proc($T : typeid)-> Renderer{
	using con
	result : Renderer
	//result.passes = buf_init(Pass(GBufferData),1)
	result.passes = buf_init(1,Pass)
	
	return result
}

create_pass ::  proc(this : ^Renderer,DT : typeid,init : proc(data : rawptr,),setup : proc(data : rawptr),execute : proc(data : rawptr)){
	using con
	result : Pass
	result.init = init
	result.setup = setup
	result.execute = execute
	buf_push(&this.passes,result)
}

init_renderers ::  proc(){
	using con
	deffered_renderer := create_renderer(DefferedRenderer)
	create_pass(&deffered_renderer,GBufferData,gbuffer_init,gbuffer_setup,gbuffer_exec)

	for pass in deffered_renderer.passes.buffer{
		pass.init(&deffered_renderer)
	}
}

execute_renderer ::  proc(renderer : Renderer){
	renderer_ref := renderer
	for pass in renderer.passes.buffer{
		pass.setup(&renderer_ref)
		pass.execute(&renderer_ref)
	}
}
//Pass Definitions 
GBufferData :: struct{
	matrix_buffer:      ^con.Buffer(m.float4x4),
	matrix_quad_buffer: ^con.Buffer(m.float4x4),
	root_sig:           rawptr,
	render_targets:     con.Buffer(RenderTarget),
	shader:             RenderShader,
}

gbuffer_init_dx11 ::  proc(data : rawptr){
	//Create Render Textures
	/*
	diffuse , normal , position buffers
	*/
}

gbuffer_setup_dx11 :: proc(data : rawptr){

	/*add clear commands for all buffers
	and for depth stencil buffer
	*/
}

gbuffer_execute_dx11 ::  proc(data : rawptr){
	/*execute commands*/
}

RENDERER : int  : 0 
gbuffer_init ::  proc(data : rawptr){
	fmt.println("GBUFFINIT")
	data_ref := data
	defered_renderer := (^DefferedRenderer)(data_ref)
	when RENDERER == 0{
		gbuffer_init_dx11(data)
	}
}

gbuffer_setup ::  proc(data : rawptr){
	fmt.println("GBUFF SETUP")
	when RENDERER == 0{
		gbuffer_setup(data)
	}
}

gbuffer_exec ::  proc(data : rawptr){
	fmt.println("GBUFF EXEC")
	when RENDERER == 0{
		gbuffer_execute_dx11(data)
	}
}
