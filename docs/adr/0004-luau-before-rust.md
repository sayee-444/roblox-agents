# The Generator is written in Luau before any Rust

The Generator is pure Luau, even with Rust and a powerful GPU available, because no official way to run Rust on Roblox servers was found and the final terrain write stays serial in Studio either way. Rust would add speed, not capability, and estimates suggest only iterated erosion needs it. Those figures are unmeasured, so the Generator returns Chunk data for the Studio writer to write, and that boundary is where Rust can be added if a measurement justifies it.
