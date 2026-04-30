//! Demonstrates consuming a reactor-mode .wasm module from Rust via wasmtime.
//!
//! This loads the cJSON wrapper module and calls its exports through linear memory:
//!   1. Call malloc() to allocate space in the wasm module's memory
//!   2. Write JSON bytes into that allocation
//!   3. Call parse_and_pretty_print() with pointer + length
//!   4. Read the result string from the returned pointer
//!   5. Call free() to release both allocations
//!
//! Usage:
//!   cargo run -- ../c-local/wasm/cjson.wasm '{"hello":"world"}'

use anyhow::{bail, Context, Result};
use std::env;
use wasmtime::*;
use wasmtime_wasi::preview1::WasiP1Ctx;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        bail!("Usage: {} <path-to-cjson.wasm> <json-string>", args[0]);
    }
    let wasm_path = &args[1];
    let json_input = &args[2];

    let engine = Engine::default();
    let module = Module::from_file(&engine, wasm_path)
        .with_context(|| format!("failed to load {}", wasm_path))?;

    let mut linker = Linker::<WasiP1Ctx>::new(&engine);
    wasmtime_wasi::preview1::add_to_linker_sync(&mut linker, |ctx| ctx)?;

    let wasi_ctx = wasmtime_wasi::WasiCtxBuilder::new().build_p1();
    let mut store = Store::new(&engine, wasi_ctx);

    let instance = linker.instantiate(&mut store, &module)?;

    let memory = instance
        .get_memory(&mut store, "memory")
        .context("missing 'memory' export")?;
    let malloc = instance
        .get_typed_func::<i32, i32>(&mut store, "malloc")
        .context("missing 'malloc' export")?;
    let free = instance
        .get_typed_func::<i32, ()>(&mut store, "free")
        .context("missing 'free' export")?;
    let parse_and_pretty_print = instance
        .get_typed_func::<(i32, i32), i32>(&mut store, "parse_and_pretty_print")
        .context("missing 'parse_and_pretty_print' export")?;

    // Step 1: Allocate space for input
    let input_bytes = json_input.as_bytes();
    let input_ptr = malloc.call(&mut store, input_bytes.len() as i32)?;
    if input_ptr == 0 {
        bail!("malloc returned null");
    }

    // Step 2: Write JSON bytes into wasm memory
    memory.write(&mut store, input_ptr as usize, input_bytes)?;

    // Step 3: Call parse_and_pretty_print
    let result_ptr =
        parse_and_pretty_print.call(&mut store, (input_ptr, input_bytes.len() as i32))?;

    // Step 4: Read result (null-terminated C string)
    if result_ptr == 0 {
        bail!("parse_and_pretty_print returned null — invalid JSON?");
    }

    let mem_data = memory.data(&store);
    let result_start = result_ptr as usize;
    let result_end = mem_data[result_start..]
        .iter()
        .position(|&b| b == 0)
        .map(|pos| result_start + pos)
        .unwrap_or(mem_data.len());
    let result_str = std::str::from_utf8(&mem_data[result_start..result_end])?;

    println!("{}", result_str);

    // Step 5: Free both allocations
    free.call(&mut store, input_ptr)?;
    free.call(&mut store, result_ptr)?;

    Ok(())
}
