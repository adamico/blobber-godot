# The Sweep — Minimum Asset List

## Environment (Tileable textures)
| Asset | Variants |
|---|---|
| Wall | 1 base |
| Floor | 1 base |
| Ceiling | solid color, no texture needed |
| Door | open + closed = 2 |

## Item Billboards
| Asset | Properties |
|---|---|
| Corpse | flammable, heavy |
| Fire Flask | volatile, flammable |
| Potion Spill | wet, corrosive |
| Cursed Chest | cursed, heavy |
| Ash | inert |
| Sludge | wet, heavy |

6 sprites cover all items including the two transform results (ash, sludge). No additional sprites needed when reactions fire — you're swapping billboards.

## Receptacle Billboards
| Asset |
|---|
| Disposal Chute |
| Smelter |
| Ritual Altar |

## UI
| Asset |
|---|
| Inventory slot frame (tiled 3x) |
| Clean% counter (text only, no sprite) |
| Crosshair |

---

## Total
- 4 environment textures (3 + ceiling skipped)
- 6 item billboards
- 3 receptacle billboards
- 3 UI elements

**16 assets.** Achievable in day 4 with simple pixel art or even placeholder shapes replaced late.