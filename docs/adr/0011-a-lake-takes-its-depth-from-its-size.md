# A Lake takes its depth from its size

Every Lake used to give `bedY`, and the developer wanted a large Lake to get a fitting depth without choosing a number each time. On 2026-11-08, for #64, they chose this rule for a Lake with `banks` that leaves `bedY` out. The deepest it may reach is a quarter of its radius up to radius 425. That is the size of `lab`'s Lake, which reached 110 studs, about a quarter of its radius, as measured with `heights`. Past 425 it grows as the natural log of the radius, joining with no break, so a very large Lake gets deeper ever more slowly. It stops at a cap of 220 studs, twice that Lake's depth, which the World Plan changes or removes with `depthCap`. The pools and shallows then default to `depthVary` 0.4, as on `lab`. On steep ground the whole bed reaches that ceiling and comes out flat, so for a depth from size the pools also lower the ceiling where they make their shallows, and their deepest zones keep it. A Lake that gives `bedY` keeps its old shape, and a Lake without `banks` still needs `bedY`, since no slope there limits the depth. Per ADR 0010, this depth is still a ceiling, and the slope of the ground around the Lake decides what it reaches.

## Considered Options

- A quarter of the radius at every size. Rejected, because a very long Lake would get very deep.
- `64 · ln(1 + radius / 100)` at every size. Rejected, because it makes small Lakes deeper than a quarter of their radius.
- Measuring the short side, `radius / elongate`. Not taken: `elongate` stretches one axis and shrinks the other by the same factor, so the radius already stands for the area, and a long Lake is as deep as a round one of the same area.

## Consequences

`scale` multiplies `bedY` and `depthCap` but not this curve, so a scaled Lake that takes its depth from its size does not get exactly scaled depths past radius 425.
