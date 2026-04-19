// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod status_parse;

fn main() {
    flow_monitor_lib::run()
}
