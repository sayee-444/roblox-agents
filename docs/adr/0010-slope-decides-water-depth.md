# The slope decides how deep water gets

A River's whole declared depth used to fit inside its half width, so `lab`'s Rivers, 100 to 120 studs wide and 60 to 90 deep, fell about 44 studs in 20 under a flat Shore, measured on 2026-11-07, and the developer saw a trench full of water. In nature the ground keeps the slope it came down with under the water, so a River in a plain is shallow and deep water needs steep ground around it. The developer chose on 2026-11-07 that the slope decides: the ground falls from a valley's edge through the Shore and under the water as one curve, how steep a Valley Side is sets how deep its River gets, a Lake's bed follows the ground around it, and a depth in the World Plan is the most the water can reach, with `heights` reporting the depth reached. This narrows ADR 0002 for depth alone: the World Plan still wins over the seeds, and its depth is a ceiling the shape may not reach.

## Considered Options

- Keep the exact depth and widen the water until it fits. Rejected, because Rivers would become much wider than the plan draws them.
- Keep the exact depth inside the declared width. Rejected, because it is the wall the developer called horrible.

## Consequences

A plan that asks for deep water in a gentle valley gets shallow water, so the agent must read the reached depth from `heights` and not from the plan. Worlds whose Rivers and Lakes have no `banks` keep their old shape.
