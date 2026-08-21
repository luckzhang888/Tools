//! USB relay controller for 4-channel relay modules (CH340 chipset).
//!
//! Protocol: [0xA0, channel(1-4), opcode, checksum]
//!   opcode: 0x00=OFF, 0x01=ON, 0x02=OFF+feedback, 0x03=ON+feedback,
//!           0x04=TOGGLE, 0x05=STATUS
//!   checksum = (0xA0 + channel + opcode) & 0xFF
//!
//! Baud rate is set at compile-time via [package.metadata] in Cargo.toml.

use clap::{Parser, ValueEnum};
use std::io::{Read, Write};
use std::process;
use std::time::Duration;

// Compile-time baud rate from build.rs (reads Cargo.toml metadata)
use std::sync::LazyLock;
static BAUD_RATE: LazyLock<u32> = LazyLock::new(|| {
    env!("BAUD_RATE")
        .parse()
        .expect("BAUD_RATE must be a valid integer")
});

#[derive(Parser)]
#[command(
    name = "serial-relay",
    version,
    about = format!("4-channel USB relay controller ({} baud)", *BAUD_RATE),
    long_about = format!(
        "Control a 4-channel USB relay module over RS-232 serial.\n\
         Baud rate: {baud} (configurable in Cargo.toml)\n\
         \n\
         Examples:\n  serial-relay -d /dev/ttyUSB0 -p 0 on\n  \
         serial-relay -d /dev/ttyUSB0 -p 1 off\n  \
         serial-relay -d /dev/ttyUSB0 -p 2 toggle\n  \
         serial-relay -d /dev/ttyUSB0 -p 3 status",
        baud = *BAUD_RATE
    )
)]
struct Cli {
    /// Serial device path
    #[arg(
        short = 'd',
        long = "device",
        default_value = "/dev/ttyUSB0",
        help = "Serial device path (e.g. /dev/ttyUSB0 or /dev/serial/by-id/...)"
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
    #[arg(help = "Action: on/open=close relay, off/close=open relay, toggle=flip, status=query")]
    action: Action,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
enum Action {
    On,
    Off,
    Toggle,
    Status,
    Open,
    Close,
}

impl Action {
    fn opcode(self) -> u8 {
        match self {
            Self::On | Self::Open => 0x01,
            Self::Off | Self::Close => 0x00,
            Self::Toggle => 0x04,
            Self::Status => 0x05,
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::On | Self::Open => "ON",
            Self::Off | Self::Close => "OFF",
            Self::Toggle => "TOGGLE",
            Self::Status => "STATUS",
        }
    }
}

/// Build the 4-byte command packet: [header, channel, opcode, checksum].
fn build_packet(channel: u8, opcode: u8) -> [u8; 4] {
    let header: u8 = 0xA0;
    let checksum = header.wrapping_add(channel).wrapping_add(opcode);
    [header, channel, opcode, checksum]
}

fn fmt_bytes(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<Vec<_>>()
        .join(" ")
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RelayState {
    Off,
    On,
}

impl RelayState {
    fn label(self) -> &'static str {
        match self {
            Self::Off => "OFF",
            Self::On => "ON",
        }
    }
}

/// Decode either a legacy one-byte response or the relay's four-byte packet.
fn decode_status(buf: &[u8], channel: u8) -> Result<RelayState, String> {
    match buf {
        [state] => Ok(if state & 0x01 == 0 {
            RelayState::Off
        } else {
            RelayState::On
        }),
        [header, response_channel, state, checksum] => {
            if *header != 0xA0 {
                return Err(format!("unexpected header 0x{header:02X}"));
            }
            if *response_channel != channel {
                return Err(format!(
                    "response is for CH{response_channel}, expected CH{channel}"
                ));
            }
            let expected = header.wrapping_add(*response_channel).wrapping_add(*state);
            if *checksum != expected {
                return Err(format!(
                    "checksum mismatch: got 0x{checksum:02X}, expected 0x{expected:02X}"
                ));
            }
            match state {
                0x00 => Ok(RelayState::Off),
                0x01 => Ok(RelayState::On),
                value => Err(format!("unexpected state byte 0x{value:02X}")),
            }
        }
        _ => Err(format!("unexpected response length: {}", buf.len())),
    }
}

fn main() {
    let cli = Cli::parse();

    let channel = cli.port + 1; // map port 0..3 -> channel 1..4
    let opcode = cli.action.opcode();
    let packet = build_packet(channel, opcode);
    let action_label = cli.action.label();

    eprintln!(
        "Device: {}, CH{channel}, Action: {action_label}",
        cli.device
    );
    eprintln!(
        "Sent: {} (checksum=0x{:02X})",
        fmt_bytes(&packet),
        packet[3]
    );

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

    if cli.action == Action::Status {
        let mut buf = [0u8; 16];
        match port.read(&mut buf) {
            Ok(n) => match decode_status(&buf[..n], channel) {
                Ok(state) => println!(
                    "CH{channel} status: {} (response: {})",
                    state.label(),
                    fmt_bytes(&buf[..n])
                ),
                Err(message) => {
                    eprintln!("Error: invalid CH{channel} response — {message}");
                    eprintln!("Received: {}", fmt_bytes(&buf[..n]));
                    process::exit(1);
                }
            },
            Err(e) => {
                if e.kind() == std::io::ErrorKind::TimedOut {
                    eprintln!("Error: CH{channel} query timed out (no response)");
                } else {
                    eprintln!("Error: read failed — {e}");
                }
                process::exit(1);
            }
        }
    } else {
        println!("CH{channel} done: {action_label}");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cli_defaults_to_tty_usb_zero() {
        let cli = Cli::try_parse_from(["serial-relay", "-p", "0", "status"]).unwrap();
        assert_eq!(cli.device, "/dev/ttyUSB0");
        assert_eq!(cli.port, 0);
        assert_eq!(cli.action, Action::Status);
    }

    #[test]
    fn actions_map_to_protocol_opcodes() {
        assert_eq!(Action::On.opcode(), 0x01);
        assert_eq!(Action::Open.opcode(), 0x01);
        assert_eq!(Action::Off.opcode(), 0x00);
        assert_eq!(Action::Close.opcode(), 0x00);
        assert_eq!(Action::Toggle.opcode(), 0x04);
        assert_eq!(Action::Status.opcode(), 0x05);
    }

    #[test]
    fn packets_match_all_four_channels() {
        assert_eq!(build_packet(1, 0x01), [0xA0, 0x01, 0x01, 0xA2]);
        assert_eq!(build_packet(2, 0x00), [0xA0, 0x02, 0x00, 0xA2]);
        assert_eq!(build_packet(3, 0x04), [0xA0, 0x03, 0x04, 0xA7]);
        assert_eq!(build_packet(4, 0x05), [0xA0, 0x04, 0x05, 0xA9]);
    }

    #[test]
    fn decodes_observed_four_byte_status_packets() {
        assert_eq!(
            decode_status(&[0xA0, 0x01, 0x00, 0xA1], 1),
            Ok(RelayState::Off)
        );
        assert_eq!(
            decode_status(&[0xA0, 0x04, 0x01, 0xA5], 4),
            Ok(RelayState::On)
        );
    }

    #[test]
    fn rejects_corrupt_or_wrong_channel_responses() {
        assert!(decode_status(&[0xA0, 0x01, 0x01, 0x00], 1).is_err());
        assert!(decode_status(&[0xA0, 0x02, 0x01, 0xA3], 1).is_err());
        assert!(decode_status(&[0xA0, 0x01, 0x02, 0xA3], 1).is_err());
    }
}
