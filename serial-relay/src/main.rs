//! USB relay controller for 4-channel relay modules (CH340 chipset).
//!
//! Protocol: [0xA0, channel(1-4), opcode, checksum]
//!   opcode: 0x00=OFF, 0x01=ON, 0x02=OFF+feedback, 0x03=ON+feedback,
//!           0x04=TOGGLE, 0x05=STATUS
//!   checksum = (0xA0 + channel + opcode) & 0xFF
//!
//! Baud rate is set at compile-time via [package.metadata] in Cargo.toml.

use clap::Parser;
use serialport;
use std::io::{Read, Write};
use std::process;
use std::time::Duration;

// Compile-time baud rate from build.rs (reads Cargo.toml metadata)
use std::sync::LazyLock;
static BAUD_RATE: LazyLock<u32> = LazyLock::new(|| {
    env!("BAUD_RATE").parse().expect("BAUD_RATE must be a valid integer")
});

#[derive(Parser)]
#[command(
    name = "serial",
    about = format!("4-channel USB relay controller ({} baud)", *BAUD_RATE),
    long_about = format!(
        "Control a 4-channel USB relay module over RS-232 serial.\n\
         Baud rate: {baud} (configurable in Cargo.toml)\n\
         \n\
         Examples:\n  serial -d /dev/ttyUSB1 -p 0 on\n  \
         serial -d /dev/ttyUSB1 -p 1 off\n  \
         serial -d /dev/ttyUSB1 -p 2 toggle\n  \
         serial -d /dev/ttyUSB1 -p 3 status",
        baud = *BAUD_RATE
    )
)]
struct Cli {
    /// Serial device path
    #[arg(
        short = 'd',
        long = "device",
        default_value = "/dev/ttyUSB1",
        help = "Serial device path (e.g. /dev/ttyUSB1, /dev/serial/by-id/...)"
    )]
    device: String,

    /// Relay port number (0=CH1, 1=CH2, 2=CH3, 3=CH4)
    #[arg(
        short = 'p',
        long = "port",
        value_parser = clap::value_parser!(u8).range(0..=3),
        help = "Relay port: 0=CH1, 1=CH2, 2=CH3, 3=CH4"
    )]
    port: u8,

    /// Operation to perform
    #[arg(
        value_parser = ["on", "off", "toggle", "status", "open", "close"],
        help = "Action: on/open=close relay, off/close=open relay, \
                toggle=flip state, status=query"
    )]
    action: String,
}

/// Map the CLI action string to the protocol opcode byte.
fn action_to_opcode(action: &str) -> u8 {
    match action {
        "on" | "open" => 0x01,
        "off" | "close" => 0x00,
        "toggle" => 0x04,
        "status" => 0x05,
        _ => unreachable!("action validated by clap"),
    }
}

/// Build the 4-byte command packet: [header, channel, opcode, checksum].
fn build_packet(channel: u8, opcode: u8) -> [u8; 4] {
    let header: u8 = 0xA0;
    let checksum = (header as u32 + channel as u32 + opcode as u32) as u8;
    [header, channel, opcode, checksum]
}

/// Print packet bytes in hex for debugging.
fn fmt_packet(pkt: &[u8; 4]) -> String {
    format!(
        "{:02X} {:02X} {:02X} {:02X}",
        pkt[0], pkt[1], pkt[2], pkt[3]
    )
}

/// Parse and display the response from the relay module.
fn parse_response(buf: &[u8], channel: u8) {
    if buf.is_empty() {
        println!("CH{channel} query: no response");
        return;
    }
    match buf.len() {
        1 => {
            let state = if buf[0] & 0x01 != 0 { "ON" } else { "OFF" };
            println!("CH{channel} status: {state} (raw=0x{b:02X})", b = buf[0]);
        }
        n => {
            let hex: Vec<String> = buf.iter().map(|b| format!("{b:02X}")).collect();
            println!("CH{channel} response ({n} bytes): {}", hex.join(" "));
        }
    }
}

fn main() {
    let cli = Cli::parse();

    let channel = cli.port + 1; // map port 0..3 -> channel 1..4
    let opcode = action_to_opcode(&cli.action);
    let packet = build_packet(channel, opcode);

    let action_label = match cli.action.as_str() {
        "open" | "on" => "ON",
        "close" | "off" => "OFF",
        "toggle" => "TOGGLE",
        "status" => "STATUS",
        _ => &cli.action,
    };

    eprintln!("Device: {}, CH{channel}, Action: {action_label}", cli.device);
    eprintln!("Sent: {} (checksum=0x{:02X})", fmt_packet(&packet), packet[3]);

    // Open serial port with compile-time baud rate, 8N1
    let mut port = match serialport::new(&cli.device, *BAUD_RATE)
        .timeout(Duration::from_millis(800))
        .open()
    {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Error: cannot open serial port {} — {e}", cli.device);
            process::exit(1);
        }
    };

    // Clear stale receive buffer
    let _ = port.clear(serialport::ClearBuffer::Input);

    // Send command
    if let Err(e) = port.write_all(&packet) {
        eprintln!("Error: write failed — {e}");
        process::exit(1);
    }
    if let Err(e) = port.flush() {
        eprintln!("Error: flush failed — {e}");
        process::exit(1);
    }

    // Wait briefly for the device to process
    std::thread::sleep(Duration::from_millis(50));

    if cli.action == "status" {
        let mut buf = [0u8; 16];
        match port.read(&mut buf) {
            Ok(n) => parse_response(&buf[..n], channel),
            Err(e) => {
                if e.kind() == std::io::ErrorKind::TimedOut {
                    println!("CH{channel} query: timeout (no response)");
                } else {
                    eprintln!("Error: read failed — {e}");
                    process::exit(1);
                }
            }
        }
    } else {
        println!("CH{channel} done: {action_label}");
    }
}
