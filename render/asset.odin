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
@(private)
asset_table : AssetTable

@(private="file")
asset_context : AssetContext
VertCompressionType :: enum
{
    none,
}

IndexComponentSize :: enum
{
    none = 0,
    size_32 = 1,
    size_16 = 2,
}
Mesh :: struct
{
    id : u32,
    name : string,
    compression_type : VertCompressionType,
    
    vertex_data : ^f32,
    vertex_data_size : u64,
    vertex_count : u64,
    tangent_data : ^f32,
    tangent_data_size : u64,
    tangent_count : u64,
    bi_tangent_data : ^f32,
    bi_tangent_data_size : u64,
    bi_tangent_count : u64,
    normal_data : ^f32,
    normal_data_size : u64,
    normal_count : u64,
    uv_data : ^f32,
    uv_data_size : u64,
    uv_count : u64,
    //NOTE(Ray):We are only support max two uv sets
    uv2_data : ^f32,
    uv2_data_size : u64,
    uv2_count : u64,
    
    index_component_size : IndexComponentSize,
    //TODO(Ray):These are seriously problematic and ugly will be re working these.
    index_32_data : ^u32,
    index_32_data_size : u64,
    index32_count : u64,
    index_16_data : ^u16,
    index_16_data_size : u64,
    index16_count : u64,
    mesh_resource : GPUMeshResource,    
    material_id : u32,
    material_name : string,    
	//TODO(Ray):TExture ID"s should be stored in materials and use maps to keep references to the names
//	heap_id : u64,//For api's that support it we will store textures in one large heap
//    metallic_roughness_texture_id : u64,

    base_color : m.float4,
}

GPUArena :: struct
{
    size : u64,
    heap : rawptr,//    ID3D12Heap* 
    resource : rawptr, //    ID3D12Resource* 
    slot : u32,
//    buffer_view : BufferView,    
}

GPUMeshResource :: struct {
	vertex_buff:  GPUArena,
	normal_buff:  GPUArena,
	uv_buff:      GPUArena,
	tangent_buff: GPUArena,
	element_buff: GPUArena,
	hash_key:     u64,
	buffer_range: m.float2,
	index_id:     u32,
}

AssetTable :: struct{
	materials : con.Buffer(Material),
	textures : con.Buffer(Texture),
	meshes : con.Buffer(Mesh),
	scene_objects : con.Buffer(SceneObject),
}

AssetContext :: struct{
	scene_objects : con.Buffer(SceneObject),
}
ModelLoadResult :: struct{
    is_success : bool,
    scene_object_id : u64,//instance id of the model created as a scene object  node 
}

init_asset_table :: proc(){
	using con
	asset_table.materials = buf_init(1,Material)
}

get_material_by_id :: proc(id : u64)-> Material{
	using con
	material := buf_get(&asset_table.materials,id)
	//COuld do a check based on seslected render api for valid material
	return material
}

asset_load_model :: proc(device : Device,ctx : ^AssetContext,file_path : cstring,material : Material,type : SceneObjectType = .Mesh) -> ModelLoadResult{
    using con
    using m
    result : ModelLoadResult
    is_success := false

    options : cgltf.options
    cgltf_data : ^cgltf.data
    aresult := cgltf.parse_file(&options,file_path, &cgltf_data)    
    assert(aresult == cgltf.result.success)
    if cast(cgltf.result)aresult == cgltf.result.success
    {
        for i : int = 0;i < int(cgltf_data.buffers_count);i += 1{
	        //uri := mem.ptr_offset(cgltf_data.buffers,i).uri
            uri := cgltf_data.buffers[i].uri
            rs := cgltf.load_buffers(&options, cgltf_data, uri)
            assert(rs == cgltf.result.success)
        }
        //TODO(ray):If we didnt  get a mesh release any memory allocated.
        if cgltf_data.nodes_count > 0
        {
            parent_trans := transform_init()
            //p_matrix_id := buf_push(&matrix_buffer,parent_trans.mat)
			p_matrix_id := cpu_matrix_buffer->add_matrix(parent_trans.mat)
            model_root_so_ : SceneObject = scene_object_init("model_root_so")
            model_root_so_.type = type
            model_root_so_id := buf_push(&ctx.scene_objects,model_root_so_)
            assert(cgltf_data.scenes_count == 1)
	        //scenes_count := mem.ptr_offset(cgltf_data.scenes,0).nodes_count	    
            scenes_count := cgltf_data.scenes[0].nodes_count
		    //root_scene := mem.ptr_offset(cgltf_data.scenes,0)
            root_scene := cgltf_data.scenes[0]
            for i : int = 0;i < cast(int)scenes_count;i+=1{
                //root_node : ^cgltf.node = mem.ptr_offset(root_scene.nodes,i)^
                root_node : ^cgltf.node = root_scene.nodes[i]
                
                trans := transform_init()
                out_mat := m.float4x4(la.MATRIX4F32_IDENTITY)
                if root_node.has_matrix == true
                {
                    out_mat = m.float4x4{root_node.m[0],root_node.m[1],root_node.m[2],root_node.m[3],
                                   root_node.m[4],root_node.m[5],root_node.m[6],root_node.m[7],
                                   root_node.m[8],root_node.m[9],root_node.m[10],root_node.m[11],
                                   root_node.m[12],root_node.m[13],root_node.m[14],root_node.m[15]};                                        
                }
                else
                {
                    cgltf.node_transform_world(root_node, cast(^cgltf.cgltf_float)&out_mat)
                }

                trans.p = m.float3{out_mat[3].x,out_mat[3].y,out_mat[3].z}
                trans.s = m.float3{m.length(m.float3{out_mat[0].x,out_mat[0].y,out_mat[0].z}),
                             la.length(m.float3{out_mat[1].x,out_mat[1].y,out_mat[1].z}),
                             la.length(m.float3{out_mat[2].x,out_mat[2].y,out_mat[2].z})}
                trans.r = la.quaternion_from_matrix4(la.Matrix4x4f32(out_mat))
                trans.mat = out_mat

                import_type : SceneObjectType = SceneObjectType.Empty
                mesh_range := m.float2{}
                if root_node.mesh != nil
                {
                    mesh_range = create_mesh_from_cgltf_mesh(root_node.mesh,material,string(file_path))
                    import_type = SceneObjectType.Mesh
                    upload_meshes(device,mesh_range)
                }

                mptr : rawptr = nil
                mesh_name := string(root_node.name)                
                child_id := add_child_to_scene_object_with_transform(ctx,model_root_so_id,&trans,&mptr,mesh_name)
                child_so := buf_chk_out(&ctx.scene_objects,child_id)
                child_so.import_type = import_type
                child_so.type = type
                child_so.primitives_range = mesh_range
                buf_chk_in(&ctx.scene_objects)
                
		        load_meshes_recursively_gltf_node(device,&result,root_node^,ctx,file_path,material,child_id,type)
            }

            buf_chk_in(&ctx.scene_objects)
            result.scene_object_id = model_root_so_id	    
	    }

        cgltf.free(cgltf_data)	
    }

    return result        
}

create_mesh_from_cgltf_mesh  :: proc(ma : ^cgltf.mesh,material : Material,path : string) -> m.float2{
    using con
    assert(ma != nil)
    mesh_id := buf_len(asset_table.meshes)
    
    result := m.float2{cast(f32)mesh_id,cast(f32)mesh_id}

    for j := 0;cast(uint)j < ma.primitives_count; j += 1{
        mesh := Mesh{}
        //prim := mem.ptr_offset(ma.primitives,j)
        prim := ma.primitives[j]
        mat  := prim.material
        if mat != nil
        {
            if mat.normal_texture.texture != nil
            {
                //            tv := mat.normal_texture
            }

            if mat.occlusion_texture.texture != nil
            {
                //            tv := mat.occlusion_texture
            }
	        
            if mat.emissive_texture.texture != nil
            {
                //            tv := mat.emissive_texture
            }

            if mat.has_pbr_metallic_roughness == true
            {
                if mat.pbr_metallic_roughness.base_color_texture.texture != nil
                {
                    tv := mat.pbr_metallic_roughness.base_color_texture
                    {
                        using fmt
                        offset := cast(u64)tv.texture.image.buffer_view.offset
                        tex_data := mem.ptr_offset(cast(^u8)tv.texture.image.buffer_view.buffer.data,cast(int)offset)
                        println(offset)
		                //TODO(Ray):This if statement is not good
                        if tex_data != nil
                        {
                            data_size := cast(u64)tv.texture.image.buffer_view.size
                            to_image_path : string
                            if tv.texture.image.uri != ""{
                                to_image_path = string(tv.texture.image.uri)
                            }else{
                                to_image_path = fmt.tprintf("%d",offset + 1)
                            }
                            //fmt.printf("Image URI: %s",image_uri)
                            //we will use the path to the mesh + the name of the texture to get lookup key using path.
                            //this is ok but stil requires the namem to bbe unique inside the gltf file
                            slice_path_name := []string{path,"::",to_image_path,}
                            path_and_texture_name := strings.concatenate(slice_path_name,context.temp_allocator)
                            fmt.println(path_and_texture_name)

                            if t,ok := get_texture_from_mem(path_and_texture_name,tex_data,cast(i32)data_size,4);ok{
                                mesh.metallic_roughness_texture_id = t.heap_id
                            }else{
                                assert(false)
                            }
                        }                    
                    }
                }

                if mat.pbr_metallic_roughness.metallic_roughness_texture.texture != nil
                {
                    //                tv := mat.pbr_metallic_roughness.metallic_roughness_texture
                }

                bcf := mat.pbr_metallic_roughness.base_color_factor
                mesh.base_color = m.float4{bcf[0],bcf[1],bcf[2],bcf[3]}

                //            cgltf_float* mf = &mat.pbr_metallic_roughness.metallic_factor
                //            cgltf_float* rf = &mat.pbr_metallic_roughness.roughness_factor
            }

            if mat.has_pbr_specular_glossiness == true
            {
                if mat.pbr_specular_glossiness.diffuse_texture.texture != nil
                {
                    //                tv := mat.pbr_specular_glossiness.diffuse_texture
                }

                if mat.pbr_specular_glossiness.specular_glossiness_texture.texture != nil
                {
                    //                tv := mat.pbr_specular_glossiness.specular_glossiness_texture
                }

                dcf := mat.pbr_specular_glossiness.diffuse_factor
                diffuse_value := m.float4{dcf[0],dcf[1],dcf[2],dcf[3]}
                sf := mat.pbr_specular_glossiness.specular_factor
                specular_value := m.float3{sf[0],sf[1],sf[2]}
                gf := &mat.pbr_specular_glossiness.glossiness_factor
            }

            //alphaCutoff
            //alphaMode
            //emissiveFactor
            //emissiveTexture
            //occlusionTexture
            //normalTexture

        }
        
        mesh.name = string(ma.name)
        mesh.material_id = 0

        if prim.type == cgltf.primitive_type.triangles
        {
            has_got_first_uv_set := false

            if prim.indices != nil
            {
                istart_offset := prim.indices.offset + prim.indices.buffer_view.offset
                ibuf := prim.indices.buffer_view.buffer                
                if prim.indices.component_type == cgltf.component_type.r_16u
                {
                    indices_size :=  cast(u64)prim.indices.count * size_of(u16)
                    indices_buffer := cast(^u16)mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset)
                    outindex_f := cast(^u16)mem.alloc(cast(int)indices_size)
                    
                    mem.copy(outindex_f,indices_buffer,cast(int)indices_size)
                    mesh.index_16_data = outindex_f
                    mesh.index_16_data_size = size_of(u16) * cast(u64)prim.indices.count
                    mesh.index16_count = cast(u64)prim.indices.count                    
                }
                else if prim.indices.component_type == cgltf.component_type.r_32u
                {
                    indices_size :=  cast(u64)prim.indices.count * size_of(u32)
                    indices_buffer := cast(^u32)(mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset))
		            outindex_f := cast(^u32)mem.alloc(cast(int)indices_size)

                    mem.copy(outindex_f,indices_buffer,cast(int)indices_size)
                    mesh.index_32_data = outindex_f
                    mesh.index_32_data_size = size_of(u32) * cast(u64)prim.indices.count
                    mesh.index32_count = cast(u64)prim.indices.count                    
                }
            }
            
            for k := 0;k < cast(int)prim.attributes_count; k += 1{
                //ac := mem.ptr_offset(prim.attributes,k)
                ac := prim.attributes[k]
                acdata := ac.data
                count := acdata.count
		        bf := acdata.buffer_view
                {
                    start_offset := bf.offset
                    stride := bf.stride
                    buf := bf.buffer
                    buffer := (^f32)(mem.ptr_offset(cast(^u8)buf.data,cast(int)start_offset))

                    if acdata.is_sparse == true
                    {
                        assert(false)
                    }

                    num_floats := acdata.count * cgltf.num_components(acdata.type)
                    num_bytes := size_of(f32) * num_floats                
                    outf := cast(^cgltf.cgltf_float)mem.alloc(cast(int)num_bytes)
                    csize := cgltf.accessor_unpack_floats(acdata,outf,num_floats)

                    //NOTE(Ray):only support two set of uv data for now.                        
                    if ac.type == cgltf.attribute_type.position
                    {
                        mesh.vertex_data = outf
                        mesh.vertex_data_size = cast(u64)num_bytes
                        mesh.vertex_count = cast(u64)count
                    }
                    else if ac.type == cgltf.attribute_type.normal
                    {
                        mesh.normal_data = outf
                        mesh.normal_data_size = cast(u64)num_bytes
                        mesh.normal_count = cast(u64)count
                    }
                    else if ac.type == cgltf.attribute_type.tangent
                    {
                        mesh.tangent_data = outf
                        mesh.tangent_data_size = cast(u64)num_bytes
                        mesh.tangent_count = cast(u64)count
                    }
                    else if ac.type == cgltf.attribute_type.texcoord && !has_got_first_uv_set
                    {

                        mesh.uv_data = outf
                        mesh.uv_data_size = cast(u64)num_bytes
                        mesh.uv_count = cast(u64)count
                        has_got_first_uv_set = true
                    }
                    else if ac.type == cgltf.attribute_type.texcoord && has_got_first_uv_set
                    {
                        mesh.uv2_data = outf
                        mesh.uv2_data_size = cast(u64)num_bytes
                        mesh.uv2_count = cast(u64)count
                        has_got_first_uv_set = true                        
                    }                    
                }
            }
        }
	    
        mesh.material_id = cast(u32)material.id
	    mesh.material_name = material.name

        last_id  := buf_push(&asset_table.meshes,mesh)

	    //TODO(Ray):Does this cast properly? verify
        result.y = cast(f32)last_id
    }
    return result    
}


set_buffer :: proc(device : Device,stride : u32,size : u32,data : ^f32) -> u64{
    v_size := size
    //buff^ = AllocateStaticGPUArena(device.device,v_size)
    //SetArenaToVertexBufferView(buff,v_size,stride)
	vertex_buffer := init_vertex_buffer(device,data,size)
    upload_buffer_data(data,size)    
    id := con.buf_push(&buffer_table.vertex_buffers,vertex_buffer)
    return id
}

upload_meshes :: proc(device : Device,range : m.float2){
    using con
    for i := range.x;i <= range.y;i+=1{
        is_valid := 0
        mesh_r : GPUMeshResource
        mesh := buf_chk_out(&asset_table.meshes,cast(u64)i)
        id_range := m.float2{}
        if mesh.vertex_count > 0
        {
            id_range.x = cast(f32)set_buffer(device,size_of(f32) * 3,u32(mesh.vertex_data_size),mesh.vertex_data)            
            is_valid += 1
        }
        else
        {
            assert(false)
        }

        start_range := id_range.x
        
        if mesh.normal_count > 0
        {
            set_buffer(device,size_of(f32) * 3,u32(mesh.normal_data_size),mesh.normal_data)            
            start_range  = start_range + 1.0
            is_valid  += 1
        }
        
        if mesh.uv_count > 0
        {
            set_buffer(device,size_of(f32) * 2,u32(mesh.uv_data_size),mesh.uv_data)            	    
            start_range += 1.0            
            is_valid += 1
        }
        
        id_range.y = start_range
        
        if mesh.index32_count > 0
        {
			size : u32 = u32(mesh.index_32_data_size)
            //mesh_r.element_buff = AllocateStaticGPUArena(device.device,size)

            format : DXGI.FORMAT
            mesh.index_component_size = IndexComponentSize.size_32
            format = DXGI.FORMAT.R32_UINT
            //SetArenaToIndexVertexBufferView(&mesh_r.element_buff,size,format)
			index_buffer := init_index_buffer(device,mesh.index_32_data,size)	
            upload_buffer_data(mesh.index_32_data,size)            
            index_id := buf_push(&buffer_table.index_buffers,index_buffer)
            
            mesh_r.index_id = cast(u32)index_id
            is_valid += 1
        }
        else if mesh.index16_count > 0
        {
            size : u32 = u32(mesh.index_16_data_size)
           // mesh_r.element_buff = AllocateStaticGPUArena(device.device,size)
            format : DXGI.FORMAT
            mesh.index_component_size = IndexComponentSize.size_16
            format = DXGI.FORMAT.R16_UINT
	    
            //SetArenaToIndexVertexBufferView(&mesh_r.element_buff,size,format)
			index_buffer := init_index_buffer(device,mesh.index_16_data,size)
            upload_buffer_data(mesh.index_16_data,size)            
            index_id := buf_push(&buffer_table.index_buffers,index_buffer)
            
            mesh_r.index_id = cast(u32)index_id
            is_valid += 1
        }
        
        //NOTE(RAY):For now we require that you have met all the data criteria
        if is_valid >= 1
        {
            mesh_r.buffer_range = id_range
            mesh.mesh_resource = mesh_r
        }
        else
        {
            assert(false)
        }

        buf_chk_in(&asset_table.meshes)        
    }
}


load_meshes_recursively_gltf_node :: proc(device : Device,result : ^ModelLoadResult,node : cgltf.node,ctx : ^AssetContext,file_path : cstring, material : Material,so_id : u64,type : SceneObjectType){
	using m
    for i :int = 0;i < cast(int)node.children_count;i+=1{
        //child_ptr := mem.ptr_offset(node.children,i)//cgltf.node
        child_ptr := node.children[i]
        child : ^cgltf.node = child_ptr	
        trans := transform_init()

        out_mat := float4x4(la.MATRIX4F32_IDENTITY)
        if child.has_matrix == true
        {
                    
            out_mat = float4x4{child.m[0],child.m[1],child.m[2],child.m[3],
                           child.m[4],child.m[5],child.m[6],child.m[7],
                           child.m[8],child.m[9],child.m[10],child.m[11],
                           child.m[12],child.m[13],child.m[14],child.m[15]}                                        
        }
        else
        {
            cgltf.node_transform_world(child,  cast(^cgltf.cgltf_float)&out_mat)
        }

        trans.p = float3{out_mat[3].x,out_mat[3].y,out_mat[3].z}
        trans.s = float3{la.length(float3{out_mat[0].x,out_mat[0].y,out_mat[0].z}),
                     la.length(float3{out_mat[1].x,out_mat[1].y,out_mat[1].z}),
                     la.length(float3{out_mat[2].x,out_mat[2].y,out_mat[2].z})}
        trans.r = la.quaternion_from_matrix4(la.Matrix4x4f32(out_mat))

        trans.mat = out_mat                    

        mesh_range := float2{}
        import_type : SceneObjectType = SceneObjectType.Empty 
        if child.mesh != nil
        {
//            result.model.model_name = string(file_path)
            mesh_range = create_mesh_from_cgltf_mesh(child.mesh,material,string(file_path))
            import_type = SceneObjectType.Mesh
            upload_meshes(device,mesh_range)            
        }

	    mptr : rawptr = nil
//add node to parent
        //TODO(Ray):We need this not to be associated with the context perm mem.
        //Have each sceneobject tree hold its own string meme
        mesh_name := string(child.name)
        child_id := add_child_to_scene_object_with_transform(ctx,so_id,&trans,&mptr,mesh_name)
        child_so := con.buf_chk_out(&ctx.scene_objects,child_id)
        child_so.import_type = import_type
        child_so.type = type
        child_so.primitives_range = mesh_range
        con.buf_chk_in(&ctx.scene_objects)                    	
        load_meshes_recursively_gltf_node(device,result,child^,ctx,file_path, material,child_id,type)
    }
}

/*

image_from_mem :: proc(ptr : ^u8,size : i32,texture : ^Texture ,desired_channels : i32)
{
    dimx : i32
    dimy : i32
    //NOTE(Ray):Depends on your pipeline wether or not you will need this or not.
    //IOS not supported RN
//when os.IOS{
//    stbi_set_flip_vertically_on_load(true)    
    //}
    comp : i32
    stbi.info_from_memory(ptr,size,&dimx, &dimy, &comp)

    texture.texels = stbi.load_from_memory(ptr,size,&dimx,&dimy,cast(^i32)&texture.channel_count,desired_channels)

    texture.dim = m.float2{cast(f32)dimx,cast(f32)dimy}
    texture.width_over_height = cast(f32)(dimx / dimy)

    // NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
    //a different api. for now we go with this. 
    //Will probaby need a different path for HDR textures etc..
    texture.bytes_per_pixel = cast(u32)desired_channels
    texture.align_percentage = m.float2{0.5,0.5}
    texture.channel_count = cast(u32)desired_channels
//    texture.texture = {}
    texture.size = cast(u32)(dimx * dimy * cast(i32)texture.bytes_per_pixel)
}

image_from_file :: proc(filename : cstring,texture : ^Texture ,desired_channels : i32)
{
    dimx : i32
    dimy : i32
    comp : i32
    stbi.info(filename,&dimx, &dimy, &comp)

    texture.texels = stbi.load(filename,&dimx,&dimy,cast(^i32)&texture.channel_count,desired_channels)
    //texture.texels = stbi.load_from_memory(ptr,size,&dimx,&dimy,cast(^i32)&texture.channel_count,desired_channels)

    texture.dim = m.float2{cast(f32)dimx,cast(f32)dimy}
    texture.width_over_height = cast(f32)(dimx / dimy)

    // NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
    //a different api. for now we go with this. 
    //Will probaby need a different path for HDR textures etc..
    texture.bytes_per_pixel = cast(u32)desired_channels
    texture.align_percentage = m.float2{0.5,0.5}
    texture.channel_count = cast(u32)desired_channels
    texture.size = cast(u32)(dimx * dimy * cast(i32)texture.bytes_per_pixel)
}

image_blank :: proc(texture : ^Texture,dim : m.float2,desired_channels : i32,bytes_per_pixel : i32){
    dimx : i32 = i32(dim.x)
    dimy : i32 = i32(dim.y)
    texture.bytes_per_pixel = u32(bytes_per_pixel)
    texture.size = cast(u32)(dimx * dimy * cast(i32)texture.bytes_per_pixel)

    texture.texels = mem.alloc(int(texture.size))
    texture.dim = m.float2{cast(f32)dimx,cast(f32)dimy}
    texture.width_over_height = cast(f32)(dimx / dimy)
    stride := dimx
    for row := 0;row < int(texture.dim.x); row +=1{
        for col := 0;col < int(texture.dim.y); col += 1{
            texel := mem.ptr_offset(cast(^u32)texture.texels,(i32(row) * stride) + i32(col))
            texel^ = 0xFF0000FF
        }
    }

    // NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
    //a different api. for now we go with this. 
    //Will probaby need a different path for HDR textures etc..
    texture.bytes_per_pixel = cast(u32)desired_channels
    texture.align_percentage = m.float2{0.5,0.5}
    texture.channel_count = cast(u32)desired_channels
}

texture_from_mem :: proc(ptr : ^u8,size : i32,desired_channels : i32) -> Texture
{
    tex : Texture
    image_from_mem(ptr,size,&tex,desired_channels)
    assert(tex.texels != nil)
    return tex
}

texture_from_file :: proc(filename : cstring,desired_channels : i32) -> Texture{
    tex : Texture
    image_from_file(filename,&tex,desired_channels)
    assert(tex.texels != nil)
    return tex
}
texture_add :: proc(texture : ^Texture,heap : ^GPUHeap) -> (heap_id : u64){
    using con
    assert(heap != nil)

    heap_index : u64 = u64(heap.count)
    //buf_push(&ctx.asset_tables.textures,texture^)
    texture.heap_id = heap_index
    texture.heap = heap
    hmdh_size : u32 = GetDescriptorHandleIncrementSize(device.device,platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV)

    hmdh := platform.GetCPUDescriptorHandleForHeapStart(heap.heap.value)
    offset : u64 = cast(u64)hmdh_size * cast(u64)heap.count
    hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset

    gpuhmdh := platform.GetGPUDescriptorHandleForHeapStart(heap.heap.value)
    gpugoffset : u64 = cast(u64)hmdh_size * cast(u64)heap.count
    gpuhmdh.ptr = gpuhmdh.ptr + offset

    texture.gpu_handle = gpuhmdh

    heap.count += 1
    
    srvDesc2 : platform.D3D12_SHADER_RESOURCE_VIEW_DESC
    srvDesc2.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0,1,2,3)
    srvDesc2.Format = platform.DXGI_FORMAT.DXGI_FORMAT_R8G8B8A8_UNORM
    srvDesc2.ViewDimension = platform.D3D12_SRV_DIMENSION.D3D12_SRV_DIMENSION_TEXTURE2D
    srvDesc2.Buffer.Texture2D.MipLevels = 1

    tex_resource : platform.D12Resource

    using platform                

    sd : DXGI_SAMPLE_DESC =
	{
	    1,0,
	}
    
    res_d : D3D12_RESOURCE_DESC  = {
	.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        0,
  	cast(u64)texture.dim.x,
	cast(u32)texture.dim.y,
	1,0,
	.DXGI_FORMAT_R8G8B8A8_UNORM,
	sd,
	.D3D12_TEXTURE_LAYOUT_UNKNOWN,
	.D3D12_RESOURCE_FLAG_NONE,
    }

    hp : D3D12_HEAP_PROPERTIES  =  
        {
	    .D3D12_HEAP_TYPE_DEFAULT,
            .D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .D3D12_MEMORY_POOL_UNKNOWN,
            1,
            1,
        }
    
    CreateCommittedResource(device.device,
        &hp,
        .D3D12_HEAP_FLAG_NONE,
        &res_d,
        .D3D12_RESOURCE_STATE_COMMON,
        nil,
        &tex_resource.state)
    
    CreateShaderResourceView(device.device,tex_resource.state, &srvDesc2, hmdh)

    texture_2d(texture,cast(u32)heap_index,&tex_resource,heap.heap.value)

    return heap_index
}
load_texture_from_path_to_default_heap :: proc(path : string) -> u64{
    return load_texture_from_path(path,&default_srv_desc_heap)
}

load_texture_from_path :: proc(path : string,heap : ^GPUHeap) -> u64{
    tex := texture_from_file(strings.clone_to_cstring(path),4)
    return texture_add(&tex,heap)
}

*/
