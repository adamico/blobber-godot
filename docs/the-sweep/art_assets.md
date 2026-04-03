# The Sweep — Art Assets

Sprite and palette mapping for all five floors. All paths are `res://` relative.

---

## Core Hazard Art

| Role | Sprite | Tag |
|---|---|---|
| Burning reanimated NPC | `assets/monster/undead/zombies/zombie_small.png` | `burning` |
| Thermal overspill | `assets/monster/nonliving/fire_vortex_1.png` | `burning` |
| Cursed combat prop | `assets/monster/statues/spooky_statue.png` | `cursed` |
| Acid crawler | `assets/monster/amorphous/acid_blob.png` | `corrosive` |
| Trap module (hot) | `assets/dungeon/traps/trap_magical.png` | `burning` |

---

## Floor-by-Floor Sprite Set

### Floor 1 — Industrial neutral

Theme: training-cleanup, grounded maintenance look.

| Node type | File |
|---|---|
| Enemy | `assets/monster/undead/zombies/zombie_small.png` |
| Floor tile | `assets/dungeon/floor/labyrinth_0.png` |
| Wall | `assets/dungeon/wall/lab-metal_0.png` |
| Door | `assets/dungeon/doors/closed_door.png` |
| Exit | `assets/dungeon/gateways/stone_stairs_up.png` |

### Floor 2 — Thermal aftermath

Theme: broadcast wreckage, heat and spill.

| Node type | File |
|---|---|
| Enemy | `assets/monster/nonliving/fire_vortex_1.png` |
| Floor tile | `assets/dungeon/floor/volcanic_floor_2.png` |
| Hazard prop | `assets/dungeon/traps/trap_magical.png` |
| Wall accent | `assets/dungeon/wall/torches/torch_3.png` |
| Exit | `assets/dungeon/gateways/escape_hatch_up.png` |

### Floor 3 — Cursed routing

Theme: debris pressure and cursed pathing.

| Node type | File |
|---|---|
| Enemy | `assets/monster/statues/spooky_statue.png` |
| Floor tile | `assets/dungeon/floor/sigils/cross.png` |
| Landmark prop | `assets/dungeon/statues/statue_wraith.png` |
| Door | `assets/dungeon/doors/runed_door.png` |
| Exit | `assets/dungeon/gateways/exit.png` |

### Floor 4 — Corrosive systems

Theme: acid and retrofuturist machinery.

| Node type | File |
|---|---|
| Enemy | `assets/monster/amorphous/acid_blob.png` |
| Floor tile | `assets/dungeon/floor/acidic_floor_2.png` |
| Tech prop | `assets/dungeon/vaults/machine_tukima.png` |
| Secondary trap | `assets/dungeon/traps/trap_mechanical.png` |
| Exit | `assets/dungeon/gateways/return_depths.png` |

### Floor 5 — Dragon finale

Theme: dragon-forward, full-system pressure.

| Node type | File |
|---|---|
| Enemy (primary) | `assets/monster/dragons/steam_dragon.png` |
| Enemy (elite) | `assets/monster/dragons/iron_dragon.png` |
| Monument prop | `assets/dungeon/statues/statue_dragon.png` |
| Floor tile | `assets/dungeon/floor/volcanic_floor_6.png` |
| Exit | `assets/dungeon/gateways/starry_portal.png` |

---

## Shared / Optional Props

| Role | File |
|---|---|
| Biohazard spill overlay | `assets/dungeon/water/ink_full.png` |
| Disposal chute stand-in | `assets/dungeon/vaults/grate.png` |
| Alternate hot trap | `assets/dungeon/traps/trap_zot.png` |
| Crumbling wall variant | `assets/dungeon/wall/metal_wall_cracked.png` |

---

## Palette Ramp

Apply `albedo_color` to each floor's `StandardMaterial3D` and `DirectionalLight3D.light_color`.  
Sprite3D nodes on that floor should also carry the same modulate color.

| Floor | Theme | `albedo_color` | `DirectionalLight3D` | Notes |
|---|---|---|---|---|
| F1 | Industrial neutral | `#C8D0CC` | `#D6E0DA` | Desaturated cool-grey; maintenance-corridor read |
| F2 | Thermal aftermath | `#F0B060` | `#FFD080` | Amber; fire vortex and trap sprites glow naturally |
| F3 | Cursed routing | `#9080B8` | `#C0A8E0` | Muted violet; makes sigils and wraith pop |
| F4 | Corrosive systems | `#90B840` | `#B0D060` | Acid-lime; anchors acid-blob and machine props |
| F5 | Dragon finale | `#C04828` | `#FF8040` | Deep ember; turns dragons dramatic |

---

## Sprite3D Baseline Settings

Apply to every enemy and hazard billboard unless noted:

```
pixel_size   = 0.004
billboard    = 1          # BaseMaterial3D.BILLBOARD_ENABLED
alpha_cut    = 1          # ALPHA_CUT_DISCARD
axis_aligned = false
```

Dragon sprites (F5): `scale = Vector3(1.5, 1.5, 1.5)`.

---

## Scene Placement Notes

- **Hostiles** — inherited scenes from `scenes/hostiles/hostile.tscn`. Replace `MeshInstance3D/CapsuleMesh` child with `Sprite3D`.
- **Hazards** — inherited scenes from `scenes/hostiles/hazard.tscn`. Same swap.
- **World props** (torches, statues) — `MeshInstance3D` with `QuadMesh` size `Vector2(0.8, 0.8)` + `StandardMaterial3D`, billboard on, placed at world cells in `scenes/world/main.tscn`.
- **Floor textures** — one `StandardMaterial3D .tres` per floor in `resources/mesh_library/`, referenced by the floor's `GridMap` cell material.
- **Exit markers** — add `Sprite3D` billboard child to the `WorldExit` node, swap texture per floor table above.
