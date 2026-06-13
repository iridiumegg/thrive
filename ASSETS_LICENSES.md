# Asset License Log

Every external asset used by this project must be recorded here with its
source, license, and required attribution **before** it lands in the repo.
Acceptable licenses: CC0, CC-BY (with attribution), or original work.

## Current assets

| Asset | Source | License | Attribution |
|-------|--------|---------|-------------|
| Terrain tile atlas | Generated procedurally at runtime (`game/world/world.gd`) | Original (this project) | — |
| Player sprite | Generated procedurally at runtime (`game/world/world.gd`) | Original (this project) | — |
| Item icons | Generated procedurally at runtime (`game/ui/item_icons.gd`) | Original (this project) | — |
| Resource node sprites | Generated procedurally at runtime (`game/entities/resource_node_entity.gd`) | Original (this project) | — |
| Trap sprites | Generated procedurally at runtime (`game/entities/trap_entity.gd`) | Original (this project) | — |
| Structure sprites | Generated procedurally at runtime (`game/entities/building_entity.gd`) | Original (this project) | — |
| NPC sprites | Generated procedurally at runtime (`game/entities/npc_entity.gd`) | Original (this project) | — |
| Wildlife sprites | Generated procedurally at runtime (`game/entities/wildlife_entity.gd`) | Original (this project) | — |

| Sound effects & wind bed | Synthesised at runtime (`game/core/audio_service.gd`) | Original (this project) | — |

No external art, audio, or font assets are currently used. All sound is
generated as PCM buffers at runtime; UI text rendering uses Godot's built-in
default theme font.
