//! CSV to JSON converter — demonstrates the CLI tool (command mode) pattern.
//!
//! Reads CSV from stdin, writes JSON array to stdout.
//! No FFI, no manual memory management — just standard Rust I/O via WASI.
//!
//! Usage (with wasmtime):
//!   echo "name,age\nAlice,30\nBob,25" | wasmtime run csv2json.wasm

use std::io::{self, Read};

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).expect("failed to read stdin");

    let mut reader = csv::Reader::from_reader(input.as_bytes());
    let headers: Vec<String> = reader
        .headers()
        .expect("failed to read CSV headers")
        .iter()
        .map(|h| h.to_string())
        .collect();

    let mut records: Vec<serde_json::Value> = Vec::new();
    for result in reader.records() {
        let record = result.expect("failed to read CSV record");
        let mut obj = serde_json::Map::new();
        for (i, field) in record.iter().enumerate() {
            let key = headers.get(i).cloned().unwrap_or_else(|| format!("col{}", i));
            obj.insert(key, serde_json::Value::String(field.to_string()));
        }
        records.push(serde_json::Value::Object(obj));
    }

    let json = serde_json::to_string_pretty(&records).expect("failed to serialize JSON");
    println!("{}", json);
}
