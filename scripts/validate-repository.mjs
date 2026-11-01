#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import GithubSlugger from "github-slugger";
import MarkdownIt from "markdown-it";
import YAML from "yaml";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
let root;
let mode;
let rootArgumentSeen = false;
let baselineRef;
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--root") {
    if (rootArgumentSeen) usage("unknown or repeated argument: --root");
    if (index + 1 >= args.length || args[index + 1].startsWith("--")) usage("--root requires a path");
    rootArgumentSeen = true;
    root = path.resolve(args[++index]);
  } else if (args[index] === "--baseline") {
    if (baselineRef !== undefined) usage("unknown or repeated argument: --baseline");
    if (index + 1 >= args.length || args[index + 1].startsWith("-")) usage("--baseline requires a Git ref");
    baselineRef = args[++index];
  } else if (["--metadata", "--links", "--all"].includes(args[index])) {
    if (mode) usage(`unknown or repeated argument: ${args[index]}`);
    mode = args[index].slice(2);
  } else usage(`unknown or repeated argument: ${args[index]}`);
}
if (!mode) usage("exactly one of --metadata, --links, or --all is required");
if (baselineRef !== undefined && mode !== "all") usage("--baseline is only valid with --all");
if (!root) {
  try {
    root = execFileSync("git", ["-C", SCRIPT_DIR, "rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
  } catch {
    usage("cannot resolve Git root; pass --root");
  }
}
root = fs.realpathSync(root);
const baselineCommit = baselineRef === undefined ? undefined : resolveBaseline(baselineRef);

const diagnostics = [];
const unsafeReports = new Set();
const report = (file, message) => diagnostics.push(`${slash(file)}: ${message}`);

function usage(message) {
  console.error(`validate-repository: ${message}`);
  console.error("usage: validate-repository.mjs [--root PATH] (--metadata|--links|--all) [--baseline REF]");
  process.exit(2);
}
function git(gitArgs) {
  return execFileSync("git", ["-C", root, ...gitArgs], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
}
function resolveBaseline(ref) {
  const exists = (name) => { try { git(["show-ref", "--verify", "--quiet", name]); return true; } catch { return false; } };
  if (ref.includes("\0") || ref.startsWith("-")) usage(`invalid baseline ref: ${ref}`);
  const namespaces = ["", "refs/tags/", "refs/heads/", "refs/remotes/"].filter((prefix) => exists(`${prefix}${ref}`));
  if (namespaces.length > 1) usage(`ambiguous baseline ref: ${ref}`);
  try { return git(["rev-parse", "--verify", "--quiet", "--end-of-options", `${ref}^{commit}`]).trim(); }
  catch { usage(`baseline ref is unavailable: ${ref}`); }
}
function slash(value) { return value.split(path.sep).join("/"); }
function isInside(parent, child) {
  const relative = path.relative(parent, child);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== "..");
}
function unsafe(relative, message) {
  const key = `${relative}\0${message}`;
  if (!unsafeReports.has(key)) {
    unsafeReports.add(key);
    report(relative, message);
  }
}

// Every repository-derived read passes through this lexical, lstat, and realpath
// boundary. In particular, no parse diagnostic can disclose an outside-root file.
function safeNode(relative, { missing = true, regularFile = false } = {}) {
  if (typeof relative !== "string" || relative.length === 0 || relative.includes("\0") || path.isAbsolute(relative)) {
    unsafe(String(relative), "unsafe path is not a repository-relative name");
    return null;
  }
  const lexical = path.resolve(root, relative);
  if (!isInside(root, lexical)) {
    unsafe(relative, "unsafe path escapes repository root");
    return null;
  }
  const rootRelative = path.relative(root, lexical);
  let cursor = root;
  for (const component of rootRelative.split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, component);
    let stat;
    try { stat = fs.lstatSync(cursor); }
    catch (error) {
      if (error.code === "ENOENT") {
        if (missing) report(relative, "required file is missing");
        return null;
      }
      unsafe(relative, `cannot inspect path safely (${error.code || error.message})`);
      return null;
    }
    if (stat.isSymbolicLink()) {
      unsafe(relative, `unsafe path contains symlink: ${slash(path.relative(root, cursor))}`);
      return null;
    }
  }
  let physical;
  try { physical = fs.realpathSync(lexical); }
  catch (error) {
    if (missing) report(relative, `cannot resolve path safely (${error.code || error.message})`);
    return null;
  }
  if (!isInside(root, physical)) {
    unsafe(relative, "unsafe physical path escapes repository root");
    return null;
  }
  const stat = fs.lstatSync(physical);
  if (regularFile && !stat.isFile()) {
    unsafe(relative, "unsafe input is not a regular file");
    return null;
  }
  return { lexical, physical, stat };
}
function readText(relative) {
  const node = safeNode(relative, { regularFile: true });
  if (!node) return null;
  try { return fs.readFileSync(node.physical, "utf8"); }
  catch (error) { report(relative, `cannot read file safely (${error.code || error.message})`); return null; }
}
function discover() {
  let hasRootGitMarker = false;
  try {
    const marker = fs.lstatSync(path.join(root, ".git"));
    hasRootGitMarker = true;
    if (!marker.isFile() && !marker.isDirectory()) {
      report(".", "unsafe Git root marker is not a regular file or directory");
      return [];
    }
  }
  catch (error) {
    if (error.code !== "ENOENT") {
      report(".", `cannot inspect Git root marker safely (${error.code || error.message})`);
      return [];
    }
  }
  let gitTopLevel;
  try {
    gitTopLevel = execFileSync("git", ["-C", root, "rev-parse", "--show-toplevel"], {
      encoding: "utf8", stdio: ["ignore", "pipe", "ignore"]
    }).trim();
  } catch (error) {
    if (hasRootGitMarker) {
      report(".", `tracked Git discovery failed closed (${error.status ?? error.code ?? "unknown"})`);
      return [];
    }
  }
  if (gitTopLevel) {
    let canonicalTopLevel;
    try { canonicalTopLevel = fs.realpathSync(gitTopLevel); }
    catch (error) {
      report(".", `cannot canonicalize detected Git root (${error.code || error.message})`);
      return [];
    }
    if (canonicalTopLevel === root) {
      try {
        const output = execFileSync("git", ["-C", root, "ls-files", "-z"], {
          encoding: "buffer", stdio: ["ignore", "pipe", "ignore"]
        });
        return output.toString("utf8").split("\0").filter(Boolean).sort();
      } catch (error) {
        report(".", `tracked Git discovery failed closed (${error.status ?? error.code ?? "unknown"})`);
        return [];
      }
    }
    if (hasRootGitMarker) {
      report(".", "Git root marker does not resolve to the explicit canonical root");
      return [];
    }
  }

  // A root with no .git marker whose canonical top level is absent or different
  // is positively outside the tracked-root trust boundary. Walk it without
  // following symlinks; safeNode applies the same boundary again before reads.
  const found = [];
  const walk = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.name === ".git" || entry.name === ".check-cache" || entry.name === "node_modules") continue;
      const full = path.join(directory, entry.name);
      const relative = slash(path.relative(root, full));
      const stat = fs.lstatSync(full);
      if (stat.isSymbolicLink()) { found.push(relative); continue; }
      if (stat.isDirectory()) walk(full);
      else if (stat.isFile()) found.push(relative);
    }
  };
  walk(root);
  return found.sort();
}

const files = discover();
const json = new Map();
const JSON_READ_FAILURE = Symbol("JSON_READ_FAILURE");
function readJson(relative) {
  if (json.has(relative)) return json.get(relative);
  const text = readText(relative);
  if (text === null) { json.set(relative, JSON_READ_FAILURE); return JSON_READ_FAILURE; }
  try {
    const value = JSON.parse(text);
    json.set(relative, value);
    return value;
  } catch (error) {
    report(relative, `invalid JSON: ${error.message}`);
    json.set(relative, JSON_READ_FAILURE);
    return JSON_READ_FAILURE;
  }
}
function isObject(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
function jsonType(value) { return value === null ? "null" : Array.isArray(value) ? "array" : typeof value; }
function isCatalogShaped(value) {
  return isObject(value) && typeof value.name === "string" && isObject(value.owner) && Array.isArray(value.plugins);
}
function deepEqual(left, right) {
  if (Object.is(left, right)) return true;
  if (Array.isArray(left) || Array.isArray(right)) {
    return Array.isArray(left) && Array.isArray(right) && left.length === right.length &&
      left.every((value, index) => deepEqual(value, right[index]));
  }
  if (left && right && typeof left === "object" && typeof right === "object") {
    const leftKeys = Object.keys(left);
    const rightKeys = Object.keys(right);
    return leftKeys.length === rightKeys.length && leftKeys.every((key) =>
      Object.prototype.hasOwnProperty.call(right, key) && deepEqual(left[key], right[key]));
  }
  return false;
}

const INDEPENDENT_EVALUATION_CLAIM = "independent cold-agent evaluation with controlled inputs";
const CLIENT_VISIBLE_CLAIM_SURFACES = [
  "README.md",
  ".claude-plugin/marketplace.json",
  ".agents/plugins/marketplace.json",
  "plugins/loom/.claude-plugin/plugin.json",
  "plugins/loom/.codex-plugin/plugin.json"
];
const RELEASE_METADATA_FIXTURE_ROOT = "plugins/loom/adapters/fixtures/v0.2.0/metadata/";
const PROHIBITED_EVALUATION_CLAIM = /\b(?:self-favoring\s+is\s+impossible|blind(?:-reviewed)?(?:\s+evaluation)?|impartial(?:ity)?(?:\s+by\s+construction)?|anonymous(?:ly)?(?:\s+evaluator)?|impossible)\b/giu;
const IMMEDIATE_CLAIM_QUALIFICATION = new RegExp(`^[ \\t:;,()\\[\\]—–-]*${INDEPENDENT_EVALUATION_CLAIM.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`, "iu");

function visitStrings(value, visit) {
  if (typeof value === "string") visit(value);
  else if (Array.isArray(value)) value.forEach((entry) => visitStrings(entry, visit));
  else if (isObject(value)) Object.values(value).forEach((entry) => visitStrings(entry, visit));
}
function hasUnqualifiedEvaluationClaim(value) {
  let unqualified = false;
  visitStrings(value, (text) => {
    PROHIBITED_EVALUATION_CLAIM.lastIndex = 0;
    for (const match of text.matchAll(PROHIBITED_EVALUATION_CLAIM)) {
      if (!IMMEDIATE_CLAIM_QUALIFICATION.test(text.slice(match.index + match[0].length))) {
        unqualified = true;
        break;
      }
    }
  });
  return unqualified;
}
function validateClientVisibleClaims() {
  let valid = true;
  const releaseFixtures = files.filter((relative) => relative.startsWith(RELEASE_METADATA_FIXTURE_ROOT) && relative.endsWith(".json"));
  const surfaces = [...new Set([...CLIENT_VISIBLE_CLAIM_SURFACES, ...releaseFixtures])].sort();
  for (const relative of surfaces) {
    const value = relative.endsWith(".json") ? readJson(relative) : readText(relative);
    if (value === null || value === JSON_READ_FAILURE) continue;
    if (hasUnqualifiedEvaluationClaim(value)) {
      report(relative, `prohibited unqualified evaluation claim; use '${INDEPENDENT_EVALUATION_CLAIM}'`);
      valid = false;
    }
  }
  return valid;
}

const THIN_ADAPTER_MAX_LINES = 20;
const THIN_ADAPTER_PATTERNS = [
  [/^plugins\/loom\/commands\/([^/]+)\.md$/, (name) => `skills/loom-${name}/SKILL.md`],
  [/^plugins\/loom\/agents\/([^/]+)\.md$/, (name) => `roles/${name}.md`],
  [/^\.agents\/skills\/(loom-[^/]+)\/SKILL\.md$/, (name) => `skills/${name}/SKILL.md`]
];
// Claude commands/agents and Antigravity .agents/skills SHALL be thin routes to
// the shared canonical skills/roles content (spec 10 "one distribution, two
// catalogs"; ADR 0018 decision 3): short, and pointing at the exact shared body
// it adapts. This is a mechanical proxy against a divergent second
// implementation ("copying helpers or workflow bodies into client directories
// is a conformance failure").
function validateThinAdapters() {
  let valid = true;
  for (const relative of files) {
    const matched = THIN_ADAPTER_PATTERNS.find(([pattern]) => pattern.test(relative));
    if (!matched) continue;
    const [pattern, pointerFor] = matched;
    const name = relative.match(pattern)[1];
    const text = readText(relative);
    if (text === null) continue;
    const lineCount = text.split("\n").length;
    if (lineCount > THIN_ADAPTER_MAX_LINES) {
      report(relative, `thin adapter exceeds ${THIN_ADAPTER_MAX_LINES} lines (${lineCount}); a client adapter must route to its shared canonical body, not copy it`);
      valid = false;
    }
    const pointer = pointerFor(name);
    if (!text.includes(pointer)) {
      report(relative, `thin adapter does not route to its shared canonical body: missing reference to ${pointer}`);
      valid = false;
    } else if (!safeNode(`plugins/loom/${pointer}`, { missing: false, regularFile: true })) {
      report(relative, `thin adapter routes to a shared canonical body that does not exist: ${pointer}`);
      valid = false;
    }
  }
  return valid;
}

async function validateMetadata() {
  let structurallyValid = true;
  for (const relative of files.filter((file) => file.endsWith(".json"))) {
    if (readJson(relative) === JSON_READ_FAILURE) structurallyValid = false;
  }
  if (!validateClientVisibleClaims()) structurallyValid = false;
  if (!validateThinAdapters()) structurallyValid = false;

  const authorizedCatalogs = new Set([
    ".claude-plugin/marketplace.json",
    ".agents/plugins/marketplace.json",
    "plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-marketplace.json",
    "plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-marketplace.json"
  ]);
  for (const relative of files.filter((file) => file.endsWith(".json"))) {
    const value = readJson(relative);
    if (value !== JSON_READ_FAILURE && isCatalogShaped(value) && !authorizedCatalogs.has(relative)) {
      report(relative, "catalog-shaped JSON is not at an authorized live or release-fixture path");
      structurallyValid = false;
    }
  }

  const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
  addFormats(ajv);
  const schemaFiles = files.filter((file) => file.endsWith(".schema.json"));
  for (const relative of schemaFiles) {
    const schema = readJson(relative);
    if (schema === JSON_READ_FAILURE) { structurallyValid = false; continue; }
    if (!isObject(schema)) {
      report(relative, `invalid JSON Schema: expected object, got ${jsonType(schema)}`);
      structurallyValid = false;
      continue;
    }
    try { ajv.addSchema(schema); }
    catch (error) { report(relative, `invalid JSON Schema: ${error.message}`); structurallyValid = false; }
  }

  const schemaBindings = [
    ["plugins/loom/.claude-plugin/plugin.json", "scripts/schemas/claude-plugin-2.1.216.schema.json"],
    [".claude-plugin/marketplace.json", "scripts/schemas/claude-marketplace-2.1.216.schema.json"],
    ["plugins/loom/.codex-plugin/plugin.json", "scripts/schemas/codex-plugin-0.144.6.schema.json"],
    [".agents/plugins/marketplace.json", "scripts/schemas/codex-marketplace-0.144.6.schema.json"],
    ["plugins/loom/adapters/compatibility/v0.2.0.json", "plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json"],
    ["plugins/loom/adapters/roots/claude-plugin-root-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"],
    ["plugins/loom/adapters/roots/codex-skill-source-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"]
  ];
  const schemaResults = new Map();
  for (const [target, schemaPath] of schemaBindings) {
    const valid = validateJson(target, schemaPath, ajv);
    schemaResults.set(target, valid);
    if (!valid) structurallyValid = false;
  }

  const readme = readText("README.md");
  if (readme !== null) {
    if (!/The exact supported client floors are\s+Claude Code 2\.1\.216 and Codex CLI 0\.144\.6\./.test(readme)) {
      report("README.md", "missing exact supported client-floor statement: Claude Code 2.1.216 and Codex CLI 0.144.6");
      structurallyValid = false;
    }
    if (!readme.includes("static scaffolding only")) {
      report("README.md", "missing static Codex scaffolding limitation");
      structurallyValid = false;
    }
  }

  const fixtureBindings = [
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json", schemaBindings[0]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-marketplace.json", schemaBindings[1]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-manifest.json", schemaBindings[2]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-marketplace.json", schemaBindings[3]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json", schemaBindings[4]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-root.json", schemaBindings[5]],
    ["plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-root.json", schemaBindings[6]]
  ];
  for (const [fixture, [live, schemaPath]] of fixtureBindings) {
    const fixtureValid = validateJson(fixture, schemaPath, ajv);
    if (!fixtureValid) { structurallyValid = false; continue; }
    if (!schemaResults.get(live)) continue;
    const left = readJson(fixture);
    const right = readJson(live);
    if (!deepEqual(left, right)) report(fixture, `release fixture differs from ${live}`);
  }

  const frontmatter = [
    [/^plugins\/loom\/commands\/[^/]+\.md$/, "scripts/schemas/command-frontmatter-v1.schema.json"],
    [/^plugins\/loom\/agents\/[^/]+\.md$/, "scripts/schemas/agent-frontmatter-v1.schema.json"],
    [/^plugins\/loom\/skills\/.+\/SKILL\.md$/, "scripts/schemas/skill-frontmatter-v1.schema.json"],
    [/^\.agents\/skills\/.+\/SKILL\.md$/, "scripts/schemas/skill-frontmatter-v1.schema.json"]
  ];
  const names = { command: new Map(), agent: new Map(), skill: new Map(), antigravitySkill: new Map() };
  for (const relative of files) {
    const matched = frontmatter.find(([pattern]) => pattern.test(relative));
    if (!matched) continue;
    const value = parseFrontmatter(relative);
    if (!value) continue;
    validateValue(relative, value, matched[1], ajv);
    const kind = relative.startsWith(".agents/skills/") ? "antigravitySkill" : relative.includes("/commands/") ? "command" : relative.includes("/agents/") ? "agent" : "skill";
    const componentName = value.name || (kind === "command" ? path.basename(relative, ".md") : undefined);
    if (componentName) {
      if (names[kind].has(componentName)) report(relative, `duplicate ${kind} name '${componentName}' (also ${names[kind].get(componentName)})`);
      else names[kind].set(componentName, relative);
    }
  }

  // Schema-invalid release objects are never passed into semantic validation.
  if (structurallyValid) semanticMetadata();
}

function validateJson(target, schemaPath, ajv) {
  const targetNode = safeNode(target, { regularFile: true });
  if (!targetNode) return false;
  const schemaNode = safeNode(schemaPath, { regularFile: true });
  if (!schemaNode) {
    report(target, `schema reference is missing or unsafe: ${schemaPath}`);
    return false;
  }
  const value = readJson(target);
  const schema = readJson(schemaPath);
  if (value === JSON_READ_FAILURE || schema === JSON_READ_FAILURE || !isObject(schema)) return false;
  return validateValue(target, value, schemaPath, ajv);
}
function validateValue(target, value, schemaPath, ajv) {
  let validator;
  try {
    const schema = readJson(schemaPath);
    if (schema === JSON_READ_FAILURE || !isObject(schema)) return false;
    validator = ajv.getSchema(schema.$id) || ajv.compile(schema);
  } catch (error) {
    report(schemaPath, `invalid JSON Schema: ${error.message}`);
    return false;
  }
  if (validator(value)) return true;
  for (const error of validator.errors || []) report(target, `schema ${error.instancePath || "/"} ${error.message}`);
  return false;
}
function parseFrontmatter(relative) {
  const text = readText(relative);
  if (text === null) return null;
  if (!text.startsWith("---\n")) { report(relative, "missing YAML frontmatter"); return null; }
  const end = text.indexOf("\n---\n", 4);
  if (end < 0) { report(relative, "unterminated YAML frontmatter"); return null; }
  try {
    const document = YAML.parseDocument(text.slice(4, end), { uniqueKeys: true });
    if (document.errors.length) throw document.errors[0];
    const value = document.toJSON();
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("frontmatter must be a mapping");
    return value;
  } catch (error) {
    report(relative, `invalid YAML frontmatter: ${error.message}`);
    return null;
  }
}
function semanticMetadata() {
  const claudeManifest = readJson("plugins/loom/.claude-plugin/plugin.json");
  const codexManifest = readJson("plugins/loom/.codex-plugin/plugin.json");
  const claudeCatalog = readJson(".claude-plugin/marketplace.json");
  const codexCatalog = readJson(".agents/plugins/marketplace.json");
  const matrixPath = "plugins/loom/adapters/compatibility/v0.2.0.json";
  const matrix = readJson(matrixPath);
  const rootPaths = [
    "plugins/loom/adapters/roots/claude-plugin-root-v1.json",
    "plugins/loom/adapters/roots/codex-skill-source-v1.json"
  ];
  const roots = rootPaths.map(readJson);
  for (const [relative, value] of [["plugins/loom/.claude-plugin/plugin.json", claudeManifest], ["plugins/loom/.codex-plugin/plugin.json", codexManifest]]) {
    if (value && (value.name !== "loom" || value.version !== "0.2.0" || value.license !== "MIT" || value.repository !== "https://github.com/craigeous/loom")) {
      report(relative, "product name, exact SemVer, license, or repository identity drift");
    }
  }
  if (claudeManifest && codexManifest && !deepEqual(
    [claudeManifest.name, claudeManifest.version, claudeManifest.description, claudeManifest.homepage, claudeManifest.license, claudeManifest.repository],
    [codexManifest.name, codexManifest.version, codexManifest.description, codexManifest.homepage, codexManifest.license, codexManifest.repository]
  )) report("plugins/loom/.codex-plugin/plugin.json", "manifest identity differs from Claude manifest");

  for (const [relative, catalog, requireVersion] of [[".claude-plugin/marketplace.json", claudeCatalog, true], [".agents/plugins/marketplace.json", codexCatalog, false]]) {
    const entries = catalog.plugins;
    if (new Set(entries.map((entry) => entry.name)).size !== entries.length) report(relative, "duplicate catalog component name");
    const entry = entries.find((candidate) => candidate.name === "loom");
    if (!entry) report(relative, "catalog is missing loom client manifest");
    else {
      if (entry.source !== "./plugins/loom") report(relative, "catalog source identity drift");
      if (requireVersion && entry.version !== "0.2.0") report(relative, "catalog release provenance drift");
      validateCatalogSource(relative, entry.source);
    }
  }

  if (!deepEqual(matrix.clientFloors, { claude: "2.1.216", codex: "0.144.6" })) report(matrixPath, "client floor drift");
  const expectedProfiles = [
    { profile: "Economy", consumers: ["researcher"], claude: { selector: "haiku" }, codex: { model: "gpt-5.6-terra", effort: "low" } },
    { profile: "Standard", consumers: ["developer", "orchestrator"], claude: { selector: "sonnet" }, codex: { model: "gpt-5.6", effort: "medium" } },
    { profile: "Deep review", consumers: ["planner", "plan evaluator", "code evaluator"], claude: { selector: "opus" }, codex: { model: "gpt-5.6", effort: "high" } }
  ];
  if (!deepEqual(matrix.profiles, expectedProfiles)) report(matrixPath, "profile mapping drift");
  const expectedBindings = [
    { id: "claude-plugin-root/v1", path: rootPaths[0] },
    { id: "codex-skill-source/v1", path: rootPaths[1] }
  ];
  const normalizedBindings = [...matrix.rootBindings].sort((left, right) => left.id.localeCompare(right.id));
  const normalizedExpected = [...expectedBindings].sort((left, right) => left.id.localeCompare(right.id));
  if (!deepEqual(normalizedBindings, normalizedExpected)) report(matrixPath, "root binding ID/path pair drift");
  for (const binding of expectedBindings) {
    const node = safeNode(binding.path, { missing: false, regularFile: true });
    if (!node) report(matrixPath, `root binding reference is missing or unsafe: ${binding.path}`);
    else if (readJson(binding.path)?.schema !== binding.id) report(binding.path, `binding-reference drift from ${binding.id}`);
  }
  const expectedRoots = [
    {
      schema: "claude-plugin-root/v1", client: "claude", binding: "CLAUDE_PLUGIN_ROOT",
      inputMustBeAbsolute: true, invocationMustBeAbsolute: true, canonicalizeInput: true,
      canonicalRootRequired: true, manifest: ".claude-plugin/plugin.json", manifestMustBeCanonical: true,
      manifestMustBeRegularFile: true, expectedName: "loom", expectedVersion: "0.2.0",
      helperDirectory: "bin", helperDirectoryMustBeDirectChild: true, allowedHelpers: ["loom-coord", "loom-verify-identity", "loom-review", "loom-eval-workspace", "loom-doctor"],
      helperMustBeRegularFile: true, helperMustBeExecutable: true
    },
    {
      schema: "codex-skill-source/v1", client: "codex", inputMustBeAbsolute: true,
      invocationMustBeAbsolute: true, skillSuffix: "skills/<skill>/SKILL.md", skillMustBeCanonical: true,
      skillMustBeRegularFile: true, skillIdentitySource: "frontmatter.name", skillIdentityMustMatchDirectory: true,
      pluginRootAscent: "../..", pluginRootMustBeCanonical: true, ascendToManifest: ".codex-plugin/plugin.json",
      manifestMustBeCanonical: true, manifestMustBeRegularFile: true, expectedName: "loom", expectedVersion: "0.2.0",
      helperDirectory: "bin", helperDirectoryMustBeDirectChild: true, allowedHelpers: ["loom-coord", "loom-verify-identity", "loom-review", "loom-eval-workspace", "loom-doctor"],
      helperMustBeRegularFile: true, helperMustBeExecutable: true,
      forbiddenWorkflowRootGuesses: ["CLAUDE_PLUGIN_ROOT", "PLUGIN_ROOT", "CODEX_HOME", "PATH"],
      hookBinding: "PLUGIN_ROOT", hookManifest: "./hooks/hooks.json"
    }
  ];
  for (const [index, binding] of roots.entries()) {
    if (!deepEqual(binding, expectedRoots[index])) report(rootPaths[index], "installed-root contract drift");
  }

  // One physical hook manifest for both clients (spec 08; ADR 0018 decision
  // 4): the Codex root binding above pins hookManifest to exactly
  // ./hooks/hooks.json, and no second client-specific hook manifest may
  // exist alongside it.
  const hookManifests = files.filter((relative) => /^plugins\/loom\/hooks\/[^/]+\.json$/.test(relative));
  if (!deepEqual(hookManifests, ["plugins/loom/hooks/hooks.json"])) {
    report("plugins/loom/hooks/hooks.json", `expected exactly one shared hook manifest, found: ${hookManifests.join(", ") || "none"}`);
  }

  // Local-review finder prompt assets (ADR 0021): packaged, non-empty regular files.
  for (const finder of ["review-correctness-v1", "review-tests-v1", "review-security-v1"]) {
    const relative = `plugins/loom/finders/${finder}.md`;
    const node = safeNode(relative, { regularFile: true });
    if (node && node.stat.size === 0) report(relative, "finder prompt asset is empty");
  }
}
function validateCatalogSource(catalogPath, source) {
  if (typeof source !== "string") return;
  const relative = slash(path.normalize(source));
  const node = safeNode(relative, { missing: false });
  if (!node) { report(catalogPath, `catalog source is missing, escaped, or unsafe: ${source}`); return; }
  const expected = safeNode("plugins/loom", { missing: false });
  if (!expected || node.physical !== expected.physical) report(catalogPath, `catalog source resolves to different physical plugin root: ${source}`);
}

async function validateLinks() {
  const markdownParser = new MarkdownIt({ html: false, linkify: false });
  // Preserve the authored href so malformed percent escapes cannot be hidden by
  // markdown-it's URL normalization before our strict decoder sees them.
  markdownParser.normalizeLink = (value) => value;
  markdownParser.normalizeLinkText = (value) => value;
  // Evaluations and archived plans are historical evidence: --all checks their
  // links (known breakage is inventoried in the allowlist); --links keeps them out.
  const historical = (relative) => relative.startsWith(".docs/evaluations/") || relative.startsWith(".docs/slice-plans/archive/");
  const markdown = files.filter((relative) => relative.endsWith(".md") && (mode === "all" || !historical(relative)));
  const scanned = new Set(markdown);
  const used = new Set();
  for (const source of markdown) {
    const text = readText(source);
    if (text === null) continue;
    const tokens = markdownParser.parse(text, {});
    for (const token of tokens) {
      if (token.type !== "inline" || !token.children) continue;
      for (const child of token.children) {
        if (child.type !== "link_open") continue;
        const target = child.attrGet("href");
        if (!target || /^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith("//")) continue;
        const error = checkLink(source, target, markdownParser);
        if (!error) continue;
        const key = `${source}\t${target}`;
        if (allowlist.has(key)) used.add(key);
        else report(source, `${error}: ${target}`);
      }
    }
  }
  for (const key of allowlist.keys()) {
    // --all reports every unused record (even a deleted or renamed source); --links only judges scanned sources.
    if (!used.has(key) && (mode === "all" || scanned.has(key.split("\t")[0]))) report(allowlistPath, `stale allowlist record: ${key}`);
  }
}
const allowlistPath = "scripts/validation/relative-link-allowlist.txt";
// Records are source<TAB>target<TAB>reason. A target of rule:<id> is instead a
// narrowly scoped documentation-state exception for that exact source and rule.
const allowlist = new Map();
const ruleExceptions = new Map();
const ruleExceptionsUsed = new Set();
function loadAllowlist() {
  const records = parseAllowlist(allowlistPath);
  for (const [key, reason] of records) {
    (key.split("\t")[1].startsWith("rule:") ? ruleExceptions : allowlist).set(key, reason);
  }
}
function parseAllowlist(relative) {
  const records = new Map();
  const text = readText(relative);
  if (text === null) return records;
  const lines = text.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line || line.startsWith("#")) continue;
    const fields = line.split("\t");
    if (fields.length !== 3 || !fields.every((field) => field.length > 0)) { report(relative, `malformed allowlist record at line ${index + 1}`); continue; }
    const key = `${fields[0]}\t${fields[1]}`;
    if (records.has(key)) report(relative, `duplicate allowlist record at line ${index + 1}: ${key}`);
    else records.set(key, fields[2]);
  }
  return records;
}
function checkLink(source, target, markdownParser) {
  const hash = target.indexOf("#");
  const rawPath = hash < 0 ? target : target.slice(0, hash);
  const rawFragment = hash < 0 ? "" : target.slice(hash + 1);
  let decodedPath;
  let fragment;
  try {
    decodedPath = decodeURIComponent(rawPath);
    fragment = decodeURIComponent(rawFragment);
  } catch {
    return "malformed percent encoding in link";
  }
  const sourceDirectory = path.posix.dirname(source);
  const repositoryRelative = decodedPath ? slash(path.posix.normalize(path.posix.join(sourceDirectory, decodedPath))) : source;
  // A historical source may carry an inventoried link that leaves the repository.
  if (source.startsWith(".docs/") && /^\.docs\/(?:evaluations|slice-plans\/archive)\//.test(source) && !isInside(root, path.resolve(root, repositoryRelative))) return "missing or unsafe relative-link target";
  const node = safeNode(repositoryRelative, { missing: false });
  if (!node) return "missing or unsafe relative-link target";
  if (node.stat.isDirectory()) return fragment ? "fragment target is a directory" : null;
  if (!node.stat.isFile()) return "missing or unsafe relative-link target";
  if (!fragment) return null;
  if (path.extname(node.physical).toLowerCase() !== ".md") return "fragment target is not Markdown";
  const text = readText(repositoryRelative);
  if (text === null) return "missing or unsafe relative-link target";
  const slugs = headingSlugs(text, markdownParser);
  if (!slugs.has(fragment)) return "missing Markdown fragment";
  return null;
}
function renderedInlineText(inline) {
  if (!inline.children) return inline.content;
  return inline.children.map((child) => {
    if (["text", "code_inline", "image"].includes(child.type)) return child.content;
    if (["softbreak", "hardbreak"].includes(child.type)) return " ";
    return "";
  }).join("");
}
function headingSlugs(text, markdownParser) {
  const result = new Set();
  const slugger = new GithubSlugger();
  const tokens = markdownParser.parse(text, {});
  for (let index = 0; index < tokens.length - 1; index += 1) {
    if (tokens[index].type === "heading_open" && tokens[index + 1].type === "inline") {
      result.add(slugger.slug(renderedInlineText(tokens[index + 1])));
    }
  }
  return result;
}

// ---- Documentation state (--all): lifecycle, evaluations, headings, authority ----
// Local artifacts and available Git history only; this cannot prove independent
// review, owner decisions, or remote landing (spec 03; the receipt owns Landed).
const DOC_STATUSES = {
  spec: ["Draft", "Plan Review", "Approved", "Needs Clarification", "Abandoned"],
  adr: ["Draft", "Plan Review", "Accepted", "Needs Clarification", "Abandoned"],
  plan: ["Draft", "Plan Review", "Approved", "In Progress", "Implemented", "Ready to Publish", "Landed", "Archived", "Needs Clarification", "Abandoned"]
};
const DOC_ARROWS = {
  spec: { Draft: ["Plan Review"], "Plan Review": ["Approved", "Draft"], Approved: ["Draft", "Plan Review"] },
  adr: { Draft: ["Plan Review"], "Plan Review": ["Accepted", "Draft"] },
  plan: {
    Draft: ["Plan Review"], "Plan Review": ["Approved", "Draft"], Approved: ["In Progress"], "In Progress": ["Implemented"],
    Implemented: ["Ready to Publish", "In Progress"], "Ready to Publish": ["Landed"], Landed: ["Archived"]
  }
};
const DOC_TERMINAL = new Set(["Abandoned", "Archived", "Accepted"]);
const DOC_HEADINGS = {
  spec: ["Authority"],
  adr: ["Context", "Decision", "Consequences"],
  plan: ["Context", "Out of Scope & Threat-Model Boundary", "Steps", "Verification", "Revision Log"],
  evaluation: ["Summary", "Findings"]
};
const EVALUATION_NAME = /^(?:\d{4}-\d{2}-\d{2}-)?(.+?)(-plan)?-eval\.md$/;

function docKind(relative) {
  if (/^\.docs\/spec\/\d\d-[^/]+\.md$/.test(relative)) return "spec";
  if (/^\.docs\/ADR\/\d{4}-[^/]+\.md$/.test(relative)) return "adr";
  if (/^\.docs\/slice-plans\/(?:archive\/)?[^/]+\.md$/.test(relative) && !relative.endsWith("/README.md")) return "plan";
  return null;
}
const planIdentity = (relative) => path.posix.basename(relative, ".md").replace(/-plan$/, "");
// Exact-source, exact-rule exceptions only; each must be used or it is stale.
function ruleReport(file, rule, message) {
  const key = `${file}\trule:${rule}`;
  if (ruleExceptions.has(key)) ruleExceptionsUsed.add(key);
  else report(file, `${message} [${rule}]`);
}
// Header = lines before the first sub-heading, outside code fences.
function headerLines(text) {
  const lines = [];
  let fenced = false;
  for (const line of text.split(/\r?\n/)) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    if (!fenced && /^#{2,6}\s/.test(line)) break;
    lines.push(line);
  }
  return lines;
}
function fieldValues(text, name) {
  return headerLines(text).filter((line) => line.startsWith(`${name}:`)).map((line) => line.slice(name.length + 1).trim());
}
function sectionText(text, name) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^##\\s+${name}\\b`, "i").test(line));
  if (start < 0) return "";
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((line) => /^##\s/.test(line));
  return (end < 0 ? rest : rest.slice(0, end)).join("\n");
}
function relativeHrefs(text, markdownParser) {
  const hrefs = [];
  for (const token of markdownParser.parse(text, {})) {
    if (token.type !== "inline" || !token.children) continue;
    for (const child of token.children) {
      if (child.type !== "link_open") continue;
      const href = child.attrGet("href");
      if (href && !/^[a-z][a-z0-9+.-]*:/i.test(href) && !href.startsWith("//") && !href.startsWith("#")) hrefs.push(href);
    }
  }
  return hrefs;
}
function resolveHref(source, href) {
  let decoded;
  try { decoded = decodeURIComponent(href.split("#")[0]); } catch { return null; }
  const target = slash(path.posix.normalize(path.posix.join(path.posix.dirname(source), decoded)));
  if (!isInside(root, path.resolve(root, target))) return null;
  return safeNode(target, { missing: false, regularFile: true }) ? target : null;
}
function headingTexts(text, markdownParser) {
  const tokens = markdownParser.parse(text, {});
  const found = [];
  for (let index = 0; index < tokens.length - 1; index += 1) {
    if (tokens[index].type === "heading_open" && tokens[index + 1].type === "inline") found.push(renderedInlineText(tokens[index + 1]).trim().toLowerCase());
  }
  return found;
}
const slugRule = (value) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

function statusField(text) {
  return fieldValues(text, "Status");
}
// One direct spec 03 step. `prior` is the status that preceded Needs Clarification
// (undefined when it cannot be established); returns "ambiguous" in that case.
function legalStep(kind, from, to, prior) {
  if (from === to) return true;
  if (DOC_TERMINAL.has(from) || !DOC_STATUSES[kind].includes(from)) return false;
  if (to === "Abandoned") return true;
  if (from === "Needs Clarification") return prior === undefined ? "ambiguous" : to === prior;
  if (to === "Needs Clarification") return true;
  return (DOC_ARROWS[kind][from] || []).includes(to);
}
// FAIL returns are the arrows that revert a rejected artifact; they need a FAIL evaluation.
const isFailReturn = (kind, from, to) => (from === "Plan Review" && to === "Draft") || (kind === "plan" && from === "Implemented" && to === "In Progress");

function validateDocsState() {
  const markdownParser = new MarkdownIt({ html: false, linkify: false });
  markdownParser.normalizeLink = (value) => value;
  markdownParser.normalizeLinkText = (value) => value;
  const artifacts = new Map();
  for (const relative of files) {
    const kind = docKind(relative);
    if (!kind || !relative.endsWith(".md")) continue;
    const text = readText(relative);
    if (text === null) continue;
    const statuses = statusField(text);
    const status = statuses.length === 1 ? statuses[0] : undefined;
    const archived = relative.startsWith(".docs/slice-plans/archive/");
    artifacts.set(relative, { relative, kind, text, status, archived });
    if (statuses.length !== 1) ruleReport(relative, "status-field", `expected exactly one 'Status:' field, found ${statuses.length}`);
    else if (!DOC_STATUSES[kind].includes(status)) ruleReport(relative, "status-token", `illegal ${kind} status '${status}'; legal: ${DOC_STATUSES[kind].join(", ")}`);
    else if (archived && !["Landed", "Archived"].includes(status)) ruleReport(relative, "archive-status", `archived plan must be Landed or Archived, found '${status}'`);
    for (const heading of DOC_HEADINGS[kind]) requireHeading(relative, text, heading, markdownParser);
    checkAuthority(relative, kind, text, artifacts, markdownParser);
  }

  const identities = new Map();
  for (const artifact of artifacts.values()) {
    if (artifact.kind !== "plan") continue;
    const identity = planIdentity(artifact.relative);
    if (!identities.has(identity)) identities.set(identity, []);
    identities.get(identity).push(artifact);
  }
  for (const [identity, plans] of identities) {
    const active = plans.filter((plan) => !plan.archived);
    if (active.length > 1) {
      for (const plan of active) ruleReport(plan.relative, "plan-identity", `slice '${identity}' has more than one active plan (${active.map((entry) => entry.relative).sort().join(", ")})`);
    }
  }

  validateLivingDocs(markdownParser);
  validateEvaluations(markdownParser);
  if (baselineCommit) validateBaseline(artifacts);
  else console.error("validate-repository: snapshot checks only; status transitions were not verified (pass --baseline <ref>)");
  for (const key of ruleExceptions.keys()) {
    if (!ruleExceptionsUsed.has(key)) report(allowlistPath, `stale rule exception: ${key}`);
  }
}

const HANDOFF_LINE_CAP = 150;
const LIVING_DOCS = { readme: "README.md", handoff: ".docs/status/handoff.md", progress: ".docs/status/progress.md", roadmap: ".docs/status/roadmap.md" };
// Structural contract for the living documents; prose ownership stays a human review.
function validateLivingDocs(markdownParser) {
  const texts = {};
  for (const [key, relative] of Object.entries(LIVING_DOCS)) {
    texts[key] = readText(relative);
    if (texts[key] === null && !fs.existsSync(path.join(root, relative))) ruleReport(relative, "living-doc-missing", "required living document is missing");
  }
  const markers = [];
  for (const [key, relative] of Object.entries(LIVING_DOCS)) {
    if (texts[key] === null) continue;
    const found = texts[key].split(/\r?\n/).filter((line) => /^Current milestone:/.test(line));
    const valid = found.length === 1 && /^Current milestone: (M\d+)$/.exec(found[0]);
    if (!valid) { ruleReport(relative, "milestone-marker", `expected exactly one 'Current milestone: M<N>' line, found ${found.length === 1 ? `malformed '${found[0]}'` : found.length}`); continue; }
    markers.push([relative, valid[1]]);
  }
  const milestone = markers.length && markers.every(([, value]) => value === markers[0][1]) ? markers[0][1] : null;
  if (markers.length && !milestone) {
    for (const [relative, value] of markers) ruleReport(relative, "milestone-mismatch", `milestone marker '${value}' does not match across living documents (${markers.map(([name, other]) => `${name}=${other}`).join(", ")})`);
  }
  if (texts.handoff !== null) {
    for (const heading of ["Start here each session", "Where things stand"]) requireHeading(LIVING_DOCS.handoff, texts.handoff, heading, markdownParser);
    const lineCount = texts.handoff.length === 0 ? 0 : texts.handoff.split(/\r?\n/).length - (/\r?\n$/.test(texts.handoff) ? 1 : 0);
    if (lineCount > HANDOFF_LINE_CAP) ruleReport(LIVING_DOCS.handoff, "handoff-size", `handoff has ${lineCount} lines; maximum is ${HANDOFF_LINE_CAP}`);
  }
  if (texts.progress !== null) {
    requireHeading(LIVING_DOCS.progress, texts.progress, "Action history", markdownParser);
    const entries = sectionText(texts.progress, "Action history").split(/\r?\n/).filter((line) => /^\s*-\s/.test(line));
    const standard = /^- \d{4}-\d{2}-\d{2} — \S/;
    if (!entries.length) ruleReport(LIVING_DOCS.progress, "action-history-entry", "Action history needs at least one '- YYYY-MM-DD — <action>' entry");
    for (const entry of entries) if (!standard.test(entry)) ruleReport(LIVING_DOCS.progress, "action-history-entry", `malformed Action history entry '${entry}'`);
  }
  if (texts.roadmap !== null) {
    requireHeading(LIVING_DOCS.roadmap, texts.roadmap, "Repository improvement program (2026)", markdownParser);
    const lines = texts.roadmap.split(/\r?\n/);
    const start = lines.findIndex((line) => /^##\s+Repository improvement program \(2026\)/.test(line));
    const rest = lines.slice(start + 1);
    const end = rest.findIndex((line) => /^##\s/.test(line));
    const program = end < 0 ? rest : rest.slice(0, end);
    const active = program.filter((line) => /^- \[ \] \*\*M\d+\b.*\(in progress\)/.test(line)).map((line) => /^- \[ \] \*\*(M\d+)\b/.exec(line)[1]);
    if (active.length !== 1) ruleReport(LIVING_DOCS.roadmap, "roadmap-in-progress", `expected exactly one unchecked '(in progress)' milestone, found ${active.length}`);
    else if (milestone && active[0] !== milestone) ruleReport(LIVING_DOCS.roadmap, "roadmap-in-progress", `in-progress milestone '${active[0]}' does not match marker '${milestone}'`);
  }
}

function requireHeading(relative, text, heading, markdownParser, label = heading) {
  const wanted = heading.toLowerCase();
  const count = headingTexts(text, markdownParser).filter((entry) => entry === wanted || entry.startsWith(`${wanted} `) || entry.startsWith(`${wanted}:`) || entry.startsWith(`${wanted} (`)).length;
  if (!count) ruleReport(relative, `heading-${slugRule(heading)}`, `missing required heading '${label}'`);
  else if (count > 1 && Object.values(LIVING_DOCS).includes(relative)) ruleReport(relative, `heading-${slugRule(heading)}`, `duplicate required heading '${label}' (${count} occurrences; expected exactly one)`);
}

const statusOf = (relative) => statusField(readText(relative) || "")[0];
const artifactIdentities = () => {
  const found = new Set();
  for (const file of files) {
    const kind = docKind(file);
    if (kind === "plan") found.add(planIdentity(file));
    else if (kind || /^\.docs\/research\/[^/]+\.md$/.test(file)) { const base = path.posix.basename(file, ".md"); found.add(base); found.add(base.replace(/^(?:\d+|\d{4}-\d{2}-\d{2})-/, "")); }
  }
  return found;
};
// Evaluation identification may sit in the header or, for older records, a labelled body line.
function identificationLines(text, name) {
  const header = fieldValues(text, name);
  if (header.length) return header;
  const found = [];
  let fenced = false;
  for (const line of text.split(/\r?\n/)) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    const match = !fenced && line.match(new RegExp(`^\\s*(?:[-*]\\s*)?(?:\\*\\*)?${name}:(?:\\*\\*)?\\s*(.*)$`, "i"));
    if (match) found.push(match[1].trim());
  }
  return found;
}

// The one designated top-level problem document an ADR may ground itself on besides research notes.
const PROBLEM_DOCUMENT = ".docs/repository-improvement-plan.md";
function checkAuthority(relative, kind, text, artifacts, markdownParser) {
  const hrefs = relativeHrefs(text, markdownParser);
  const targets = hrefs.map((href) => resolveHref(relative, href)).filter(Boolean);
  if (kind === "spec") {
    const adrs = relativeHrefs(sectionText(text, "Authority"), markdownParser).map((href) => resolveHref(relative, href)).filter((target) => target && /^\.docs\/ADR\/\d{4}-[^/]+\.md$/.test(target));
    if (!adrs.length) ruleReport(relative, "authority", "Authority section must link at least one existing ADR");
    else if (!adrs.some((target) => statusOf(target) === "Accepted")) ruleReport(relative, "authority", "Authority section must link at least one accepted ADR");
  } else if (kind === "adr") {
    // Grounding is an approved/accepted research note or problem document under .docs/research/, never an arbitrary doc.
    const grounding = targets.filter((target) => (/^\.docs\/research\/[^/]+\.md$/.test(target) || target === PROBLEM_DOCUMENT) && ["Approved", "Accepted"].includes(statusOf(target)));
    const prior = targets.filter((target) => target !== relative && ((/^\.docs\/ADR\//.test(target) && statusOf(target) === "Accepted") || (/^\.docs\/spec\//.test(target) && statusOf(target) === "Approved")));
    if (!grounding.length) ruleReport(relative, "authority", "body must link existing approved research or a problem statement");
    if (!prior.length) ruleReport(relative, "authority", "body must link accepted prior authority (an accepted ADR or approved spec)");
  } else if (kind === "plan") {
    const header = headerLines(text).join("\n");
    const specNames = [...header.matchAll(/\b(\d\d-[a-z0-9-]+\.md)\b/g)].map((match) => match[1]);
    const adrNumbers = [...header.matchAll(/\bADR[ -]?(\d{4})\b/gi)].map((match) => match[1]);
    const identified = new Set(targets.filter((target) => /^\.docs\/(?:spec|ADR)\//.test(target)));
    let unresolved = 0;
    for (const name of specNames) { if (files.includes(`.docs/spec/${name}`)) identified.add(`.docs/spec/${name}`); else unresolved += 1; }
    for (const number of adrNumbers) { const found = files.find((file) => file.startsWith(`.docs/ADR/${number}-`)); if (found) identified.add(found); else unresolved += 1; }
    if (!identified.size && !unresolved) ruleReport(relative, "authority", "plan must identify target specs or accepted ADRs in metadata or body links");
    else if (unresolved) ruleReport(relative, "authority", "plan identifies a spec or ADR that does not exist");
    for (const target of identified) {
      const wanted = target.startsWith(".docs/spec/") ? "Approved" : "Accepted";
      if (statusOf(target) !== wanted) ruleReport(relative, "authority", `plan target ${target} must be ${wanted}, found '${statusOf(target) || "none"}'`);
    }
  }
}

// An evaluation names its artifact (field or filename identity) and links applicable, resolvable authority.
const AUTHORITY_ROOT = /^(?:\.docs\/(?:spec|ADR|research|slice-plans)\/[^\s]+\.md$|plugins\/loom\/skills\/loom-playbook\/references\/[^/]*rubric[^/]*\.md$)/;
function checkEvaluationIdentification(relative, text, identity, markdownParser) {
  const artifactField = identificationLines(text, "Artifact").join(" ");
  const authorityField = identificationLines(text, "Reviewed against").join(" ");
  const identities = artifactIdentities();
  const artifactLinks = relativeHrefs(artifactField, markdownParser);
  const strip = (name) => name.replace(/^(?:\d+|\d{4}-\d{2}-\d{2})-/, "");
  let artifactOk;
  if (artifactLinks.length) {
    // Every link must resolve to the artifact this evaluation is named for, not just any file.
    artifactOk = artifactLinks.every((href) => {
      const target = resolveHref(relative, href);
      if (!target || target.startsWith(".docs/evaluations/")) return false;
      const base = path.posix.basename(target, ".md");
      return [identity, strip(identity)].some((name) => name === planIdentity(target) || name === base || name === strip(base));
    });
  } else artifactOk = identities.has(identity) || identities.has(strip(identity));
  if (!artifactOk) ruleReport(relative, "authority", `evaluation does not identify a resolvable reviewed artifact: ${artifactField || identity}`);
  if (!authorityField) { ruleReport(relative, "authority", "evaluation header must identify the reviewed artifact and authority ('Artifact:' or 'Reviewed against:')"); return; }
  const authorityLinks = relativeHrefs(authorityField, markdownParser);
  const resolved = authorityLinks.map((href) => resolveHref(relative, href));
  if (resolved.some((target) => !target)) { ruleReport(relative, "authority", `evaluation authority links must resolve to local files: ${authorityField}`); return; }
  const adrNumbers = [...authorityField.matchAll(/\bADRs?\s+((?:\d{4}(?:\s*[,/\u2013-]\s*|\s+and\s+)?)+)/gi)].flatMap((match) => match[1].match(/\d{4}/g));
  const missing = adrNumbers.filter((number) => !files.some((file) => file.startsWith(`.docs/ADR/${number}-`)));
  if (missing.length) { ruleReport(relative, "authority", `evaluation authority names an ADR that does not exist: ${missing.join(", ")}`); return; }
  // Bare names count only when they resolve to a real, applicable file.
  const unresolvedNames = [];
  for (const match of authorityField.matchAll(/\bspecs?\s+(\d\d)\b/gi)) if (!files.some((file) => file.startsWith(`.docs/spec/${match[1]}-`))) unresolvedNames.push(`spec ${match[1]}`);
  for (const match of authorityField.matchAll(/(?<![\w/.-])(\d\d-[a-z][a-z0-9-]*\.md)\b/gi)) if (!files.includes(`.docs/spec/${match[1]}`)) unresolvedNames.push(match[1]);
  for (const match of authorityField.matchAll(/\.docs\/slice-plans\/[\w./-]+\.md/gi)) if (!files.includes(match[0]) && !files.includes(match[0].replace("/slice-plans/", "/slice-plans/archive/"))) unresolvedNames.push(match[0]);
  if (unresolvedNames.length) { ruleReport(relative, "authority", `evaluation authority names a file that does not exist: ${unresolvedNames.join(", ")}`); return; }
  // Generic references (slice plan, rubric, research notes) must resolve to the file applicable to this artifact.
  const bare = strip(identity);
  const planEval = /-plan-eval\.md$/.test(relative);
  const hasPlan = [identity, bare].some((name) => files.includes(`.docs/slice-plans/${name}.md`) || files.includes(`.docs/slice-plans/archive/${name}.md`));
  const hasRubric = files.includes(`plugins/loom/skills/loom-playbook/references/${planEval ? "plan" : "code"}-eval-rubric.md`);
  const hasResearch = [identity, bare].some((name) => files.includes(`.docs/research/${name}.md`));
  const generic = [];
  if (/\bslice[- ]plans?\b/i.test(authorityField) && !hasPlan) generic.push("slice plan");
  if (/\brubric\b/i.test(authorityField) && !hasRubric) generic.push("rubric");
  if (/\bresearch notes?\b|\b(?:approved|accepted)\b[^;]*\bresearch\b/i.test(authorityField) && !hasResearch) generic.push("research");
  const named = adrNumbers.length > 0
    || /\bspecs?\s+\d\d\b|(?<![\w/.-])\d\d-[a-z][a-z0-9-]*\.md\b/i.test(authorityField)
    || (/\brepository[- ]improvement[- ]plan\b/i.test(authorityField) && files.includes(PROBLEM_DOCUMENT))
    || (/\bresearch notes?\b|\b(?:approved|accepted)\b[^;]*\bresearch\b/i.test(authorityField) && hasResearch)
    || (/\brubric\b/i.test(authorityField) && hasRubric)
    || (/\bplaybook\b/i.test(authorityField) && files.includes("plugins/loom/skills/loom-playbook/SKILL.md"))
    || (/\bslice[- ]plans?\b/i.test(authorityField) && hasPlan)
    || /\.docs\/slice-plans\/[\w./-]+\.md/i.test(authorityField);
  const codePaths = [...authorityField.matchAll(/`([^`\s]+)`/g)].map((match) => match[1].replace(/^\.\//, "")).filter((candidate) => files.includes(candidate));
  const applicable = resolved.concat(codePaths).filter((target) => AUTHORITY_ROOT.test(target));
  if (!applicable.length && !named) {
    const detail = generic.length ? ` (generic ${generic.join(", ")} reference does not resolve to this artifact's applicable file)` : "";
    ruleReport(relative, "authority", `evaluation authority must reference applicable specs, ADRs, research, plan or rubric: ${authorityField}${detail}`);
  }
}

const evaluationRecords = [];
const NON_MERITS = ["invalid", "infrastructure-blocked"];
function validateEvaluations(markdownParser) {
  const events = new Map();
  for (const relative of files.filter((file) => file.startsWith(".docs/evaluations/"))) {
    const name = relative.slice(".docs/evaluations/".length);
    if (name.includes("/")) { ruleReport(relative, "eval-name", "unexpected nested path under .docs/evaluations"); continue; }
    if (name === "README.md" || name === "macos-dual-client-dogfood-evidence.json") continue;
    if (/^.+-(?:review-findings|acceptance)\.md$/.test(name)) continue;
    const dated = name.match(/^(\d{4})-(\d{2})-(\d{2})-/);
    if (dated && (Number(dated[2]) < 1 || Number(dated[2]) > 12 || Number(dated[3]) < 1 || Number(dated[3]) > 31)) {
      ruleReport(relative, "eval-name", `invalid date prefix '${dated[0]}'`);
      continue;
    }
    const match = name.match(EVALUATION_NAME);
    if (!match) {
      ruleReport(relative, "eval-name", "name is not <artifact>-eval.md, <artifact>-plan-eval.md, a dated form, a companion, or static evidence");
      continue;
    }
    const text = readText(relative);
    if (text === null) continue;
    if (statusField(text).length) ruleReport(relative, "eval-status-field", "evaluation must not carry a 'Status:' field; use Verdict");
    for (const heading of DOC_HEADINGS.evaluation) requireHeading(relative, text, heading, markdownParser);
    checkEvaluationIdentification(relative, text, match[1], markdownParser);
    const rounds = fieldValues(text, "Round");
    const verdicts = fieldValues(text, "Verdict");
    let round;
    if (rounds.length !== 1) ruleReport(relative, "eval-round", `expected exactly one top-level 'Round:' field, found ${rounds.length}`);
    else if (!/^\d+$/.test(rounds[0])) ruleReport(relative, "eval-round", `Round must be a nonnegative decimal integer, found '${rounds[0]}'`);
    else round = Number(rounds[0]);
    if (verdicts.length !== 1) ruleReport(relative, "eval-verdict", `expected exactly one top-level 'Verdict:' field, found ${verdicts.length}`);
    else if (!["PASS", "FAIL"].includes(verdicts[0])) ruleReport(relative, "eval-verdict", `Verdict must be PASS or FAIL, found '${verdicts[0]}'`);
    if (round === undefined || !["PASS", "FAIL"].includes(verdicts[0])) continue;
    const identity = match[1];
    if (!events.has(identity)) events.set(identity, []);
    const runClass = fieldValues(text, "Run-Status")[0];
    if (runClass !== undefined && !NON_MERITS.includes(runClass)) ruleReport(relative, "eval-sequence", `Run-Status must be one of ${NON_MERITS.join(", ")}, found '${runClass}'`);
    const event = { relative, identity, round, verdict: verdicts[0], nonMerits: NON_MERITS.includes(runClass), planEval: Boolean(match[2]), resetText: fieldValues(text, "Owner-Reset").join(" "), commit: (fieldValues(text, "Commit").concat(fieldValues(text, "Reviewed commit"))[0] || "").match(/[0-9a-f]{7,40}/)?.[0] };
    events.get(identity).push(event);
    evaluationRecords.push(event);
  }
  for (const [identity, group] of events) {
    const hasReset = (event) => event.resetText.length > 0;
    // Every recorded reset is validated, wherever it sits in the group.
    for (const event of group.filter(hasReset)) {
      const text = event.resetText;
      const valid = event.round === 0 && text.toLowerCase().includes(identity.toLowerCase())
        && /\bowner\b[^.;]*\b(?:decision|decided|directed|approved)\b|\b(?:decision|decided|directed|approved)\b[^.;]*\bowner\b/i.test(text)
        && /\bmaterially\s+new\s+direction\b/i.test(text) && /\breset\b[^.;]*\b0\b|\b0\b[^.;]*\breset\b/i.test(text);
      event.resetValid = valid;
      if (!valid) ruleReport(event.relative, "eval-sequence", `Owner-Reset must record an owner decision naming '${identity}', a materially new direction and a reset to 0, with Round: 0`);
    }
    if (group.length < 2) {
      if (group[0].round !== 0 && !hasReset(group[0])) ruleReport(group[0].relative, "eval-sequence", `first evaluation of '${identity}' must be Round: 0, found ${group[0].round}`);
      continue;
    }
    for (const event of group) event.sha = eventCommit(event);
    const unordered = group.filter((event) => !event.sha);
    if (unordered.length) {
      for (const event of unordered) ruleReport(event.relative, "eval-sequence", "cannot order evaluations: the recorded reviewed 'Commit:' is missing or not a commit");
      continue;
    }
    const ordered = [...group].sort((left, right) => left.sha === right.sha ? 0 : isAncestor(left.sha, right.sha) ? -1 : isAncestor(right.sha, left.sha) ? 1 : 0);
    if (ordered[0].round !== 0 && !hasReset(ordered[0])) ruleReport(ordered[0].relative, "eval-sequence", `first evaluation of '${identity}' must be Round: 0, found ${ordered[0].round}`);
    for (let index = 1; index < ordered.length; index += 1) {
      const earlier = ordered[index - 1];
      const later = ordered[index];
      if (earlier.sha === later.sha || !isAncestor(earlier.sha, later.sha)) {
        ruleReport(later.relative, "eval-sequence", `ordering is ambiguous against ${earlier.relative}`);
        continue;
      }
      if (hasReset(later)) continue;
      const expected = earlier.verdict === "FAIL" && !earlier.nonMerits ? earlier.round + 1 : earlier.round;
      if (later.round !== expected) ruleReport(later.relative, "eval-sequence", `round ${later.round} follows ${earlier.relative} (round ${earlier.round} ${earlier.verdict}); expected exactly ${expected}, and a reset needs an 'Owner-Reset:' decision`);
    }
  }
}
// Only the recorded reviewed commit orders events; never the commit that added the file.
function eventCommit(event) {
  if (!event.commit) return undefined;
  try { return git(["rev-parse", "--verify", "--quiet", "--end-of-options", `${event.commit}^{commit}`]).trim() || undefined; }
  catch { return undefined; }
}
function isAncestor(left, right) {
  try { git(["merge-base", "--is-ancestor", left, right]); return true; } catch { return false; }
}

function validateBaseline(current) {
  const baseline = new Map();
  let listing = "";
  try { listing = git(["ls-tree", "-r", "--name-only", baselineCommit, "--", ".docs"]); } catch { /* no .docs at baseline */ }
  for (const relative of listing.split("\n").filter((name) => docKind(name))) {
    let text;
    try { text = git(["show", `${baselineCommit}:${relative}`]); } catch { continue; }
    const statuses = statusField(text);
    if (statuses.length !== 1) continue;
    const kind = docKind(relative);
    baseline.set(kind === "plan" ? `plan:${planIdentity(relative)}` : relative, { relative, kind, status: statuses[0], archived: relative.startsWith(".docs/slice-plans/archive/") });
  }
  for (const artifact of current.values()) {
    if (!artifact.status) continue;
    const before = baseline.get(artifact.kind === "plan" ? `plan:${planIdentity(artifact.relative)}` : artifact.relative);
    if (!before) continue;
    const arrow = `${before.relative} '${before.status}' -> ${artifact.relative} '${artifact.status}'`;
    if (before.archived && !artifact.archived) { report(artifact.relative, `baseline: archived plan was reactivated (${arrow})`); continue; }
    if (!before.archived && artifact.archived && !["Landed", "Abandoned"].includes(before.status)) { report(artifact.relative, `baseline: archive rename before landing (${arrow})`); continue; }
    const problem = checkTransitions(before, artifact);
    if (problem === "illegal") report(artifact.relative, `baseline: illegal status transition (${arrow})`);
    else if (problem === "ambiguous") report(artifact.relative, `baseline: ambiguous clarification restoration; the status before Needs Clarification cannot be established (${arrow})`);
    else if (problem === "fail-ambiguous") report(artifact.relative, `baseline: FAIL return evidence cannot be ordered; a matching FAIL evaluation needs a recorded reviewed 'Commit:' at or after the rejected status (${arrow})`);
    else if (problem === "fail-evidence") report(artifact.relative, `baseline: FAIL return without a recorded FAIL evaluation (${arrow})`);
  }
}
function statusAt(sha, relative) {
  try { const statuses = statusField(git(["show", `${sha}:${relative}`])); return statuses.length === 1 ? statuses[0] : undefined; }
  catch { return undefined; }
}
// Statuses (with the commit that first showed each) from the baseline through every commit that touched the artifact.
function statusSequence(before, artifact) {
  let log = "";
  try { log = git(["log", "--reverse", "--format=%H", `${baselineCommit}..HEAD`, "--", before.relative, artifact.relative]); } catch { /* no intermediate history */ }
  const sequence = [{ status: before.status, sha: baselineCommit }];
  for (const sha of log.split("\n").filter(Boolean)) {
    const seen = statusAt(sha, artifact.relative) ?? statusAt(sha, before.relative);
    if (seen) sequence.push({ status: seen, sha });
  }
  sequence.push({ status: artifact.status, sha: undefined });
  return sequence.filter((entry, index) => index === 0 || entry.status !== sequence[index - 1].status);
}
function priorStatus(relative) {
  let log = "";
  try { log = git(["log", "--format=%H", baselineCommit, "--", relative]); } catch { return undefined; }
  for (const sha of log.split("\n").filter(Boolean)) {
    const seen = statusAt(sha, relative);
    if (seen && seen !== "Needs Clarification") return seen;
  }
  return undefined;
}
// A FAIL return needs a merits FAIL of the matching phase, reviewing a commit within the interval from the commit that entered the rejected status to the commit that returned from it.
function failEvidence(artifact, from, to, entered, returned) {
  const base = path.posix.basename(artifact.relative, ".md");
  const names = new Set([planIdentity(artifact.relative), base, base.replace(/^\d+-/, "")]);
  const wantPlanEval = artifact.kind === "plan" ? from === "Plan Review" : undefined;
  const candidates = evaluationRecords.filter((record) => record.verdict === "FAIL" && !record.nonMerits && names.has(record.identity) && (wantPlanEval === undefined || record.planEval === wantPlanEval));
  if (!candidates.length) return "fail-evidence";
  let ambiguous = false;
  for (const record of candidates) {
    const sha = eventCommit(record);
    if (!sha || !entered || !isAncestor(sha, "HEAD")) { ambiguous = true; continue; }
    // Bound the reviewed commit to this rejected-status interval; a later cycle's FAIL cannot justify an earlier return.
    if (isAncestor(entered, sha) && (!returned || isAncestor(sha, returned))) return null;
  }
  return ambiguous ? "fail-ambiguous" : "fail-evidence";
}
function checkTransitions(before, artifact) {
  const sequence = statusSequence(before, artifact);
  let prior = before.status === "Needs Clarification" ? priorStatus(before.relative) : undefined;
  for (let index = 1; index < sequence.length; index += 1) {
    const from = sequence[index - 1].status;
    const to = sequence[index].status;
    const step = legalStep(artifact.kind, from, to, prior);
    if (step === "ambiguous") return "ambiguous";
    if (!step) return "illegal";
    if (to === "Needs Clarification") prior = from;
    if (isFailReturn(artifact.kind, from, to)) {
      const problem = failEvidence(artifact, from, to, sequence[index - 1].sha, sequence[index].sha);
      if (problem) return problem;
    }
  }
  return null;
}

// ---- Packaging (--all): root LICENSE and CHANGELOG ----
const MIT_LICENSE = `MIT License

Copyright (c) 2026 Craig Pfeiffer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
`;
function validatePackaging() {
  const license = readText("LICENSE");
  if (license !== null && license.replace(/\n$/, "") !== MIT_LICENSE.replace(/\n$/, "")) {
    report("LICENSE", "must exactly match the canonical MIT license text with 'Copyright (c) 2026 Craig Pfeiffer'");
  }
  const changelog = readText("CHANGELOG.md");
  if (changelog === null) return;
  const lines = changelog.split(/\r?\n/);
  const outsideFence = [];
  let fence = null;
  for (const line of lines) {
    const marker = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/);
    if (fence === null) {
      if (marker && !(marker[1][0] === "`" && marker[2].includes("`"))) {
        fence = { char: marker[1][0], length: marker[1].length };
        outsideFence.push(false);
      } else outsideFence.push(true);
      continue;
    }
    outsideFence.push(false);
    if (marker && marker[1][0] === fence.char && marker[1].length >= fence.length && marker[2].trim() === "") fence = null;
  }
  const headings = lines.map((line, index) => (outsideFence[index] && line === "## [0.2.0]" ? index : -1)).filter((index) => index >= 0);
  if (headings.length !== 1) { report("CHANGELOG.md", `must contain exactly one '## [0.2.0]' heading (found ${headings.length})`); return; }
  const section = [];
  for (let index = headings[0] + 1; index < lines.length; index++) {
    if (!outsideFence[index]) continue;
    if (/^##\s/.test(lines[index])) break;
    section.push(lines[index]);
  }
  if (!section.some((line) => /^\s*(?:[-*+]|\d+[.)])\s+\S/.test(line))) {
    report("CHANGELOG.md", "'## [0.2.0]' section must contain at least one nonblank Markdown list item");
  }
}

if (mode === "links" || mode === "all") loadAllowlist();
if (mode === "metadata" || mode === "all") await validateMetadata();
if (mode === "links" || mode === "all") await validateLinks();
if (mode === "all") validateDocsState();
if (mode === "all") validatePackaging();
diagnostics.sort().forEach((line) => console.error(line));
if (diagnostics.length) process.exit(1);
console.log(`Repository ${mode} validation passed`);
