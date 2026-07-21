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
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === "--root" && i + 1 < args.length) root = path.resolve(args[++i]);
  else if (["--metadata", "--links", "--all"].includes(args[i]) && !mode) mode = args[i].slice(2);
  else usage(`unknown or repeated argument: ${args[i]}`);
}
if (!mode) usage("exactly one of --metadata, --links, or --all is required");
if (!root) {
  try {
    root = execFileSync("git", ["-C", SCRIPT_DIR, "rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
  } catch {
    usage("cannot resolve Git root; pass --root");
  }
}
root = fs.realpathSync(root);

const diagnostics = [];
const report = (file, message) => diagnostics.push(`${slash(file)}: ${message}`);
const absolute = (relative) => path.join(root, relative);
const exists = (relative) => fs.existsSync(absolute(relative));

function usage(message) {
  console.error(`validate-repository: ${message}`);
  console.error("usage: validate-repository.mjs [--root PATH] (--metadata|--links|--all)");
  process.exit(2);
}
function slash(value) { return value.split(path.sep).join("/"); }
function isInside(parent, child) {
  const rel = path.relative(parent, child);
  return rel === "" || (!rel.startsWith(`..${path.sep}`) && rel !== "..");
}
function discover() {
  try {
    const output = execFileSync("git", ["-C", root, "ls-files", "-z"], { encoding: "buffer", stdio: ["ignore", "pipe", "ignore"] });
    return output.toString("utf8").split("\0").filter(Boolean).sort();
  } catch {
    const found = [];
    const walk = (dir) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
        if (entry.name === ".git" || entry.name === ".check-cache" || entry.name === "node_modules") continue;
        const full = path.join(dir, entry.name);
        const rel = slash(path.relative(root, full));
        const stat = fs.lstatSync(full);
        if (stat.isSymbolicLink()) { found.push(rel); continue; }
        if (stat.isDirectory()) walk(full);
        else if (stat.isFile()) found.push(rel);
      }
    };
    walk(root);
    return found.sort();
  }
}

const files = discover();
const fileSet = new Set(files);
const json = new Map();
function readJson(relative) {
  if (json.has(relative)) return json.get(relative);
  try {
    const value = JSON.parse(fs.readFileSync(absolute(relative), "utf8"));
    json.set(relative, value);
    return value;
  } catch (error) {
    report(relative, `invalid JSON: ${error.message}`);
    json.set(relative, null);
    return null;
  }
}
function deepEqual(a, b) { return JSON.stringify(a) === JSON.stringify(b); }

async function validateMetadata() {
  for (const relative of files.filter((f) => f.endsWith(".json"))) readJson(relative);

  const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
  addFormats(ajv);
  const schemaFiles = files.filter((f) => f.endsWith(".schema.json"));
  for (const relative of schemaFiles) {
    const schema = readJson(relative);
    if (!schema) continue;
    try { ajv.addSchema(schema); }
    catch (error) { report(relative, `invalid JSON Schema: ${error.message}`); }
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
  for (const [target, schemaPath] of schemaBindings) validateJson(target, schemaPath, ajv);

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
    validateJson(fixture, schemaPath, ajv);
    const left = readJson(fixture); const right = readJson(live);
    if (left && right && !deepEqual(left, right)) report(fixture, `release fixture differs from ${live}`);
  }

  const frontmatter = [
    [/^plugins\/loom\/commands\/[^/]+\.md$/, "scripts/schemas/command-frontmatter-v1.schema.json"],
    [/^plugins\/loom\/agents\/[^/]+\.md$/, "scripts/schemas/agent-frontmatter-v1.schema.json"],
    [/^plugins\/loom\/skills\/.+\/SKILL\.md$/, "scripts/schemas/skill-frontmatter-v1.schema.json"]
  ];
  const names = { command: new Map(), agent: new Map(), skill: new Map() };
  for (const relative of files) {
    const matched = frontmatter.find(([pattern]) => pattern.test(relative));
    if (!matched) continue;
    const value = parseFrontmatter(relative);
    if (!value) continue;
    validateValue(relative, value, matched[1], ajv);
    const kind = relative.includes("/commands/") ? "command" : relative.includes("/agents/") ? "agent" : "skill";
    const componentName = value.name || (kind === "command" ? path.basename(relative, ".md") : undefined);
    if (componentName) {
      if (names[kind].has(componentName)) report(relative, `duplicate ${kind} name '${componentName}' (also ${names[kind].get(componentName)})`);
      else names[kind].set(componentName, relative);
    }
  }
  semanticMetadata();
}

function validateJson(target, schemaPath, ajv) {
  if (!exists(target)) { report(target, "required file is missing"); return; }
  if (!exists(schemaPath)) { report(target, `schema reference is missing: ${schemaPath}`); return; }
  const value = readJson(target); const schema = readJson(schemaPath);
  if (!value || !schema) return;
  validateValue(target, value, schemaPath, ajv);
}
function validateValue(target, value, schemaPath, ajv) {
  let validator;
  try { validator = ajv.getSchema(readJson(schemaPath)?.$id) || ajv.compile(readJson(schemaPath)); }
  catch (error) { report(schemaPath, `invalid JSON Schema: ${error.message}`); return; }
  if (!validator(value)) {
    for (const error of validator.errors || []) report(target, `schema ${error.instancePath || "/"} ${error.message}`);
  }
}
function parseFrontmatter(relative) {
  const text = fs.readFileSync(absolute(relative), "utf8");
  if (!text.startsWith("---\n")) { report(relative, "missing YAML frontmatter"); return null; }
  const end = text.indexOf("\n---\n", 4);
  if (end < 0) { report(relative, "unterminated YAML frontmatter"); return null; }
  try {
    const document = YAML.parseDocument(text.slice(4, end), { uniqueKeys: true });
    if (document.errors.length) throw document.errors[0];
    const value = document.toJSON();
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("frontmatter must be a mapping");
    return value;
  } catch (error) { report(relative, `invalid YAML frontmatter: ${error.message}`); return null; }
}
function semanticMetadata() {
  const cm = readJson("plugins/loom/.claude-plugin/plugin.json");
  const xm = readJson("plugins/loom/.codex-plugin/plugin.json");
  const cc = readJson(".claude-plugin/marketplace.json");
  const xc = readJson(".agents/plugins/marketplace.json");
  const matrix = readJson("plugins/loom/adapters/compatibility/v0.2.0.json");
  const roots = [readJson("plugins/loom/adapters/roots/claude-plugin-root-v1.json"), readJson("plugins/loom/adapters/roots/codex-skill-source-v1.json")];
  for (const [relative, value] of [["plugins/loom/.claude-plugin/plugin.json", cm], ["plugins/loom/.codex-plugin/plugin.json", xm]]) {
    if (value && (value.name !== "loom" || value.version !== "0.2.0" || value.license !== "MIT" || value.repository !== "https://github.com/craigeous/loom")) report(relative, "product name, exact SemVer, license, or repository identity drift");
  }
  if (cm && xm && (cm.name !== xm.name || cm.version !== xm.version || cm.description !== xm.description || cm.license !== xm.license || cm.repository !== xm.repository)) report("plugins/loom/.codex-plugin/plugin.json", "manifest identity differs from Claude manifest");
  for (const [relative, catalog, requireVersion] of [[".claude-plugin/marketplace.json", cc, true], [".agents/plugins/marketplace.json", xc, false]]) {
    if (!catalog) continue;
    const entries = catalog.plugins || [];
    if (new Set(entries.map((entry) => entry.name)).size !== entries.length) report(relative, "duplicate catalog component name");
    const entry = entries.find((candidate) => candidate.name === "loom");
    if (!entry) report(relative, "catalog is missing loom client manifest");
    else {
      if (entry.source !== "./plugins/loom") report(relative, "catalog source identity drift");
      if (requireVersion && entry.version !== "0.2.0") report(relative, "catalog release provenance drift");
      validateCatalogSource(relative, entry.source);
    }
  }
  if (matrix) {
    if (!deepEqual(matrix.clientFloors, { claude: "2.1.216", codex: "0.144.6" })) report("plugins/loom/adapters/compatibility/v0.2.0.json", "client floor drift");
    const expectedProfiles = [
      { profile: "Economy", consumers: ["researcher"], claude: { selector: "haiku" }, codex: { model: "gpt-5.6-terra", effort: "low" } },
      { profile: "Standard", consumers: ["developer", "orchestrator"], claude: { selector: "sonnet" }, codex: { model: "gpt-5.6", effort: "medium" } },
      { profile: "Deep review", consumers: ["planner", "plan evaluator", "code evaluator"], claude: { selector: "opus" }, codex: { model: "gpt-5.6", effort: "high" } }
    ];
    if (!deepEqual(matrix.profiles, expectedProfiles)) report("plugins/loom/adapters/compatibility/v0.2.0.json", "profile mapping drift");
    for (const binding of matrix.rootBindings || []) {
      if (!fileSet.has(binding.path) && !exists(binding.path)) report("plugins/loom/adapters/compatibility/v0.2.0.json", `root binding reference is missing: ${binding.path}`);
      else if (readJson(binding.path)?.schema !== binding.id) report(binding.path, `binding-reference drift from ${binding.id}`);
    }
  }
  for (const [index, binding] of roots.entries()) {
    if (binding && (binding.expectedName !== "loom" || binding.expectedVersion !== "0.2.0")) report(index ? "plugins/loom/adapters/roots/codex-skill-source-v1.json" : "plugins/loom/adapters/roots/claude-plugin-root-v1.json", "root binding manifest identity drift");
  }
}
function validateCatalogSource(catalogPath, source) {
  if (typeof source !== "string") return;
  const lexical = path.resolve(root, source);
  if (!isInside(root, lexical)) { report(catalogPath, `catalog source escapes repository: ${source}`); return; }
  try {
    if (fs.lstatSync(lexical).isSymbolicLink()) { report(catalogPath, `catalog source is a symlink: ${source}`); return; }
    const physical = fs.realpathSync(lexical);
    const expected = fs.realpathSync(absolute("plugins/loom"));
    if (!isInside(root, physical)) report(catalogPath, `catalog source symlink escapes repository: ${source}`);
    else if (physical !== expected) report(catalogPath, `catalog source resolves to different physical plugin root: ${source}`);
  } catch (error) { report(catalogPath, `catalog source cannot resolve: ${source} (${error.code || error.message})`); }
}

async function validateLinks() {
  const md = new MarkdownIt({ html: false, linkify: false });
  const markdown = files.filter((relative) => relative.endsWith(".md") && !relative.startsWith(".docs/evaluations/") && !relative.startsWith(".docs/slice-plans/archive/"));
  const allowlistPath = "scripts/validation/relative-link-allowlist.txt";
  const allowlist = parseAllowlist(allowlistPath);
  const used = new Set();
  for (const source of markdown) {
    const tokens = md.parse(fs.readFileSync(absolute(source), "utf8"), {});
    for (const token of tokens) {
      if (token.type !== "inline" || !token.children) continue;
      for (const child of token.children) {
        if (child.type !== "link_open") continue;
        const target = child.attrGet("href");
        if (!target || /^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith("//")) continue;
        const error = checkLink(source, target, md);
        if (!error) continue;
        const key = `${source}\t${target}`;
        if (allowlist.has(key)) used.add(key);
        else report(source, `${error}: ${target}`);
      }
    }
  }
  for (const key of allowlist.keys()) if (!used.has(key)) report(allowlistPath, `stale allowlist record: ${key}`);
}
function parseAllowlist(relative) {
  const records = new Map();
  if (!exists(relative)) { report(relative, "allowlist file is missing"); return records; }
  const lines = fs.readFileSync(absolute(relative), "utf8").split(/\r?\n/);
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
function checkLink(source, target, md) {
  const hash = target.indexOf("#");
  const rawPath = hash < 0 ? target : target.slice(0, hash);
  const rawFragment = hash < 0 ? "" : target.slice(hash + 1);
  let decodedPath; let fragment;
  try { decodedPath = decodeURIComponent(rawPath); fragment = decodeURIComponent(rawFragment); }
  catch { return "malformed percent encoding in link"; }
  const resolved = decodedPath ? path.resolve(path.dirname(absolute(source)), decodedPath) : absolute(source);
  if (!isInside(root, resolved)) return "relative link escapes repository";
  let stat;
  try { stat = fs.statSync(resolved); } catch { return "missing relative-link target"; }
  let targetFile = resolved;
  if (stat.isDirectory()) return fragment ? "fragment target is a directory" : null;
  if (!fs.existsSync(targetFile) || !fs.statSync(targetFile).isFile()) return "missing relative-link target";
  if (!fragment) return null;
  if (path.extname(targetFile).toLowerCase() !== ".md") return "fragment target is not Markdown";
  const slugs = headingSlugs(fs.readFileSync(targetFile, "utf8"), md);
  if (!slugs.has(fragment)) return "missing Markdown fragment";
  return null;
}
function headingSlugs(text, md) {
  const result = new Set(); const slugger = new GithubSlugger(); const tokens = md.parse(text, {});
  for (let index = 0; index < tokens.length - 1; index += 1) if (tokens[index].type === "heading_open" && tokens[index + 1].type === "inline") result.add(slugger.slug(tokens[index + 1].content));
  return result;
}

if (mode === "metadata" || mode === "all") await validateMetadata();
if (mode === "links" || mode === "all") await validateLinks();
diagnostics.sort().forEach((line) => console.error(line));
if (diagnostics.length) process.exit(1);
console.log(`Repository ${mode} validation passed`);
