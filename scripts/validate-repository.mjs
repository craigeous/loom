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
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--root" && index + 1 < args.length) root = path.resolve(args[++index]);
  else if (["--metadata", "--links", "--all"].includes(args[index]) && !mode) mode = args[index].slice(2);
  else usage(`unknown or repeated argument: ${args[index]}`);
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
const unsafeReports = new Set();
const report = (file, message) => diagnostics.push(`${slash(file)}: ${message}`);

function usage(message) {
  console.error(`validate-repository: ${message}`);
  console.error("usage: validate-repository.mjs [--root PATH] (--metadata|--links|--all)");
  process.exit(2);
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
  try {
    const output = execFileSync("git", ["-C", root, "ls-files", "-z"], { encoding: "buffer", stdio: ["ignore", "pipe", "ignore"] });
    return output.toString("utf8").split("\0").filter(Boolean).sort();
  } catch {
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

async function validateMetadata() {
  let structurallyValid = true;
  for (const relative of files.filter((file) => file.endsWith(".json"))) {
    if (readJson(relative) === JSON_READ_FAILURE) structurallyValid = false;
  }

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
      helperDirectory: "bin", helperDirectoryMustBeDirectChild: true, allowedHelpers: ["loom-coord"],
      helperMustBeRegularFile: true, helperMustBeExecutable: true
    },
    {
      schema: "codex-skill-source/v1", client: "codex", inputMustBeAbsolute: true,
      invocationMustBeAbsolute: true, skillSuffix: "skills/<skill>/SKILL.md", skillMustBeCanonical: true,
      skillMustBeRegularFile: true, skillIdentitySource: "frontmatter.name", skillIdentityMustMatchDirectory: true,
      pluginRootAscent: "../..", pluginRootMustBeCanonical: true, ascendToManifest: ".codex-plugin/plugin.json",
      manifestMustBeCanonical: true, manifestMustBeRegularFile: true, expectedName: "loom", expectedVersion: "0.2.0",
      helperDirectory: "bin", helperDirectoryMustBeDirectChild: true, allowedHelpers: ["loom-coord"],
      helperMustBeRegularFile: true, helperMustBeExecutable: true,
      forbiddenWorkflowRootGuesses: ["CLAUDE_PLUGIN_ROOT", "PLUGIN_ROOT", "CODEX_HOME", "PATH"],
      hookBinding: "PLUGIN_ROOT", hookManifest: "./hooks/hooks.json"
    }
  ];
  for (const [index, binding] of roots.entries()) {
    if (!deepEqual(binding, expectedRoots[index])) report(rootPaths[index], "installed-root contract drift");
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
  const markdown = files.filter((relative) => relative.endsWith(".md") && !relative.startsWith(".docs/evaluations/") && !relative.startsWith(".docs/slice-plans/archive/"));
  const allowlistPath = "scripts/validation/relative-link-allowlist.txt";
  const allowlist = parseAllowlist(allowlistPath);
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
  for (const key of allowlist.keys()) if (!used.has(key)) report(allowlistPath, `stale allowlist record: ${key}`);
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

if (mode === "metadata" || mode === "all") await validateMetadata();
if (mode === "links" || mode === "all") await validateLinks();
diagnostics.sort().forEach((line) => console.error(line));
if (diagnostics.length) process.exit(1);
console.log(`Repository ${mode} validation passed`);
