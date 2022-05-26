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

MaterialPropertyValue :: union{

	int,
	f32,
	m.float3,
	m.float4,
	Texture,
}

MaterialProperty :: struct{
	name : string,
	value : MaterialPropertyValue,
}

Material :: struct{
	id : u64,
	name : string,
	pipeline_state : rawptr,
	base_color : MaterialProperty,//m.float4,
	properties : con.Buffer(MaterialProperty),
}



