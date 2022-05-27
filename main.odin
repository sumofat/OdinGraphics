package main

import fmt "core:fmt"
import D3D11 "vendor:directx/d3d11"
import D3D12 "vendor:directx/d3d12"
import DXGI  "vendor:directx/dxgi"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import runtime "core:runtime"
import la "core:math/linalg"
import m "core:math/linalg/hlsl"
import render "render"
/*
Remove the windows specific part of the windows

*/
Time :: struct{}
Input :: struct{}
Window :: struct{
	dim : m.float2,
	handle : rawptr,
	p : m.float2,
}

Platform :: struct{}
PlatformState :: struct{
	time : Time,
	input : Input,
	//    Renderer renderer,
	//    Audio audio,
	is_running : bool,
	//TODO(Ray):what will we do on other platforms not for sure yet.
	window : Window,
	//    Memory memory,
	//    info : windows.SYSTEM_INFO,
}

ps : PlatformState
main :: proc(){
	using fmt
	fmt.println("Running Main Odin")
	result_string,window_data := spawn_window(&ps,"TestWindow")
	fmt.println(result_string)
	fmt.println(window_data)
	render.init(windows.HWND(window_data.hwnd))

	render.load_scene("lantern.glb")

	for{
		handle_msgs(&window_data)
		using render
		render.RenderTick()
	}

}

Wnd_Proc :: proc "std" (hwnd : window32.Hwnd, uMsg : u32, wParam : window32.Wparam, lParam : window32.Lparam) -> window32.Lresult{
	context = runtime.default_context();
	//platform.ImGui_ImplWin32_WndProcHandler(hwnd, uMsg, wParam, lParam);
		switch (uMsg){
			case window32.WM_DESTROY:{
				window32.post_quit_message(0);
				return 0;
			}
			case window32.WM_PAINT:{
				ps : window32.Paint_Struct = {};
				hdc : window32.Hdc = window32.begin_paint(hwnd, &ps);

				//window32.fill_rect(hdc, &ps.rcPaint, window32.COLOR_BACKGROUND);

				window32.end_paint(hwnd, &ps);
				return 0;
			}
		}
		return window32.def_window_proc_a(hwnd, uMsg, wParam, lParam);
	}

WindowData :: struct {
    hInstance : window32.Hinstance,
    hwnd : window32.Hwnd,
    width : u32,
    height : u32,
};

ErrorStr :: cstring;
GWL_STYLE :: -16
WINSetScreenMode :: proc(ps : ^PlatformState,is_full_screen : bool){
}
set_screen_mode :: proc(ps : ^PlatformState,is_full_screen : bool){
	WINSetScreenMode(ps,is_full_screen)
}

spawn_window :: proc(ps : ^PlatformState,windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, WindowData){
    // Register the window class.
    
	using m
	window : WindowData;

    CLASS_NAME : cstring = "Main Window";

	wc : window32.Wnd_Class_Ex_A = {}; 
	hInstance := cast(window32.Hinstance)(window32.get_module_handle_a(nil));
	ps.is_running = true;
	ps.window.dim = float2{f32(width), f32(height)};
	ps.window.p = float2{};

	wc.size = size_of(window32.Wnd_Class_Ex_A);
	wc.wnd_proc = Wnd_Proc;
	wc.instance = hInstance;
	wc.class_name = CLASS_NAME;

	if window32.register_class_ex_a(&wc) == 0 do return "Failed to register class!", window;

    hwnd := window32.create_window_ex_a(
        0,
        CLASS_NAME,
        windowName,
        window32.WS_OVERLAPPEDWINDOW | window32.WS_VISIBLE,
        window32.CW_USEDEFAULT, window32.CW_USEDEFAULT, i32(ps.window.dim.x), i32(ps.window.dim.y),
        nil,
        nil,
        hInstance,
        nil,
    );

    ps.window.handle = hwnd;
    
    if hwnd == nil do return "failed to create window!", window;
    
    window.hInstance = hInstance;
    window.hwnd = hwnd;
    window.width = width;
    window.height = height;

    return nil, window;
}

handle_msgs :: proc(window : ^WindowData) -> bool{
    msg : window32.Msg = {};
    cont : bool = true;
    for window32.peek_message_a(&msg, nil, 0, 0, window32.PM_REMOVE){ 
        if msg.message == window32.WM_QUIT do cont = false;
        window32.translate_message(&msg);
        window32.dispatch_message_a(&msg);
    }
    return cont;
}
