# Breaker Zone Setup

Setiap lane memiliki satu model `BreakerZone` sendiri. Posisi zone boleh berbeda antar-lane, tetapi zone dengan `EncounterId` yang sama harus memiliki jumlah dan pola jarak obstacle yang setara.

```text
BreakerZones
└─ TireRush_Lane01 [Model] # tag: BreakerZone
   ├─ ActivationPart [Part]
   ├─ Obstacles [Folder]
   │  ├─ Tire01 [Model] # tag: BreakerObstacle
   │  │  ├─ Visual parts...
   │  │  └─ ImpactPart [Part]
   │  ├─ Tire02 [Model] # tag: BreakerObstacle
   │  │  └─ ImpactPart [Part]
   │  └─ Tire03 [Model] # tag: BreakerObstacle
   │     └─ ImpactPart [Part]
   └─ EndPart [Part]
```

## BreakerZone attributes

| Attribute | Type | Example | Purpose |
| --- | --- | --- | --- |
| `LaneIndex` | number | `1` | Lane owner. Must match the spawn and MoveTarget lane. |
| `EncounterId` | string | `"TireRush01"` | Connects equivalent zones across lanes. |
| `ZoneOrder` | number | `1` | Authoring order when a lane contains several zones. |
| `ZoneId` | string | `"TireRush_Lane01"` | Optional stable identifier; model name is the fallback. |

## BreakerObstacle attributes

| Attribute | Type | Example | Purpose |
| --- | --- | --- | --- |
| `ObstacleIndex` | number | `1` | Required sequential index, starting at 1. |
| `ObstacleId` | string | `"Tire01"` | Optional stable identifier; instance name is the fallback. |
| `ThrowSide` | number | `1` or `-1` | Optional direction for debris. Defaults to alternating sides. |

The number of visual tyre meshes is unrestricted. A model containing three tyres and a model containing seven tyres are both supported; every BasePart/MeshPart descendant becomes independent local debris at impact. The current prototype always uses one tap per `BreakerObstacle`.

`ImpactPart` is the gameplay marker, not necessarily the visible mesh. Place it at the center of the collision moment. Recommended properties:

```text
Transparency = 1
CanCollide = false
CanTouch = false
CanQuery = true
```

Use the same marker properties for `ActivationPart` and `EndPart`. Every visual part of a Breaker obstacle is forced non-collidable at runtime.

## Recommended prototype measurements

- ActivationPart to first ImpactPart: 45–55 studs.
- ImpactPart to ImpactPart: 24–28 studs.
- Last ImpactPart to EndPart: 10–15 studs.
- Five obstacles per zone.
- Difference in the same gap across lanes: at most 2 studs.

The system warns in Output when markers are missing, indices are invalid, an encounter is missing from a lane, obstacle counts differ, or spacing differs beyond the configured tolerance.

## Runtime behavior

1. Crossing `ActivationPart` pauses normal prompts and pauses the remaining On Fire duration.
2. One Breaker prompt is scheduled from each obstacle's distance and the racer's current effective speed.
3. The tap must be `Good` or `Perfect` to preserve the Breaker chain and destroy that obstacle.
4. `Early` and `Miss` break the chain. The obstacle still scatters, but the character falls at impact.
5. Crossing `EndPart` disables Breaker, restores the paused On Fire duration, and resumes normal prompts.
