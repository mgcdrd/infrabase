from __future__ import annotations

DOCUMENTATION = r"""
name: merge_firewall_zones
short_description: Merge layered firewall zone lists by zone name
description:
  - Takes a list of layers, each a list of C(firewall_zones)-style zone dicts
    (the role's base list first, then every C(firewall_zones_extra_*) layer),
    and returns one zone list.
  - Zones are matched by C(name). List keys (interfaces, sources, allowed
    ports/services, source_rules, forward_ports) are concatenated and
    de-duplicated, with ports compared as strings so C(22) and C("22") collapse.
    Any other key (for example C(masquerade)) takes the value from the last
    layer that sets it. Zones that appear in only one layer pass through.
author: mgcdrd
"""

LIST_KEYS = (
    "interfaces",
    "sources",
    "allowed_tcp_ports",
    "allowed_udp_ports",
    "allowed_services",
    "source_rules",
    "forward_ports",
)


def _dedupe(items):
    seen = []
    out = []
    for item in items:
        key = item if isinstance(item, dict) else str(item)
        if key not in seen:
            seen.append(key)
            out.append(item)
    return out


def merge_firewall_zones(layers):
    merged = {}
    for layer in layers:
        for zone in layer or []:
            current = merged.setdefault(zone["name"], {"name": zone["name"]})
            for key, value in zone.items():
                if key == "name":
                    continue
                if key in LIST_KEYS:
                    current[key] = _dedupe(list(current.get(key, [])) + list(value or []))
                else:
                    current[key] = value
    return list(merged.values())


class FilterModule:
    def filters(self):
        return {"merge_firewall_zones": merge_firewall_zones}
