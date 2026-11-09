# The World Plan bounds depth, and the place's Destroy Height lies below it

Roblox removes anything that falls below a place's Destroy Height, -500 in a new place, measured on 2026-11-08. The developer wants Oceans 800 to 1,200 studs deep, Trenches and Caverns down to 3,500, so a character on such a bed would be removed. On 2026-11-08, for #77, they chose their standard: nothing the Generator makes goes below -3,500, and their places remove what falls below -4,000, which leaves 500 studs of margin.

So the World Plan holds a Depth Limit, -3,500 when it leaves it out, and validation refuses any Ocean, Lake, River or Cave that may reach below it, working each depth out from the plan alone, with every asked depth as a ceiling, as ADR 0010 does, deepened by the most its pools and roughness can add. The World Plan may also declare the place's Destroy Height, which must lie below its Depth Limit. `run` and `generate` set a declared one in the place before writing. A world that declares none leaves the place's own value, and writes nothing when it goes deeper than that value.

A write clears its Chunk down to the Depth Limit, since that is the deepest any earlier plan may have taken it. Before, it cleared down to -256, which left the bed and water of a deeper earlier write hidden under the new one, seen on 2026-11-08.

## Considered Options

- Raising the whole map so that sea level sits near 4,000 and every bed stays above Roblox's -500. Rejected: every height of every plan and test moves, the gap to the Destroy Height is the same thing reached the other way, a check that a plan goes no deeper than allowed is still needed, and so is the clearing.
- Recording, for each Chunk, the lowest height its last write reached, and clearing down to that. Rejected: clearing 3,200 studs of empty space under a Chunk cost nothing measurable and clearing 3,200 studs of rock took 0.14 s, measured on 2026-11-08, so always clearing down to the Depth Limit costs the same where it matters and needs no record and no case for older Chunks.
- Leaving the Destroy Height to the developer's Properties window alone. Rejected: a setting of the game would live only in a Studio window, and nothing would catch a new place left at -500.

## Consequences

The Destroy Height changes in the place only, so it lasts once the developer saves the place. A fall off the edge of the world lasts longer before the body is removed, about 6.4 s to -4,000 against 2.3 s to -500 at Roblox's default gravity, calculated and not measured. What a game does about that belongs to its World Limit. `scale` leaves both values as they are, since they belong to the place.
