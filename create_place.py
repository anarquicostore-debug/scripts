#!/usr/bin/env python3 -I
"""
Gera um arquivo .rbxlx (Roblox place XML) com:
- Baseplate (chão)
- SpawnLocation
- Script de boas-vindas no ServerScriptService
- Lighting configurado

Uso: python3 create_place.py [nome_do_arquivo]
Abre o .rbxlx gerado no Roblox Studio.
"""

import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom

def prop(parent, tag, name, value):
    el = ET.SubElement(parent, tag, name=name)
    el.text = str(value)
    return el

def vector3(parent, name, x, y, z):
    v = ET.SubElement(parent, "Vector3", name=name)
    ET.SubElement(v, "X").text = str(x)
    ET.SubElement(v, "Y").text = str(y)
    ET.SubElement(v, "Z").text = str(z)

def color3(parent, name, r, g, b):
    c = ET.SubElement(parent, "Color3uint8", name=name)
    c.text = str((r << 16) | (g << 8) | b)

def cframe(parent, name, x, y, z):
    cf = ET.SubElement(parent, "CoordinateFrame", name=name)
    ET.SubElement(cf, "X").text = str(x)
    ET.SubElement(cf, "Y").text = str(y)
    ET.SubElement(cf, "Z").text = str(z)
    ET.SubElement(cf, "R00").text = "1"
    ET.SubElement(cf, "R01").text = "0"
    ET.SubElement(cf, "R02").text = "0"
    ET.SubElement(cf, "R10").text = "0"
    ET.SubElement(cf, "R11").text = "1"
    ET.SubElement(cf, "R12").text = "0"
    ET.SubElement(cf, "R20").text = "0"
    ET.SubElement(cf, "R21").text = "0"
    ET.SubElement(cf, "R22").text = "1"

def create_part(parent, class_name, name, x, y, z, sx, sy, sz, anchored=True, **extra):
    item = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{name}"})
    props = ET.SubElement(item, "Properties")
    prop(props, "string", "Name", name)
    prop(props, "bool", "Anchored", str(anchored).lower())
    vector3(props, "size", sx, sy, sz)
    cframe(props, "CFrame", x, y, z)
    if "color" in extra:
        r, g, b = extra["color"]
        color3(props, "Color3uint8", r, g, b)
    if "material" in extra:
        prop(props, "token", "Material", extra["material"])
    if "transparency" in extra:
        prop(props, "float", "Transparency", extra["transparency"])
    return item

def create_script(parent, name, source, class_name="Script"):
    item = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{name}"})
    props = ET.SubElement(item, "Properties")
    prop(props, "string", "Name", name)
    src = ET.SubElement(props, "ProtectedString", name="Source")
    src.text = source
    return item

def build_place():
    root = ET.Element("roblox", {
        "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime",
        "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
        "version": "4",
    })

    # Workspace
    workspace = ET.SubElement(root, "Item", {"class": "Workspace", "referent": "RBXWorkspace"})
    ws_props = ET.SubElement(workspace, "Properties")
    prop(ws_props, "string", "Name", "Workspace")

    # Baseplate
    create_part(workspace, "Part", "Baseplate",
                0, -0.5, 0, 512, 1, 512,
                color=(91, 154, 76), material="880")

    # SpawnLocation
    create_part(workspace, "SpawnLocation", "SpawnLocation",
                0, 1, 0, 6, 1, 6,
                color=(100, 100, 100))

    # Lighting
    lighting = ET.SubElement(root, "Item", {"class": "Lighting", "referent": "RBXLighting"})
    l_props = ET.SubElement(lighting, "Properties")
    prop(l_props, "string", "Name", "Lighting")
    prop(l_props, "string", "TimeOfDay", "14:00:00")
    prop(l_props, "float", "Brightness", "2")

    # ServerScriptService
    sss = ET.SubElement(root, "Item", {"class": "ServerScriptService", "referent": "RBXSSS"})
    sss_props = ET.SubElement(sss, "Properties")
    prop(sss_props, "string", "Name", "ServerScriptService")

    game_script = '''\
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("Bem-vindo, " .. player.Name .. "!")

    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.WalkSpeed = 20
        humanoid.JumpHeight = 10

        -- Dar uma ferramenta ao jogador
        local tool = Instance.new("Tool")
        tool.Name = "Espada"
        tool.RequiresHandle = false
        tool.Parent = player.Backpack
    end)
end)

print("Servidor iniciado!")
'''
    create_script(sss, "GameScript", game_script)

    # StarterGui
    starter_gui = ET.SubElement(root, "Item", {"class": "StarterGui", "referent": "RBXStarterGui"})
    sg_props = ET.SubElement(starter_gui, "Properties")
    prop(sg_props, "string", "Name", "StarterGui")

    gui_script = '''\
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Parent = player.PlayerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.3, 0, 0.05, 0)
label.Position = UDim2.new(0.35, 0, 0.02, 0)
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Text = "Bem-vindo ao Jogo!"
label.Parent = gui

task.delay(5, function()
    label:Destroy()
end)
'''
    create_script(starter_gui, "WelcomeGui", gui_script, "LocalScript")

    # ReplicatedStorage
    rs = ET.SubElement(root, "Item", {"class": "ReplicatedStorage", "referent": "RBXReplicatedStorage"})
    rs_props = ET.SubElement(rs, "Properties")
    prop(rs_props, "string", "Name", "ReplicatedStorage")

    # StarterPlayer
    sp = ET.SubElement(root, "Item", {"class": "StarterPlayer", "referent": "RBXStarterPlayer"})
    sp_props = ET.SubElement(sp, "Properties")
    prop(sp_props, "string", "Name", "StarterPlayer")

    return root

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else "MeuJogo.rbxlx"
    if not filename.endswith(".rbxlx"):
        filename += ".rbxlx"

    root = build_place()
    rough = ET.tostring(root, encoding="unicode", xml_declaration=False)
    parsed = minidom.parseString(rough)
    pretty = parsed.toprettyxml(indent="  ", encoding="utf-8")

    with open(filename, "wb") as f:
        f.write(pretty)

    print(f"Arquivo criado: {filename}")
    print("Abra no Roblox Studio para jogar!")

if __name__ == "__main__":
    main()
