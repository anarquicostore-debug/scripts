#!/usr/bin/env python3 -I
"""
Converte JSON v2 (save_game.lua) em .rbxlx
Uso: python3 json_to_rbxlx.py game_12345.json [saida.rbxlx]
"""

import json, sys, math
import xml.etree.ElementTree as ET

REF = 0
def ref():
    global REF; REF += 1; return f"RBX{REF:08X}"

MATERIAL_MAP = {
    "Enum.Material.Plastic": "256", "Enum.Material.SmoothPlastic": "272",
    "Enum.Material.Neon": "288", "Enum.Material.Wood": "512",
    "Enum.Material.WoodPlanks": "528", "Enum.Material.Marble": "784",
    "Enum.Material.Slate": "800", "Enum.Material.Concrete": "816",
    "Enum.Material.Granite": "832", "Enum.Material.Brick": "848",
    "Enum.Material.Pebble": "864", "Enum.Material.Cobblestone": "880",
    "Enum.Material.CorrodedMetal": "1040", "Enum.Material.DiamondPlate": "1056",
    "Enum.Material.Foil": "1072", "Enum.Material.Grass": "1280",
    "Enum.Material.Sand": "1296", "Enum.Material.Fabric": "1312",
    "Enum.Material.Ice": "1536", "Enum.Material.Glass": "1568",
    "Enum.Material.ForceField": "1584", "Enum.Material.Metal": "1040",
}

FONT_MAP = {
    "Enum.Font.Legacy": "0", "Enum.Font.Arial": "1", "Enum.Font.ArialBold": "2",
    "Enum.Font.SourceSans": "3", "Enum.Font.SourceSansBold": "4",
    "Enum.Font.SourceSansSemibold": "16", "Enum.Font.SourceSansLight": "5",
    "Enum.Font.SourceSansItalic": "6", "Enum.Font.Bodoni": "7",
    "Enum.Font.Garamond": "8", "Enum.Font.Cartoon": "9",
    "Enum.Font.Code": "10", "Enum.Font.Highway": "11",
    "Enum.Font.SciFi": "12", "Enum.Font.Arcade": "13",
    "Enum.Font.Fantasy": "14", "Enum.Font.Antique": "15",
    "Enum.Font.Gotham": "17", "Enum.Font.GothamMedium": "18",
    "Enum.Font.GothamBold": "19", "Enum.Font.GothamBlack": "20",
    "Enum.Font.FredokaOne": "21", "Enum.Font.Ubuntu": "22",
    "Enum.Font.TitilliumWeb": "23", "Enum.Font.Fondamento": "24",
    "Enum.Font.Merriweather": "25", "Enum.Font.Michroma": "26",
    "Enum.Font.Nunito": "27", "Enum.Font.Oswald": "28",
    "Enum.Font.PatrickHand": "29", "Enum.Font.PermanentMarker": "30",
    "Enum.Font.Roboto": "31", "Enum.Font.RobotoCondensed": "32",
    "Enum.Font.RobotoMono": "33", "Enum.Font.SpecialElite": "34",
    "Enum.Font.BuilderSans": "35", "Enum.Font.BuilderSansMedium": "36",
    "Enum.Font.BuilderSansBold": "37", "Enum.Font.BuilderSansExtraBold": "38",
}

ENUM_TOKEN_MAP = {
    "Material": MATERIAL_MAP,
    "Font": FONT_MAP,
}

BOOL_PROPS = {"Anchored","CanCollide","Transparency","Visible","Enabled","Disabled",
    "TextScaled","TextWrapped","RichText","ClipsDescendants","Active","Selectable",
    "ResetOnSpawn","IgnoreGuiInset","AutoButtonColor","Modal","CastShadow",
    "CanQuery","Massless","GlobalShadows","Shadows","LockedToPart","Looped","Playing"}

def write_prop(props_el, name, pdata):
    if pdata is None: return
    t = pdata.get("type")
    v = pdata.get("value")
    if v is None: return

    if t == "string":
        if name == "Source":
            el = ET.SubElement(props_el, "ProtectedString", name=name)
        else:
            el = ET.SubElement(props_el, "string", name=name)
        el.text = str(v)

    elif t == "number":
        el = ET.SubElement(props_el, "float", name=name)
        el.text = str(v)

    elif t == "boolean" or name in BOOL_PROPS:
        el = ET.SubElement(props_el, "bool", name=name)
        el.text = str(v).lower() if isinstance(v, bool) else str(v)

    elif t == "Vector3":
        vel = ET.SubElement(props_el, "Vector3", name=name)
        ET.SubElement(vel, "X").text = str(v[0])
        ET.SubElement(vel, "Y").text = str(v[1])
        ET.SubElement(vel, "Z").text = str(v[2])

    elif t == "Vector2":
        vel = ET.SubElement(props_el, "Vector2", name=name)
        ET.SubElement(vel, "X").text = str(v[0])
        ET.SubElement(vel, "Y").text = str(v[1])

    elif t == "CFrame":
        if name == "Position" and len(v) >= 3:
            cf = ET.SubElement(props_el, "CoordinateFrame", name="CFrame")
            ET.SubElement(cf, "X").text = str(v[0])
            ET.SubElement(cf, "Y").text = str(v[1])
            ET.SubElement(cf, "Z").text = str(v[2])
            rot = ["R00","R01","R02","R10","R11","R12","R20","R21","R22"]
            for i, rn in enumerate(rot):
                ET.SubElement(cf, rn).text = str(v[3+i]) if len(v) > 3+i else ("1" if i%4==0 else "0")
        else:
            cf = ET.SubElement(props_el, "CoordinateFrame", name=name)
            ET.SubElement(cf, "X").text = str(v[0]) if len(v)>0 else "0"
            ET.SubElement(cf, "Y").text = str(v[1]) if len(v)>1 else "0"
            ET.SubElement(cf, "Z").text = str(v[2]) if len(v)>2 else "0"
            rot = ["R00","R01","R02","R10","R11","R12","R20","R21","R22"]
            for i, rn in enumerate(rot):
                ET.SubElement(cf, rn).text = str(v[3+i]) if len(v) > 3+i else ("1" if i%4==0 else "0")

    elif t == "Color3":
        r, g, b = int(v[0]*255), int(v[1]*255), int(v[2]*255)
        el = ET.SubElement(props_el, "Color3uint8", name=name)
        el.text = str((r<<16)|(g<<8)|b)

    elif t == "BrickColor":
        el = ET.SubElement(props_el, "int", name=name)
        el.text = str(v) if isinstance(v, int) else "194"

    elif t == "UDim2":
        ud = ET.SubElement(props_el, "UDim2", name=name)
        xs = ET.SubElement(ud, "XS"); xs.text = str(v[0])
        xo = ET.SubElement(ud, "XO"); xo.text = str(int(v[1]))
        ys = ET.SubElement(ud, "YS"); ys.text = str(v[2])
        yo = ET.SubElement(ud, "YO"); yo.text = str(int(v[3]))

    elif t == "UDim":
        ud = ET.SubElement(props_el, "UDim", name=name)
        ET.SubElement(ud, "S").text = str(v[0])
        ET.SubElement(ud, "O").text = str(int(v[1]))

    elif t == "Rect":
        r = ET.SubElement(props_el, "Rect2D", name=name)
        mn = ET.SubElement(r, "min")
        ET.SubElement(mn, "X").text = str(v[0])
        ET.SubElement(mn, "Y").text = str(v[1])
        mx = ET.SubElement(r, "max")
        ET.SubElement(mx, "X").text = str(v[2])
        ET.SubElement(mx, "Y").text = str(v[3])

    elif t == "Enum":
        s = str(v)
        for prop_name, mapping in ENUM_TOKEN_MAP.items():
            if name == prop_name and s in mapping:
                el = ET.SubElement(props_el, "token", name=name)
                el.text = mapping[s]
                return
        el = ET.SubElement(props_el, "token", name=name)
        parts = s.split(".")
        el.text = parts[-1] if parts else s

    elif t == "NumberSequence":
        el = ET.SubElement(props_el, "NumberSequence", name=name)
        parts = []
        for kp in v:
            parts.append(f"{kp[0]} {kp[1]} {kp[2]}")
        el.text = " ".join(parts)

    elif t == "ColorSequence":
        el = ET.SubElement(props_el, "ColorSequence", name=name)
        parts = []
        for kp in v:
            parts.append(f"{kp[0]} {kp[1]} {kp[2]} {kp[3]} 0")
        el.text = " ".join(parts)

    elif t == "NumberRange":
        el = ET.SubElement(props_el, "NumberRange", name=name)
        el.text = f"{v[0]} {v[1]}"

def serialize_node(parent_xml, node):
    cn = node.get("ClassName", "Folder")
    item = ET.SubElement(parent_xml, "Item", {"class": cn, "referent": ref()})
    props_el = ET.SubElement(item, "Properties")

    node_props = node.get("Properties", {})
    if not node_props:
        node_props = {}
        if "Name" in node: node_props["Name"] = {"type":"string","value":node["Name"]}
        for k in ("Position","Size","Anchored","CanCollide","Transparency","Color","Material","Source"):
            if k in node:
                v = node[k]
                if isinstance(v, list):
                    node_props[k] = {"type":"Vector3","value":v}
                elif isinstance(v, bool):
                    node_props[k] = {"type":"boolean","value":v}
                elif isinstance(v, str):
                    node_props[k] = {"type":"string","value":v}
                else:
                    node_props[k] = {"type":"number","value":v}

    for pname, pdata in node_props.items():
        write_prop(props_el, pname, pdata)

    for child in node.get("Children", []):
        serialize_node(item, child)

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
    jf = sys.argv[1]
    of = sys.argv[2] if len(sys.argv) > 2 else jf.replace(".json", ".rbxlx")
    convert(jf, of)
