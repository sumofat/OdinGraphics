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

MatrixBuffer :: struct{
	buf : con.Buffer(m.float4x4),
	using mat_buf_vtable : ^MatrixBufferVTable,
}

MatrixBufferVTable :: struct{
	add_matrix : proc(this : ^MatrixBuffer,mat : m.float4x4)-> u64,
	get_matrix : proc(this : ^MatrixBuffer,mat_id : u64)-> m.float4x4,
	get_current_matrix_id : proc(this : ^MatrixBuffer)-> u64,
	get_pointer_at_offset : proc(this : ^MatrixBuffer,offset : u64 = 0)-> ^m.float4x4,
}

get_matrix :: proc(this : ^MatrixBuffer,mat_id : u64)-> m.float4x4{
	return con.buf_get(&this.buf,mat_id)
}

add_matrix :: proc(this : ^MatrixBuffer,mat : m.float4x4) -> u64{
	using con
	return buf_push(&this.buf,mat)
}	

get_current_matrix_id :: proc(this : ^MatrixBuffer)-> u64{
	return con.buf_len(this.buf) * size_of(m.float4x4)	
}

get_pointer_at_offset :: proc(this : ^MatrixBuffer,offset : u64 = 0)-> ^m.float4x4{
	assert(con.buf_len(this.buf) >= 1)
	return &this.buf.buffer[offset]
}



StructuredBuffer :: struct($T : typeid){
	data : (T),
	buf_ptr : rawptr, 
	srv_ptr : rawptr,
}

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

@(private)
cpu_matrix_buffer : MatrixBuffer

@(private)
gpu_matrix_buffer : MatrixBuffer

@(private)
matrix_buffer_vtable : MatrixBufferVTable

init_matrix_buffer :: proc(start_matrix_size : u64)-> MatrixBuffer{
	result : MatrixBuffer
	result.buf = con.buf_init(start_matrix_size,m.float4x4)
	
	matrix_buffer_vtable.add_matrix = add_matrix
	matrix_buffer_vtable.get_matrix = get_matrix
	matrix_buffer_vtable.get_current_matrix_id = get_current_matrix_id
	matrix_buffer_vtable.get_pointer_at_offset = get_pointer_at_offset
	result.mat_buf_vtable = &matrix_buffer_vtable
	return result
}

init_constant_buffer_dx11 ::  proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> ConstantBuffer(T){
	using D3D11
	result : ConstantBuffer(T)

	// Define the constant data used to communicate with shaders.
	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = byte_size
	cb_desc.Usage = USAGE.DYNAMIC
	cb_desc.BindFlags = .CONSTANT_BUFFER
	cb_desc.CPUAccessFlags = .CPU_ACCESS_WRITE
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

init_buffer_structured_dx11 ::  proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> StructuredBuffer(T){
	using D3D11
	result : StructuredBuffer(T)

	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = byte_size
	cb_desc.Usage = USAGE.DYNAMIC
	cb_desc.BindFlags = BIND_FLAG.SHADER_RESOURCE
	cb_desc.CPUAccessFlags = CPU_ACCESS_FLAG.WRITE
	cb_desc.MiscFlags = RESOURCE_MISC_FLAG.BUFFER_STRUCTURED
	cb_desc.StructureByteStride = size_of(T)

	init_data : SUBRESOURCE_DATA
	init_data.pSysMem = const_data
	init_data.SysMemPitch = 0
	init_data.SysMemSlicePitch = 0
	buffer_ptr : ^IBuffer	
	hresult := (^IDevice)(device.ptr)->CreateBuffer(&cb_desc,&init_data,&buffer_ptr)
	result.buf_ptr = buffer_ptr
	assert(hresult == 0)
	srv_ptr : ^IShaderResourceView
	srv_desc : SHADER_RESOURCE_VIEW_DESC
	srv_desc.Format = DXGI.FORMAT.UNKNOWN
	srv_desc.ViewDimension = SRV_DIMENSION.BUFFER
	srv_desc.Buffer.FirstElement = 0
	srv_desc.Buffer.NumElements = 8

	hresult = (^IDevice)(device.ptr)->CreateShaderResourceView(buffer_ptr, &srv_desc, &srv_ptr);
	result.srv_ptr = srv_ptr
	assert(hresult == 0)

	return result
}

init_buffer_structured :: proc(device : Device,$T : typeid,const_data : ^T,byte_size : u32)-> StructuredBuffer(T){
	result : StructuredBuffer(T)
	when RENDERER == RENDER_TYPE.DX11{
		result = init_buffer_structured_dx11(device,T,const_data,byte_size)
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

init_vertex_buffer :: proc(device : Device,const_data : $T,byte_size : u32)-> VertexBuffer{
	result : VertexBuffer
	when RENDERER == RENDER_TYPE.DX11{
		result = init_vertex_buffer_structured_dx11(device,const_data,byte_size)
	}
	return result
}

init_vertex_buffer_structured_dx11 ::  proc(device : Device,const_data : $T,byte_size : u32)-> VertexBuffer{
	using D3D11
	result : VertexBuffer

	// Define the constant data used to communicate with shaders.
	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = u32(byte_size)
	cb_desc.Usage = USAGE.DEFAULT
	cb_desc.BindFlags = BIND_FLAG.VERTEX_BUFFER//BIND_FLAG.CONSTANT_BUFFER
	//cb_desc.CPUAccessFlags = CPU_ACCESS_FLAG.WRITE
	//cb_desc.MiscFlags = RESOURCE_MISC_FLAG.BUFFER_STRUCTURED
	//cb_desc.StructureByteStride = size_of(T)

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

upload_buffer_data :: proc(data : rawptr,size : u32){
	when RENDERER == RENDER_TYPE.DX11{
//		upload_buffer_data_dx11(g_arena,data,size)
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

init_index_buffer :: proc(device : Device,const_data : $T,byte_size : u32)-> IndexBuffer{
	result : IndexBuffer
	when RENDERER == RENDER_TYPE.DX11{
		result = init_index_buffer_structured_dx11(device,const_data,byte_size)
	}
	return result
}

init_index_buffer_structured_dx11 ::  proc(device : Device,const_data : $T,byte_size : u32)-> IndexBuffer{
	using D3D11
	result : IndexBuffer

	// Define the constant data used to communicate with shaders.
	cb_desc :  BUFFER_DESC
	cb_desc.ByteWidth = u32(byte_size)
	cb_desc.Usage = USAGE.DEFAULT
	cb_desc.BindFlags = BIND_FLAG.INDEX_BUFFER//BIND_FLAG.CONSTANT_BUFFER

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
