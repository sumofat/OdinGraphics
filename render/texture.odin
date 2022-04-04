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
Texture :: struct{
	dim : m.float2,
	size : u32,
	ptr : rawptr,
}

TextureLocation :: struct{
	heap_id : u64,
    texture_id : u64,//if there is a heap id id is the offset into the heap
}

@(private="file")
asset_cache : con.AnyCache(u64,Texture)


// NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
//Will probaby need a different path for HDR textures etc..
image_from_mem :: proc(ptr : ^u8,size : i32,texture : ^Texture ){
    dimx : i32
    dimy : i32
	chan_count : clib.int
    texture.ptr = stbi.load_from_memory(ptr,size,&dimx,&dimy,&chan_count,0)
    texture.dim = m.float2{cast(f32)dimx,cast(f32)dimy}
	assert(chan_count > 0)
	bytes_per_pixel := 1//8bits
    texture.size = u32(dimx * dimy * chan_count) 
}

texture_from_mem :: proc(ptr : ^u8,size : i32,desired_channels : i32) -> Texture{
    tex : Texture
    image_from_mem(ptr,size,&tex)
    assert(tex.ptr != nil)
    return tex
}

texture_add :: proc(texture : ^Texture){
    using con
	
	when RENDERER == RENDER_TYPE.DX11{
		
	}
}

get_texture_from_mem :: proc(uri : string,ptr : ^u8,size : i32,desired_channels : i32) -> (texture : ^Texture,success : bool){
    result : ^Texture
    using con
    lookup_key := u64(hash.murmur64(transmute([]u8)uri))
    if anycache_exist(&asset_cache,lookup_key){
        t := anycache_get_ptr(&asset_cache,lookup_key)
        if t != nil{
            return t,true
        }else{
            return nil,false
        }
    }else{
        /*
		heap_ := heap
        if heap_ == nil{
            heap_ = &default_srv_desc_heap
        }
		*/

        tex :=  texture_from_mem(ptr,size,desired_channels)   
        heap_id := texture_add(&tex,heap_)
        tex.heap_id = heap_id
        anycache_add(&asset_tables.texture_cache,lookup_key,tex)
        
        t := anycache_get_ptr(&asset_tables.texture_cache,lookup_key)
        if t != nil{
            t.id = lookup_key
            return t,true
        }else{
            return nil,false
        }
    }
}

get_texture_from_file :: proc(path : string,heap : ^GPUHeap = nil) -> (texture : ^Texture,success : bool){
    result : ^Texture
    using con
    using asset_ctx
    lookup_key := u64(hash.murmur64(transmute([]u8)path))
    if anycache_exist(&asset_tables.texture_cache,lookup_key){
        t := anycache_get_ptr(&asset_tables.texture_cache,lookup_key)
        if t != nil{
            t.id = lookup_key
            return t,true
        }else{
            return nil,false
        }
    }else{
            //TODO(Ray):This gets it from disk but we should be able to get it from anywhere .. network stream etc...
            //We will add a facility for tagging assets and retrieving base on criteria and only the asset retriever
            //(Serializer) like system will be the only one to deal with what we are getting it from.
        heap_ := heap
        if heap_ == nil{
            heap_ = &default_srv_desc_heap
        }

        tex :=  texture_from_file(strings.clone_to_cstring(path,context.temp_allocator),4)   
        heap_id := texture_add(&tex,heap_)
        tex.heap_id = heap_id
        anycache_add(&asset_tables.texture_cache,lookup_key,tex)
        
        t := anycache_get_ptr(&asset_tables.texture_cache,lookup_key)
        if t != nil{
            t.id = lookup_key
            return t,true
        }else{
            return nil,false
        }
    }
}

