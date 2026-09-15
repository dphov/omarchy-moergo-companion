use serde_json::Value;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::process::{Command, Stdio};

const NOTIFY_STATE_FILE: &str = "/tmp/glove80_battery_notified.json";
const LOW_PCT: i64 = 20;
const CRITICAL_PCT: i64 = 10;
const RECOVERY_MARGIN: i64 = 5;

#[derive(Debug, Default)]
struct UsbState {
    left: bool,
    right: bool,
}

fn check_usb() -> UsbState {
    let mut state = UsbState::default();
    let paths = match fs::read_dir("/sys/bus/usb/devices") {
        Ok(p) => p,
        Err(_) => return state,
    };

    for entry in paths.flatten() {
        let base = entry.path();
        let vid = match fs::read_to_string(base.join("idVendor")) {
            Ok(s) => s.trim().to_lowercase(),
            Err(_) => continue,
        };
        if vid != "16c0" {
            continue;
        }
        let pid = fs::read_to_string(base.join("idProduct"))
            .unwrap_or_default()
            .trim()
            .to_lowercase();
        if pid == "27db" {
            state.left = true;
        } else if pid == "27d9" {
            state.right = true;
        }

        if let Ok(pname) = fs::read_to_string(base.join("product")) {
            let pname = pname.to_lowercase();
            if pname.contains("glove80 left") {
                state.left = true;
            } else if pname.contains("glove80 right") {
                state.right = true;
            }
        }
    }

    state
}

fn run_command(args: &[&str], timeout_secs: u64) -> Option<String> {
    let mut child = Command::new(args[0])
        .args(&args[1..])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    let pid = child.id();
    let timeout = std::time::Duration::from_secs(timeout_secs);
    let start = std::time::Instant::now();

    loop {
        match child.try_wait().ok()? {
            Some(status) => {
                if !status.success() {
                    return None;
                }
                let mut stdout = String::new();
                if let Some(mut pipe) = child.stdout.take() {
                    use std::io::Read;
                    let _ = pipe.read_to_string(&mut stdout);
                }
                return Some(stdout);
            }
            None => {
                if start.elapsed() >= timeout {
                    unsafe {
                        libc::kill(pid as libc::pid_t, libc::SIGTERM);
                    }
                    return None;
                }
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
        }
    }
}

#[derive(Debug, Default, serde::Serialize)]
struct DeviceInfo {
    address: String,
    name: String,
    connected: bool,
    paired: bool,
    trusted: bool,
    battery_levels: Vec<i64>,
}

fn get_device_info() -> DeviceInfo {
    let mut dev = DeviceInfo::default();
    dev.name = "Glove80".to_string();

    let output = match run_command(
        &[
            "busctl",
            "call",
            "-j",
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects",
        ],
        2,
    ) {
        Some(o) => o,
        None => return dev,
    };

    let json: Value = match serde_json::from_str(&output) {
        Ok(v) => v,
        Err(_) => return dev,
    };

    let data = json
        .get("data")
        .and_then(|d| d.as_array())
        .and_then(|a| a.first())
        .and_then(|v| v.as_object())
        .cloned()
        .unwrap_or_default();

    // Find device path.
    let mut dev_path: Option<String> = None;
    for (path, ifaces) in &data {
        let ifaces = match ifaces.as_object() {
            Some(i) => i,
            None => continue,
        };
        let device = match ifaces.get("org.bluez.Device1").and_then(|v| v.as_object()) {
            Some(d) => d,
            None => continue,
        };

        let d_name = device
            .get("Name")
            .and_then(|n| n.get("data"))
            .and_then(|v| v.as_str())
            .or_else(|| {
                device
                    .get("Alias")
                    .and_then(|n| n.get("data"))
                    .and_then(|v| v.as_str())
            })
            .unwrap_or("")
            .to_lowercase();
        let modalias = device
            .get("Modalias")
            .and_then(|n| n.get("data"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();

        if d_name.contains("glove80")
            || d_name.contains("zmk")
            || modalias.contains("v16c0p27db")
            || modalias.contains("v1d50p615e")
        {
            dev_path = Some(path.clone());
            dev.name = device
                .get("Name")
                .and_then(|n| n.get("data"))
                .and_then(|v| v.as_str())
                .or_else(|| {
                    device
                        .get("Alias")
                        .and_then(|n| n.get("data"))
                        .and_then(|v| v.as_str())
                })
                .unwrap_or("Glove80")
                .to_string();
            dev.address = device
                .get("Address")
                .and_then(|n| n.get("data"))
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            dev.connected = device
                .get("Connected")
                .and_then(|n| n.get("data"))
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            dev.paired = device
                .get("Paired")
                .and_then(|n| n.get("data"))
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            dev.trusted = device
                .get("Trusted")
                .and_then(|n| n.get("data"))
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            break;
        }
    }

    // Read GATT battery levels.
    if let Some(prefix) = dev_path {
        let mut levels: Vec<(String, i64)> = Vec::new();
        for (path, ifaces) in &data {
            if !path.starts_with(&prefix) {
                continue;
            }
            let ifaces = match ifaces.as_object() {
                Some(i) => i,
                None => continue,
            };
            let char_iface = match ifaces
                .get("org.bluez.GattCharacteristic1")
                .and_then(|v| v.as_object())
            {
                Some(c) => c,
                None => continue,
            };
            let uuid = char_iface
                .get("UUID")
                .and_then(|u| u.get("data"))
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_lowercase();
            if !uuid.starts_with("00002a19") {
                continue;
            }

            // Always request a fresh read; BlueZ's cached Value can be stale
            // compared to the system Bluetooth settings panel.
            let mut level: Option<i64> = None;
            if let Some(out) = run_command(
                &[
                    "busctl",
                    "call",
                    "-j",
                    "org.bluez",
                    path,
                    "org.bluez.GattCharacteristic1",
                    "ReadValue",
                    "a{sv}",
                    "0",
                ],
                1,
            ) {
                if let Ok(v) = serde_json::from_str::<Value>(&out) {
                    level = v
                        .get("data")
                        .and_then(|d| d.as_array())
                        .and_then(|a| a.first())
                        .and_then(|v| v.as_array())
                        .and_then(|a| a.first())
                        .and_then(|v| v.as_i64());
                }
            }

            // Fall back to cached Value only if a live read fails.
            if level.is_none() {
                level = char_iface
                    .get("Value")
                    .and_then(|v| v.get("data"))
                    .and_then(|v| v.as_array())
                    .and_then(|a| a.first())
                    .and_then(|v| v.as_i64());
            }

            if let Some(l) = level {
                levels.push((path.clone(), l));
            }
        }

        levels.sort_by(|a, b| a.0.cmp(&b.0));
        dev.battery_levels = levels.into_iter().map(|(_, l)| l).collect();
    }

    // Fallback to UPower.
    if dev.battery_levels.is_empty() {
        if let Some(out) = run_command(&["upower", "-e"], 1) {
            for line in out.lines() {
                let line = line.trim();
                if line.contains("keyboard") || line.contains("Glove80") {
                    if let Some(info) = run_command(&["upower", "-i", line], 1) {
                        if info.contains("Glove80") {
                            if let Some(pct) = info
                                .lines()
                                .find(|l| l.contains("percentage:"))
                                .and_then(|l| {
                                    l.split_whitespace()
                                        .find(|w| w.ends_with('%'))
                                        .and_then(|w| w.trim_end_matches('%').parse::<i64>().ok())
                                })
                            {
                                dev.battery_levels.push(pct);
                                dev.connected = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    dev
}

fn read_notify_state() -> HashMap<String, bool> {
    fs::read_to_string(NOTIFY_STATE_FILE)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| {
            let mut m = HashMap::new();
            m.insert("low".to_string(), false);
            m.insert("critical".to_string(), false);
            m
        })
}

fn save_notify_state(state: &HashMap<String, bool>) {
    let _ = fs::write(NOTIFY_STATE_FILE, serde_json::to_string(state).unwrap_or_default());
}

fn send_notification(urgency: &str, icon: &str, title: &str, body: &str) {
    let _ = Command::new("notify-send")
        .args(["-u", urgency, "-i", icon, title, body])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn check_low_battery_notifications(battery: Option<i64>, charging: bool) {
    if battery.is_none() || charging {
        let _ = fs::remove_file(NOTIFY_STATE_FILE);
        return;
    }
    let battery = battery.unwrap();

    let mut state = read_notify_state();

    if battery >= LOW_PCT + RECOVERY_MARGIN {
        state.insert("low".to_string(), false);
    }
    if battery >= CRITICAL_PCT + RECOVERY_MARGIN {
        state.insert("critical".to_string(), false);
    }

    if battery <= CRITICAL_PCT && !state.get("critical").copied().unwrap_or(false) {
        send_notification(
            "critical",
            "battery-caution-symbolic",
            "Glove80 battery critical",
            &format!("{battery}% — charge now."),
        );
        state.insert("critical".to_string(), true);
        state.insert("low".to_string(), true);
    } else if battery <= LOW_PCT && !state.get("low").copied().unwrap_or(false) {
        send_notification(
            "normal",
            "battery-low-symbolic",
            "Glove80 battery low",
            &format!("{battery}% remaining."),
        );
        state.insert("low".to_string(), true);
    }

    save_notify_state(&state);
}

fn execute_action(action: &str) -> Value {
    let dev = get_device_info();
    if dev.address.is_empty() {
        return serde_json::json!({
            "success": false,
            "error": "No paired Glove80 device found",
        });
    }

    let bt_cmd = match action {
        "--connect" => "connect",
        "--disconnect" => "disconnect",
        "--trust" => "trust",
        "--untrust" => "untrust",
        "--forget" => "remove",
        _ => {
            return serde_json::json!({
                "success": false,
                "error": format!("Unknown action: {action}"),
            });
        }
    };

    match Command::new("bluetoothctl")
        .args([bt_cmd, &dev.address])
        .output()
    {
        Ok(out) => {
            let success = out.status.success();
            let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
            let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
            serde_json::json!({
                "success": success,
                "output": stdout,
                "error": if success { "" } else { &stderr },
            })
        }
        Err(e) => serde_json::json!({
            "success": false,
            "error": e.to_string(),
        }),
    }
}

fn get_status() -> Value {
    let usb = check_usb();
    let dev = get_device_info();
    let bt_conn = dev.connected;
    let levels = dev.battery_levels.clone();
    let pct = levels.first().copied();

    let is_charging = usb.left || usb.right;
    let connected = usb.left || usb.right || bt_conn;

    check_low_battery_notifications(pct, is_charging);

    let icon = "\u{f11c} "; // keyboard icon

    if !connected {
        return serde_json::json!({
            "connected": false,
            "text": "\u{f11c} Off",
            "tooltip": "MoErgo Glove80: Disconnected",
            "battery": Value::Null,
            "batteryLevels": levels,
            "charging": false,
            "usbLeft": false,
            "usbRight": false,
            "device": dev,
        });
    }

    let left_level = levels.first().copied().or(pct);
    let right_level = levels.get(1).copied();

    let l_str = if usb.left {
        left_level.map_or("L\u{26a1}".to_string(), |l| format!("L\u{26a1}{l}%"))
    } else {
        left_level.map_or_else(|| "".to_string(), |l| format!("L{l}%"))
    };

    let r_str = if usb.right {
        right_level.map_or("R\u{26a1}".to_string(), |l| format!("R\u{26a1}{l}%"))
    } else {
        right_level.map_or_else(|| "".to_string(), |l| format!("R{l}%"))
    };

    let text = if levels.len() >= 2 {
        format!("{icon}{l_str} {r_str}").trim().to_string()
    } else if usb.left && usb.right {
        pct.map_or(format!("{icon}\u{26a1} USB"), |p| format!("{icon}\u{26a1} {p}%"))
    } else if usb.left {
        pct.map_or(format!("{icon}\u{26a1} USB"), |p| format!("{icon}\u{26a1} {p}%"))
    } else if usb.right {
        pct.map_or(format!("{icon}R\u{26a1}"), |p| format!("{icon}{p}% R\u{26a1}"))
    } else if let Some(p) = pct {
        format!("{icon}{p}%")
    } else if bt_conn {
        format!("{icon}Connected")
    } else {
        format!("{icon}Disconnected")
    };

    let conn_mode = if usb.left && usb.right {
        "Both halves connected via USB"
    } else if usb.left {
        "Left: USB (charging), Right: wireless"
    } else if usb.right {
        "Left: wireless, Right: USB (charging)"
    } else {
        "Bluetooth"
    };

    let tooltip = if levels.len() >= 2 {
        format!("MoErgo Glove80: Left {}%, Right {}% ({conn_mode})", levels[0], levels[1])
    } else if let Some(p) = pct {
        format!("MoErgo Glove80: {p}% ({conn_mode})")
    } else {
        format!("MoErgo Glove80: {conn_mode}")
    };

    serde_json::json!({
        "connected": true,
        "text": text,
        "tooltip": tooltip,
        "battery": pct,
        "batteryLevels": levels,
        "charging": is_charging,
        "usbLeft": usb.left,
        "usbRight": usb.right,
        "device": dev,
    })
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 && args[1].starts_with("--") {
        let action = args[1].as_str();
        if matches!(
            action,
            "--connect" | "--disconnect" | "--trust" | "--untrust" | "--forget"
        ) {
            let result = execute_action(action);
            println!("{}", serde_json::to_string(&result).unwrap_or_default());
            std::process::exit(if result.get("success").and_then(|v| v.as_bool()).unwrap_or(false) {
                0
            } else {
                1
            });
        }
    }

    let status = get_status();
    println!("{}", serde_json::to_string(&status).unwrap_or_default());
}
