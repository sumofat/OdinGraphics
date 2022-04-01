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

ConstantBuffer :: struct($T : typeid){
	data : (T),
	ptr : rawptr, 
}

VertexBuffer :: struct{
	ptr : rawptr,
	stride_in_bytes : u32,
	offset : u32,
}

IndexBuffer :: struct{
	format : Format,
	ptr : rawptr,
}

BufferTable :: struct{
	index_buffers : con.Buffer(IndexBuffer),
	vertex_buffers : con.Buffer(VertexBuffer),
}

@(private)
buffer_table : BufferTable

init_constant_buffer_dx11 ::  proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> ConstantBuffer(T){
	using D3D11
	result : ConstantBuffer(T)

	// Define the constant data used to communicate with shaders.
	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = byte_size
	cb_desc.Usage = USAGE.DYNAMIC
	cb_desc.BindFlags = CONSTANT_BUFFER
	cb_desc.CPUAccessFlags = CPU_ACCESS_WRITE
	cb_desc.MiscFlags = 0
	cb_desc.StructureByteStride = 0

	init_data : SUBRESOURCE_DATA
	init_data.pSysMem = const_data
	init_data.SysMemPitch = 0
	init_data.SysMemSlicePitch = 0
	constant_buffer : ^IBuffer
	hresult := (^IDevice)(device.ptr)->CreateBuffer(&cb_desc,&init_data,&constant_buffer)
	assert(hresult == 0)
	assert(constant_buffer != nil)
	result.ptr = constant_buffer
	return result
}

init_constant_buffer :: proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> ConstantBuffer(T){
	result : ConstantBuffer
	when RENDERER == RENDER_TYPE.DX11{
		result = init_constant_buffer_dx11(device,T,const_data,byte_size)
	}
	return result
}

init_constant_buffer_structured_dx11 ::  proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> ConstantBuffer(T){
	using D3D11
	result : ConstantBuffer(T)

	// Define the constant data used to communicate with shaders.
	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = byte_size
	cb_desc.Usage = USAGE.DYNAMIC
	cb_desc.BindFlags = BIND_FLAG.SHADER_RESOURCE//BIND_FLAG.CONSTANT_BUFFER
	cb_desc.CPUAccessFlags = CPU_ACCESS_FLAG.WRITE
	cb_desc.MiscFlags = RESOURCE_MISC_FLAG.BUFFER_STRUCTURED
	cb_desc.StructureByteStride = size_of(T)

	init_data : SUBRESOURCE_DATA
	init_data.pSysMem = const_data
	init_data.SysMemPitch = 0
	init_data.SysMemSlicePitch = 0
	buffer_ptr : ^IBuffer	
	hresult := (^IDevice)(device.ptr)->CreateBuffer(&cb_desc,&init_data,&buffer_ptr)
	result.ptr = buffer_ptr
	assert(hresult == 0)
	return result
}

init_constant_buffer_structured :: proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> ConstantBuffer(T){
	result : ConstantBuffer(T)
	when RENDERER == RENDER_TYPE.DX11{
		result = init_constant_buffer_structured_dx11(device,T,const_data,byte_size)
	}
	return result
}

set_constant_buffers_dx11 :: proc(device : Device,start_slot : u32,num_buffers : u32,buffers : []^D3D11.IBuffer){
	using D3D11
	(^IDeviceContext)(device.con.ptr)->VSSetConstantBuffers(start_slot,num_buffers,&buffers[0])
}

set_constant_buffers :: proc(device : Device,start_slot : u32,$T : typeid,constant_buffers : []ConstantBuffer(T)){
	when RENDERER == RENDER_TYPE.DX11{
		using D3D11
		ibuffers : con.Buffer(^IBuffer) = con.buf_init(u64(len(constant_buffers)),^IBuffer)
		defer{con.buf_clear(&ibuffers)}
		for i : int = 0;i < len(constant_buffers);i += 1{
				con.buf_push(&ibuffers,(^IBuffer)(constant_buffers[i].ptr))
		}
		set_constant_buffers_dx11(device,start_slot,u32(len(constant_buffers)),ibuffers.buffer[:])
	}
}
set_vertex_buffers_dx11 :: proc(dev : Device,start_slot : u32,num_buffers : u32,vertex_buffers : []^D3D11.IBuffer,strides : []u32,offsets : []u32){
	using D3D11
	(^IDeviceContext)(dev.con.ptr)->IASetVertexBuffers(start_slot,num_buffers,&vertex_buffers[0],&strides[0],&offsets[0])
}

set_vertex_buffers :: proc(dev : Device,start_slot : u32,num_buffers : u32,vertex_buffers : []VertexBuffer,strides : []u32,offsets : []u32){
	using D3D11
	when RENDERER == RENDER_TYPE.DX11{
		ibuffers : con.Buffer(^IBuffer) = con.buf_init(u64(len(vertex_buffers)),^IBuffer)
		defer{con.buf_clear(&ibuffers)}
		for i : int = 0;i < len(vertex_buffers);i += 1{
				con.buf_push(&ibuffers,(^IBuffer)(vertex_buffers[i].ptr))
		}
		set_vertex_buffers_dx11(dev,start_slot,num_buffers,ibuffers.buffer[:],strides,offsets)
	}
}

set_index_buffers_dx11 :: proc(dev : Device,buffer : ^D3D11.IBuffer,format : Format,offset : u32){
	using D3D11
	(^IDeviceContext)(dev.con.ptr)->IASetIndexBuffer(buffer,convert_format_dxgi(format),offset)
}

set_index_buffer :: proc(dev : Device,buffer : IndexBuffer,format : Format,offset : u32){
	using D3D11
	assert(buffer.ptr != nil)

	when RENDERER == RENDER_TYPE.DX11{
		set_index_buffers_dx11(dev,(^IBuffer)(buffer.ptr),format,offset)
	}
}
