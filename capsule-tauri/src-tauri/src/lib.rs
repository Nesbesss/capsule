use std::io::Write;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Manager, Emitter};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cocoa::appkit::{NSWindow, NSWindowCollectionBehavior, NSWindowStyleMask};
use cocoa::base::{id, nil};
use objc::{msg_send, sel, sel_impl};
use whisper_rs::{WhisperContext, FullParams, SamplingStrategy};
use core_graphics::event::{CGEventTapLocation, CGEventTapOptions, CGEventTapProxy, CGEventType, CGEventFlags, CGEvent};
use core_foundation::runloop::{CFRunLoop, kCFRunLoopCommonModes};
use core_foundation::base::TCFType;

struct AppState {
    is_recording: Mutex<bool>,
    audio_buffer: Arc<Mutex<Vec<f32>>>,
    stream: Mutex<Option<cpal::Stream>>,
    whisper_ctx: Arc<Mutex<Option<WhisperContext>>>,
    last_alt_state: Mutex<bool>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(AppState {
            is_recording: Mutex::new(false),
            audio_buffer: Arc::new(Mutex::new(Vec::new())),
            stream: Mutex::new(None),
            whisper_ctx: Arc::new(Mutex::new(None)),
            last_alt_state: Mutex::new(false),
        })
        .setup(|app| {
            // macOS Window Customization (Delayed to ensure window is ready)
            #[cfg(target_os = "macos")]
            {
                let handle = app.handle().clone();
                std::thread::spawn(move || {
                    std::thread::sleep(std::time::Duration::from_millis(1500));
                    let h = handle.clone();
                    let _ = handle.run_on_main_thread(move || {
                        if let Some(win) = h.get_webview_window("main") {
                            if let Ok(ns_win_ptr) = win.ns_window() {
                                let ns_window = ns_win_ptr as id;
                                if ns_window != nil {
                                    unsafe {
                                        // Set as floating panel (Level 3 = NSFloatingWindowLevel)
                                        ns_window.setLevel_(3);
                                        let mut style_mask = ns_window.styleMask();
                                        // NSNonactivatingPanelMask = 1 << 7
                                        if let Some(mask) = NSWindowStyleMask::from_bits(1 << 7) {
                                             style_mask.insert(mask);
                                        }
                                        ns_window.setStyleMask_(style_mask);
                                        
                                        ns_window.setCollectionBehavior_(
                                            NSWindowCollectionBehavior::NSWindowCollectionBehaviorCanJoinAllSpaces |
                                            NSWindowCollectionBehavior::NSWindowCollectionBehaviorFullScreenAuxiliary
                                        );
                                        println!("🪟 Native floating window styles applied on main thread");
                                    }
                                }
                            }
                        }
                    });
                });
            }

            // Unpack Whisper model setup
             let handle = app.handle().clone();
             std::thread::spawn(move || {
                let resource_path = handle.path().resolve("models/ggml-base.en.bin", tauri::path::BaseDirectory::Resource).unwrap();
                let ctx = WhisperContext::new_with_params(&resource_path.to_string_lossy(), Default::default())
                    .expect("failed to load model");
                
                let state = handle.state::<AppState>();
                *state.whisper_ctx.lock().unwrap() = Some(ctx);
                println!("🧠 Whisper model loaded");
             });

            // Native macOS Global Hotkey Listener (CGEventTap)
            let app_handle = app.handle().clone();
            std::thread::spawn(move || {
                unsafe {
                    let h_ptr = Box::into_raw(Box::new(app_handle)) as *mut std::ffi::c_void;
                    
                    extern "C" fn callback(
                        _proxy: CGEventTapProxy,
                        _type: CGEventType,
                        event: &CGEvent,
                        user_data: *mut std::ffi::c_void,
                    ) -> *const CGEvent {
                        let app = unsafe { &*(user_data as *const AppHandle) };
                        let state = app.state::<AppState>();
                        let flags = event.get_flags();
                        
                        // kCGEventFlagMaskAlternate = 0x00080000
                        let is_alt = flags.contains(CGEventFlags::CGEventFlagAlternate);
                        
                        let mut last_state = state.last_alt_state.lock().unwrap();
                        if is_alt != *last_state {
                            *last_state = is_alt;
                            if is_alt {
                                let a = app.clone();
                                std::thread::spawn(move || start_recording(&a));
                            } else {
                                let a = app.clone();
                                std::thread::spawn(move || stop_recording(&a));
                            }
                        }
                        
                        // We return the event pointer as expected by CGEventTap
                        event as *const CGEvent
                    }

                    if let Ok(tap) = core_graphics::event::CGEventTap::new(
                        CGEventTapLocation::HID,
                        CGEventTapOptions::Default,
                        &[CGEventType::FlagsChanged],
                        callback,
                        h_ptr,
                    ) {
                        let loop_source = tap.mach_port.create_runloop_source(0).expect("failed to create runloop source");
                        let run_loop = CFRunLoop::get_current();
                        run_loop.add_source(&loop_source, kCFRunLoopCommonModes);
                        tap.enable();
                        println!("🎹 Native EventTap enabled (HID)");
                        CFRunLoop::run_current();
                    } else {
                        eprintln!("❌ Failed to create EventTap. Check Input Monitoring permissions.");
                    }
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

fn start_recording(app: &AppHandle) {
    let state = app.state::<AppState>();
    {
        let mut is_recording = match state.is_recording.lock() {
            Ok(lock) => lock,
            Err(_) => return,
        };
        if *is_recording { return; }
        *is_recording = true;
    }
    println!("🔴 Starting Recording...");

    // Show window on main thread
    let h = app.clone();
    let _ = h.clone().run_on_main_thread(move || {
        if let Some(win) = h.get_webview_window("main") {
            let _ = win.show();
            let _ = win.set_focus();
        }
    });
    
    let _ = app.emit("recording-started", ());

    let audio_buffer = state.audio_buffer.clone();
    let app_h = app.clone();

    // Start CPAL stream safely
    let host = cpal::default_host();
    let device = match host.default_input_device() {
        Some(d) => d,
        None => {
            eprintln!("❌ No input device found");
            return;
        }
    };
    
    let config = match device.default_input_config() {
        Ok(c) => c.into(),
        Err(e) => {
            eprintln!("❌ Failed to get input config: {:?}", e);
            return;
        }
    };
    println!("🎙️ Audio config: {:?}", config);

    let err_fn = move |err| {
        eprintln!("an error occurred on stream: {}", err);
    };

    let stream_res = device.build_input_stream(
        &config,
        move |data: &[f32], _: &_| {
            if let Ok(mut buffer) = audio_buffer.lock() {
                buffer.extend_from_slice(data);
            }
            let sum_squares: f32 = data.iter().map(|s| s * s).sum();
            let rms = (sum_squares / data.len() as f32).sqrt();
            let _ = app_h.emit("amplitude", rms);
        },
        err_fn,
        None,
    );

    match stream_res {
        Ok(stream) => {
            if let Err(e) = stream.play() {
                eprintln!("❌ Failed to play stream: {:?}", e);
            } else {
                println!("▶️ Stream playing");
                if let Ok(mut s_guard) = state.stream.lock() {
                    *s_guard = Some(stream);
                }
            }
        }
        Err(e) => {
            eprintln!("❌ Failed to build stream: {:?}", e);
        }
    }
}

fn stop_recording(app: &AppHandle) {
    let state = app.state::<AppState>();
    {
        let mut is_recording = match state.is_recording.lock() {
            Ok(lock) => lock,
            Err(_) => return,
        };
        if !*is_recording { return; }
        *is_recording = false;
    }

    // Stop stream
    {
        if let Ok(mut stream_guard) = state.stream.lock() {
            if let Some(stream) = stream_guard.take() {
                drop(stream); 
            }
        }
    }
    
    println!("⏹ Stopping Recording");
    let _ = app.emit("recording-stopped", ());
    
    // Process audio
    let audio_data = {
        if let Ok(mut buffer) = state.audio_buffer.lock() {
            let data = buffer.clone();
            buffer.clear();
            data
        } else {
            return;
        }
    };
    
    // Transcribe in background
    let app_handle = app.clone();
    std::thread::spawn(move || {
        let state = app_handle.state::<AppState>();
        let ctx_guard = match state.whisper_ctx.lock() {
            Ok(lock) => lock,
            Err(_) => return,
        };
        
        if let Some(ctx) = ctx_guard.as_ref() {
            let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
            params.set_language(Some("en"));
            params.set_print_special(false);
            params.set_print_progress(false);
            params.set_print_realtime(false);
            params.set_print_timestamps(false);

            let whisper_state = match ctx.create_state() {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("❌ Failed to create whisper state: {:?}", e);
                    return;
                }
            };
            
            let mut s = whisper_state;
            match s.full(params, &audio_data) {
                Ok(_) => {
                    let num_segments = s.full_n_segments();
                    let mut text = String::new();
                    for i in 0..num_segments {
                        if let Some(segment) = s.get_segment(i) {
                            text.push_str(&segment.to_string());
                        }
                    }
                    println!("✅ Transcription: {}", text);
                    let _ = app_handle.emit("transcription", text.trim());
                    
                    // Copy to clipboard
                    if let Ok(mut child) = std::process::Command::new("pbcopy")
                        .stdin(std::process::Stdio::piped())
                        .spawn() 
                    {
                        if let Some(mut stdin) = child.stdin.take() {
                            let _ = stdin.write_all(text.trim().as_bytes());
                        }
                        let _ = child.wait();
                    }
                    
                    // Paste
                    let _ = std::process::Command::new("osascript")
                        .arg("-e")
                        .arg("tell application \"System Events\" to keystroke \"v\" using {command down}")
                        .output();
                }
                Err(e) => {
                    eprintln!("❌ Failed to run model: {}", e);
                }
            }
        }
    });
}

