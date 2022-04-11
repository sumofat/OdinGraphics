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
import clib "core:c"

//a cpu loaded texture that we throw after load it give the memory back
CPULoadedTextureResult :: struct{
	dim : m.float2,
	size : u32,
	texels : rawptr,
}

//Represents a shader resource view texture for the gpu renderer
Texture :: struct{
	dim : m.float2,
	size : u32,
	location : TextureLocation,
}

TextureLocation :: struct{
	heap_id : u64,
    texture_id : rawptr,//if there is a heap id id is the offset into the heap
}

@(private="file")
texture_cache : con.AnyCache(u64,Texture)

// NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
//Will probaby need a different path for HDR textures etc..
image_from_mem :: proc(ptr : ^u8,size : i32) -> (m.float2,rawptr){
    dimx : i32
    dimy : i32
	chan_count : clib.int
    result_ptr := stbi.load_from_memory(ptr,size,&dimx,&dimy,&chan_count,0)
    result_dim := m.float2{cast(f32)dimx,cast(f32)dimy}
	assert(result_ptr != nil)
	assert(chan_count == 4)
	return result_dim,result_ptr
}

image_from_file :: proc(filename : cstring,size : i32) -> (m.float2,rawptr){
    dimx : i32
    dimy : i32
	chan_count : clib.int
    result_ptr := stbi.load(filename,&dimx,&dimy,&chan_count,0)
    result_dim := m.float2{cast(f32)dimx,cast(f32)dimy}
	assert(result_ptr != nil)
	assert(chan_count == 4)
	return result_dim,result_ptr
}

texture_from_file :: proc(file : cstring,size : i32,desired_channels : i32) -> CPULoadedTextureResult{
    tex : CPULoadedTextureResult
	tex.size = u32(tex.dim.x * tex.dim.y * 4)
    tex.dim,tex.texels = image_from_file(file,size)
    assert(tex.texels != nil)
    return tex
}
texture_from_mem :: proc(ptr : ^u8,size : i32,desired_channels : i32) -> CPULoadedTextureResult{
    tex : CPULoadedTextureResult
	tex.size = u32(tex.dim.x * tex.dim.y * 4)
    tex.dim,tex.texels = image_from_mem(ptr,size)
    assert(tex.texels != nil)
    return tex
}

get_texture_gpu :: proc(texture : CPULoadedTextureResult) -> Texture{
    using con
	using D3D11	
	when RENDERER == RENDER_TYPE.DX11{
		result : Texture
		result.dim = texture.dim
		result.size = u32(texture.dim.x * texture.dim.y * 4)		
		desc : TEXTURE2D_DESC
		desc.Width = u32(texture.dim.x)
		desc.Height = u32(texture.dim.y)
		desc.Usage = USAGE.IMMUTABLE
		desc.Format = DXGI.FORMAT.R8G8B8A8_UNORM
		desc.MipLevels = 0
		desc.ArraySize = 1
		desc.BindFlags = BIND_FLAG.SHADER_RESOURCE
		desc.SampleDesc.Count = 1
		desc.SampleDesc.Quality = 0
		tex : ^ITexture2D
		hresult := (^IDevice)(render_device.ptr)->CreateTexture2D(&desc,nil,&tex)
		assert(hresult == 0)

		sr_desc : SHADER_RESOURCE_VIEW_DESC
		sr_desc.Texture2D.MipLevels = 0
		sr_desc.Texture2D.MostDetailedMip = 0
		sr_desc.Format = DXGI.FORMAT.R8G8B8A8_UNORM

		srv : ^IShaderResourceView
		hresult = (^IDevice)(render_device.ptr)->CreateShaderResourceView(tex,&sr_desc,&srv)
		assert(hresult == 0)
		result.location.texture_id = srv
		return result
	}
}

get_texture_from_mem :: proc(uri : string,ptr : ^u8,size : i32,desired_channels : i32) -> (texture : Texture,success : bool){
    result : ^Texture
    using con
    lookup_key := u64(hash.murmur64(transmute([]u8)uri))
    if anycache_exist(&texture_cache,lookup_key){
        t := anycache_get(&texture_cache,lookup_key)
            return t,true
    }else{
        tex_loaded_result :=  texture_from_mem(ptr,size,desired_channels)   
		if tex_loaded_result.texels == nil{
			return Texture{},false
		}

        tex := get_texture_gpu(tex_loaded_result)
        //tex.heap_id = heap_id
        anycache_add(&texture_cache,lookup_key,tex)
        
        t := anycache_get(&texture_cache,lookup_key)
		return t,true
    }
}

get_texture_from_file :: proc(device : Device,uri : string,size : i32,desired_channels : i32) -> (texture : Texture,success : bool){
    result : ^Texture
    using con
    lookup_key := u64(hash.murmur64(transmute([]u8)uri))
    if anycache_exist(&texture_cache,lookup_key){
        t := anycache_get(&texture_cache,lookup_key)
            return t,true
    }else{
        tex_loaded_result :=  texture_from_file(strings.clone_to_cstring(uri),size,desired_channels)   
		if tex_loaded_result.texels == nil{
			return Texture{},false
		}

        tex := get_texture_gpu(tex_loaded_result)
        anycache_add(&texture_cache,lookup_key,tex)
        
        t := anycache_get(&texture_cache,lookup_key)
		return t,true
    }
}

