#!/usr/bin/env python3
"""Find the smallest common CIDR supernet covering all given IPs and/or subnets.

Usage:
    common_supernet.py <ip-or-cidr> [<ip-or-cidr> ...]

Example:
    common_supernet.py 182.43.76.120 182.70.255.242 182.61.33.68 \
        182.93.7.194 182.52.90.106
"""

import argparse
import ipaddress
import sys


def common_supernet(entries):
    """Return the smallest ip_network that contains all given entries.

    Each entry may be a bare IP address (treated as a /32 or /128 host)
    or a CIDR network (e.g. "10.0.0.0/24"). All entries must be the same
    IP version (all IPv4 or all IPv6).
    """
    networks = []
    for entry in entries:
        try:
            net = ipaddress.ip_network(entry, strict=False)
        except ValueError as exc:
            raise ValueError(f"invalid IP/subnet {entry!r}: {exc}") from exc
        networks.append(net)

    versions = {net.version for net in networks}
    if len(versions) > 1:
        raise ValueError("cannot mix IPv4 and IPv6 entries")

    max_prefix = networks[0].max_prefixlen
    # Each network's own prefix length caps how many leading bits it can
    # possibly share with the others (a /24 network only "owns" 24 bits).
    bound = min(net.prefixlen for net in networks)

    bits = [format(int(net.network_address), f"0{max_prefix}b") for net in networks]

    prefix_len = 0
    for i in range(bound):
        if all(b[i] == bits[0][i] for b in bits):
            prefix_len += 1
        else:
            break

    base_bits = bits[0][:prefix_len] + "0" * (max_prefix - prefix_len)
    base_ip = ipaddress.ip_address(int(base_bits, 2))
    return ipaddress.ip_network(f"{base_ip}/{prefix_len}")


def main():
    parser = argparse.ArgumentParser(
        description="Find the smallest common CIDR supernet for a list of "
        "IPs and/or subnets."
    )
    parser.add_argument(
        "entries",
        nargs="+",
        help="IP addresses and/or CIDR subnets (e.g. 10.0.0.1 10.0.1.0/24)",
    )
    args = parser.parse_args()

    try:
        supernet = common_supernet(args.entries)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    print(supernet)


if __name__ == "__main__":
    main()
