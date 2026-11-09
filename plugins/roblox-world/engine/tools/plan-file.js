// Reads and rewrites a World Plan as text, so that a command can answer about it or change it with no
// Studio and no model writing it. Pure: text in, text and facts out.

const SECTIONS = ['regions', 'rivers', 'lakes', 'oceans'];

// Lengths and heights, each multiplied by a scale. Slopes, ratios, angles, counts and seeds stay as they
// are, and so does `rockUnder`, the thickness of a wall of rock whatever the map's size.
const LENGTHS = [
  'mean', 'amp', 'scale', 'warpScale', 'warpAmp',
  'halfWidth', 'height', 'ridgeScale', 'crestScale',
  'radius', 'margin', 'warp', 'gully', 'shore',
  'meander', 'bedY', 'bedRough', 'depthCap', 'rough', 'smooth',
  'clearBottom', 'clearTop',
  'snowLine', 'snowBlend', 'rockLine', 'bankDist', 'bankHeight', 'bedSand', 'bedDeep',
];
const ON_THE_GRID = ['floorY', 'waterLevel']; // Validation wants these on the voxel grid.
const LISTS = ['widths', 'depths', 'floors'];
const DEPTH_LIMIT = -3500; // The Depth Limit of a plan that declares none, as the Generator's Shape takes it.
const LIMITS = { smooth: 100 }; // The most validation accepts.
const VOXEL = 4;
const NUMBER = /-?\d+(?:\.\d+)?/g;
const FIELD_START = '(?<=^|[\\s,{])';

// The text with comments blanked out, at the same positions, so that positions found in it fit the original.
function withoutComments(text) {
  let out = '';
  let inString = false;
  for (let at = 0; at < text.length; at += 1) {
    const char = text[at];
    if (inString) {
      inString = char !== '"';
      out += char;
    } else if (char === '"') {
      inString = true;
      out += char;
    } else if (text.startsWith('--', at)) {
      const end = text.indexOf('\n', at);
      const stop = end < 0 ? text.length : end;
      out += ' '.repeat(stop - at);
      at = stop - 1;
    } else {
      out += char;
    }
  }
  return out;
}

// Where the brace opened at `open` closes.
function closing(code, open) {
  let depth = 0;
  for (let at = open; at < code.length; at += 1) {
    if (code[at] === '{') depth += 1;
    if (code[at] === '}') {
      depth -= 1;
      if (depth === 0) return at;
    }
  }
  throw new Error('The World Plan has a brace that never closes');
}

function sectionRange(code, name) {
  const found = new RegExp(`^[ \\t]*${name}[ \\t]*=[ \\t]*\\{`, 'm').exec(code);
  if (!found) return null;
  const open = found.index + found[0].length - 1;
  return { name, open, close: closing(code, open) };
}

// Each table in a section's list, with its position.
function entries(code, range) {
  const found = [];
  let at = range.open + 1;
  while (at < range.close) {
    if (code[at] === '{') {
      const end = closing(code, at);
      found.push({ start: at, end, source: code.slice(at, end + 1) });
      at = end;
    }
    at += 1;
  }
  return found;
}

const textField = (source, name) => {
  const match = new RegExp(`${FIELD_START}${name}\\s*=\\s*"([^"]*)"`, 'm').exec(source);
  return match ? match[1] : undefined;
};

const numberField = (code, name) => {
  const match = new RegExp(`${FIELD_START}${name}\\s*=\\s*(-?[\\d.]+)`, 'm').exec(code);
  return match ? Number(match[1]) : undefined;
};

function extentOf(code) {
  const match = /extent\s*=\s*\{([^}]*)\}/.exec(code);
  if (!match) return null;
  const read = (name) => numberField(match[1], name);
  return { minX: read('minX'), maxX: read('maxX'), minZ: read('minZ'), maxZ: read('maxZ') };
}

// What the plan declares: its seed, extent and everything placed on the map.
function facts(text) {
  const code = withoutComments(text);
  const things = {};
  for (const name of SECTIONS) {
    const range = sectionRange(code, name);
    things[name] = range ? entries(code, range).map((entry) => ({ id: textField(entry.source, 'id'), kind: textField(entry.source, 'kind') })) : [];
  }
  const extent = extentOf(code);
  const chunks = extent ? (extent.maxX - extent.minX + 1) * (extent.maxZ - extent.minZ + 1) : 0;
  return { seed: numberField(code, 'worldSeed'), extent, chunks, ...things };
}

// The Chunks recorded in a generation state file.
function stateFacts(text) {
  const generated = [];
  const locked = [];
  for (const [, key, body] of withoutComments(text).matchAll(/\["([^"]+)"\]\s*=\s*\{([^}]*)\}/g)) {
    if (/generated\s*=\s*true/.test(body)) generated.push(key);
    if (/locked\s*=\s*true/.test(body)) locked.push(key);
  }
  return { generated, locked };
}

// An entry with what makes it a block of its own: its indentation, its comma and the rest of its line.
function blockAt(text, entry) {
  let start = entry.start;
  while (start > 0 && (text[start - 1] === ' ' || text[start - 1] === '\t')) start -= 1;
  if (start > 0 && text[start - 1] !== '\n') start = entry.start;
  let end = entry.end + 1;
  if (text[end] === ',') end += 1;
  const lineEnd = text.indexOf('\n', end);
  const stop = lineEnd < 0 ? text.length : lineEnd;
  if (/^\s*(--.*)?$/.test(text.slice(end, stop))) end = lineEnd < 0 ? text.length : lineEnd + 1;
  return { start, end };
}

// The words the glossary capitalises.
const KIND_NAMES = { river: 'River', lake: 'Lake', ocean: 'Ocean', trench: 'Trench' };

// Takes `id` out of the plan. A River and its valley go together, since only a valley carves a River into
// the ground, so naming either takes both. Returns the new text and what was taken, `id` first, each with
// its list and exact text. Throws when the plan has no such thing.
function remove(text, id) {
  const code = withoutComments(text);
  const blocks = SECTIONS.flatMap((name) => {
    const range = sectionRange(code, name);
    return (range ? entries(code, range) : []).map((entry) => ({
      section: name,
      entry,
      id: textField(entry.source, 'id'),
      riverId: textField(entry.source, 'riverId'),
      kind: textField(entry.source, 'kind') || name.replace(/s$/, ''),
    }));
  });
  const named = blocks.find((block) => block.id === id);
  if (!named) throw new Error(`The World Plan has no "${id}". It holds: ${blocks.map((block) => block.id).join(' ')}`);
  const river = named.riverId || id;
  const taken = blocks
    .filter((block) => block.id === id || block.id === river || block.riverId === river)
    .map((block) => {
      const { start, end } = blockAt(text, block.entry);
      return { section: block.section, id: block.id, kind: KIND_NAMES[block.kind] || block.kind, start, end, text: text.slice(start, end) };
    })
    .sort((a, b) => (b.id === id) - (a.id === id));
  let out = text;
  for (const block of [...taken].sort((a, b) => b.start - a.start)) out = out.slice(0, block.start) + out.slice(block.end);
  for (const name of SECTIONS) out = out.replace(new RegExp(`^([ \\t]*${name}[ \\t]*=[ \\t]*)\\{\\s*\\}`, 'm'), '$1{}');
  return { text: out, taken };
}

// A history entry for what was taken out of the plan, holding it exactly, so restoring it needs no Git.
function removalEntry({ date, why, taken, written, unwritten, locked }) {
  const names = taken.map((block) => `${block.kind} \`${block.id}\``).join(' and ');
  const blocks = taken.map((block) => `Into \`${block.section}\`:\n\n\`\`\`luau\n${block.text.trimEnd()}\n\`\`\``).join('\n\n');
  const lines = [
    `- **Why:** ${why}`,
    `- **Chunks written:** ${written.join(' ') || 'none'}`,
    ...(unwritten.length ? [`- **Chunks not written:** ${unwritten.join(' ')}, since Studio stopped answering`] : []),
    ...(locked.length ? [`- **Locked Chunks it reached, not written:** ${locked.join(' ')}`] : []),
    '- **Restore:** paste each block below into its list in the World Plan, and generate those Chunks again.',
  ];
  return `## ${date}: Removed ${names}\n\n${lines.join('\n')}\n\n${blocks}\n`;
}

const round2 = (value) => Math.round(value * 100) / 100;

// New Chunk indices for one axis: as many Chunks as hold the scaled span, around the same centre.
function scaleAxis(min, max, factor) {
  const count = Math.max(1, Math.ceil((max - min + 1) * factor - 1e-9));
  const centre = (min + max) / 2;
  const newMin = Math.round(centre - (count - 1) / 2);
  return { min: newMin, max: newMin + count - 1, centre, newCentre: newMin + (count - 1) / 2 };
}

// The comments that hold a number, which described the plan at its old size. What a Chunk covers stays true.
function staleComments(text) {
  const edits = [];
  let inString = false;
  for (let at = 0; at < text.length; at += 1) {
    if (text[at] === '"') inString = !inString;
    if (!inString && text.startsWith('--', at)) {
      const end = text.indexOf('\n', at);
      const stop = end < 0 ? text.length : end;
      if (/\d/.test(text.slice(at, stop)) && !text.startsWith('-- Chunk (i, j) covers', at)) {
        let start = at;
        while (start > 0 && (text[start - 1] === ' ' || text[start - 1] === '\t')) start -= 1;
        const alone = start === 0 || text[start - 1] === '\n';
        edits.push({ start, end: alone && end >= 0 ? stop + 1 : stop, text: '' });
      }
      at = stop - 1;
    }
  }
  return edits;
}

// Throws when a scaled Trench's floor lies below the Depth Limit, which does not scale, since the place's Destroy Height
// under it does not either.
function belowDepthLimit(text, limit) {
  const code = withoutComments(text);
  const range = sectionRange(code, 'regions');
  for (const entry of range ? entries(code, range) : []) {
    const floors = new RegExp(`${FIELD_START}floors\\s*=\\s*\\{([^}]*)\\}`).exec(entry.source);
    const lowest = floors ? Math.min(...(floors[1].match(NUMBER) || []).map(Number)) : Infinity;
    if (lowest < limit) throw new Error(`scale would take trench ${textField(entry.source, 'id')}'s floor to ${lowest}, below the Depth Limit ${limit}. Nothing was changed`);
  }
}

// Multiplies a plan by `factor`: where things stand, about the map's centre, how long and how high they
// are, and the extent that holds them. Seeds stay, so the same noise draws it at the new size.
function scale(text, factor) {
  const code = withoutComments(text);
  const extent = extentOf(code);
  const size = numberField(code, 'chunkSize');
  if (!extent || !size) throw new Error('The World Plan needs an extent and a chunkSize');
  const sites = /^\s*sites\s*=\s*\{\s*[^}\s]/m.test(code);
  const limit = /^\s*worldLimit\s*=\s*([^\s,]+)/m.exec(code);
  if (sites || (limit && limit[1] !== 'nil')) throw new Error('scale does not handle sites or a worldLimit yet. Nothing was changed');

  const x = scaleAxis(extent.minX, extent.maxX, factor);
  const z = scaleAxis(extent.minZ, extent.maxZ, factor);
  const placeX = (value) => Math.round(x.newCentre * size + (value - x.centre * size) * factor);
  const placeZ = (value) => Math.round(z.newCentre * size + (value - z.centre * size) * factor);
  const placed = (table) => {
    const values = (table.match(NUMBER) || []).map(Number);
    const point = values.length === 3
      ? [placeX(values[0]), round2(values[1] * factor), placeZ(values[2])]
      : [placeX(values[0]), placeZ(values[1])];
    return `{ ${point.join(', ')} }`;
  };

  const edits = staleComments(text);
  const droppedComments = edits.length;
  const eachField = (names, make) => {
    for (const m of code.matchAll(new RegExp(`${FIELD_START}(${names.join('|')})(\\s*=\\s*)(-?\\d+(?:\\.\\d+)?)`, 'gm'))) {
      edits.push({ start: m.index, end: m.index + m[0].length, text: `${m[1]}${m[2]}${make(Number(m[3]), m[1])}` });
    }
  };
  eachField(LENGTHS, (value, name) => round2(Math.min(value * factor, LIMITS[name] ?? Infinity)));
  eachField(ON_THE_GRID, (value) => Math.round((value * factor) / VOXEL) * VOXEL);
  eachField(['octaves'], (value) => Math.max(1, value + Math.round(Math.log2(factor))));
  for (const list of code.matchAll(new RegExp(`${FIELD_START}(?:${LISTS.join('|')})\\s*=\\s*\\{[^}]*\\}`, 'gm'))) {
    for (const number of list[0].matchAll(NUMBER)) {
      const start = list.index + number.index;
      edits.push({ start, end: start + number[0].length, text: String(round2(Number(number[0]) * factor)) });
    }
  }
  for (const center of code.matchAll(new RegExp(`${FIELD_START}(center\\s*=\\s*)(\\{[^}]*\\})`, 'gm'))) {
    edits.push({ start: center.index, end: center.index + center[0].length, text: `${center[1]}${placed(center[2])}` });
  }
  for (const points of code.matchAll(new RegExp(`${FIELD_START}points\\s*=\\s*\\{`, 'gm'))) {
    const open = points.index + points[0].length - 1;
    const close = closing(code, open);
    for (const point of code.slice(open + 1, close).matchAll(/\{[^{}]*\}/g)) {
      const start = open + 1 + point.index;
      edits.push({ start, end: start + point[0].length, text: placed(point[0]) });
    }
  }
  const declared = /extent\s*=\s*\{[^}]*\}/.exec(code);
  edits.push({ start: declared.index, end: declared.index + declared[0].length, text: `extent = { minX = ${x.min}, maxX = ${x.max}, minZ = ${z.min}, maxZ = ${z.max} }` });

  edits.sort((a, b) => b.start - a.start);
  // A comment inside a table could make two edits meet, so this stops rather than write a broken plan.
  edits.forEach((edit, index) => {
    if (index > 0 && edit.end > edits[index - 1].start) throw new Error('scale could not rewrite this plan, since a comment sits inside a table it changes. Nothing was changed');
  });
  let out = text;
  for (const edit of edits) out = out.slice(0, edit.start) + edit.text + out.slice(edit.end);
  belowDepthLimit(out, numberField(code, 'depthLimit') ?? DEPTH_LIMIT);
  return { text: out, before: extent, extent: { minX: x.min, maxX: x.max, minZ: z.min, maxZ: z.max }, droppedComments };
}

// The heading of the newest entry in a world's history.
function lastChange(history) {
  const match = /^## (.+)$/m.exec(history);
  return match ? match[1] : null;
}

module.exports = { facts, stateFacts, remove, removalEntry, scale, lastChange };
