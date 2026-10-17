#!/usr/bin/env python3 -I
"""
Converte o JSON exportado pelo save_game.lua em .rbxlx
Uso: python3 json_to_rbxlx.py game_12345.json [saida.rbxlx]
"""

import json
import sys
import xml.etree.ElementTree as ET

REF_COUNTER = 0

def next_ref():
    global REF_COUNTER
    REF_COUNTER += 1
    return f"RBX{REF_COUNTER}"

def add_prop(props, tag, name, value):
    el = ET.SubElement(props, tag, name=name)
    el.text = str(value)

def add_vector3(props, name, xyz):
    v = ET.SubElement(props, "Vector3", name=name)
    ET.SubElement(v, "X").text = str(xyz[0])
    ET.SubElement(v, "Y").text = str(xyz[1])
    ET.SubElement(v, "Z").text = str(xyz[2])

def add_cframe(props, name, xyz):
    cf = ET.SubElement(props, "CoordinateFrame", name=name)
    ET.SubElement(cf, "X").text = str(xyz[0])
    ET.SubElement(cf, "Y").text = str(xyz[1])
    ET.SubElement(cf, "Z").text = str(xyz[2])
    for r, v in [("R00","1"),("R01","0"),("R02","0"),
                 ("R10","0"),("R11","1"),("R12","0"),
                 ("R20","0"),("R21","0"),("R22","1")]:
        ET.SubElement(cf, r).text = v

def add_color3(props, name, rgb):
    r, g, b = int(rgb[0]*255), int(rgb[1]*255), int(rgb[2]*255)
    el = ET.SubElement(props, "Color3uint8", name=name)
    el.text = str((r << 16) | (g << 8) | b)

MATERIAL_MAP = {
    "Plastic": "256", "Wood": "512", "Slate": "800",
    "Concrete": "816", "CorrodedMetal": "1040", "DiamondPlate": "1056",
    "Foil": "1072", "Grass": "1280", "Ice": "1536",
    "Marble": "784", "Granite": "832", "Brick": "848",
    "Pebble": "864", "Sand": "1296", "Fabric": "1312",
    "SmoothPlastic": "272", "Metal": "1040", "WoodPlanks": "528",
    "Cobblestone": "880", "Neon": "288", "Glass": "1568",
    "ForceField": "1584",
}

def serialize_node(parent_xml, node):
    class_name = node.get("ClassName", "Folder")
    item = ET.SubElement(parent_xml, "Item", {
        "class": class_name,
        "referent": next_ref()
    })
    props = ET.SubElement(item, "Properties")
    add_prop(props, "string", "Name", node.get("Name", class_name))

    if "Position" in node:
        add_cframe(props, "CFrame", node["Position"])
    if "Size" in node:
        add_vector3(props, "size", node["Size"])
    if "Anchored" in node:
        add_prop(props, "bool", "Anchored", str(node["Anchored"]).lower())
    if "CanCollide" in node:
        add_prop(props, "bool", "CanCollide", str(node["CanCollide"]).lower())
    if "Transparency" in node:
        add_prop(props, "float", "Transparency", str(node["Transparency"]))
    if "Color" in node:
        add_color3(props, "Color3uint8", node["Color"])
    if "Material" in node:
        mat = MATERIAL_MAP.get(node["Material"], "256")
        add_prop(props, "token", "Material", mat)
    if "Source" in node:
        src = ET.SubElement(props, "ProtectedString", name="Source")
        src.text = node["Source"]

    for child in node.get("Children", []):
        serialize_node(item, child)

    return item

def convert(json_path, output_path):
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    root = ET.Element("roblox", {
        "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime",
        "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
        "version": "4",
    })

    for svc_name, svc_data in data.get("Services", {}).items():
        serialize_node(root, svc_data)

    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"Convertido: {json_path} -> {output_path}")
    print("Abre no Roblox Studio!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 json_to_rbxlx.py game_12345.json [saida.rbxlx]")
        sys.exit(1)
    json_file = sys.argv[1]
    out_file = sys.argv[2] if len(sys.argv) > 2 else json_file.replace(".json", ".rbxlx")
    convert(json_file, out_file)
