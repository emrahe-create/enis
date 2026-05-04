import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { enisBrand } from "../src/brand/enis.brand.js";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "..");
const brandAssetDir = path.join(repoRoot, "assets", "brand");
const brandSourceFile = path.join(repoRoot, "src", "brand", "enis.brand.js");

function readBrandTextFiles() {
  return [
    brandSourceFile,
    path.join(brandAssetDir, "copy.json"),
    path.join(brandAssetDir, "colors.json"),
    path.join(brandAssetDir, "logo-enis.svg")
  ]
    .map((filePath) => fs.readFileSync(filePath, "utf8"))
    .join("\n");
}

function isPng(buffer) {
  return buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
}

test("brand copy contains English and Turkish taglines", () => {
  const copy = JSON.parse(fs.readFileSync(path.join(brandAssetDir, "copy.json"), "utf8"));

  assert.equal(enisBrand.appName, "enis");
  assert.equal(copy.tagline.en, "Say what’s on your mind.");
  assert.equal(copy.tagline.tr, "İçinden geçenleri söyle.");
  assert.equal(enisBrand.tagline.en, copy.tagline.en);
  assert.equal(enisBrand.tagline.tr, copy.tagline.tr);
});

test("brand colors match the Enis palette", () => {
  const colors = JSON.parse(fs.readFileSync(path.join(brandAssetDir, "colors.json"), "utf8"));

  assert.equal(colors.primaryBlue, "#5D8CFF");
  assert.equal(colors.softBlue, "#7CB7FF");
  assert.equal(colors.lavender, "#A78BFA");
  assert.equal(colors.softPurple, "#C084FC");
  assert.equal(colors.deepNavy, "#21184A");
  assert.equal(colors.background, "#F8F7FF");
  assert.equal(colors.white, "#FFFFFF");
});

test("brand assets avoid forbidden copy and references", () => {
  const text = readBrandTextFiles();

  assert.equal(text.includes("Seni dinliyor"), false);
  assert.equal(text.includes("Yanında"), false);
  assert.equal(/\bfriend\b/i.test(text), false);
  assert.equal(/\btherapist\b/i.test(text), false);
  assert.equal(/replacement for human connection/i.test(text), false);
  assert.equal(/\bdependency\b/i.test(text), false);
  assert.equal(/[\u0600-\u06FF]/.test(text), false);
  assert.equal(new RegExp("mas" + "cot", "i").test(text), false);
});

test("brand voice stays supportive and neutral", () => {
  assert.equal(enisBrand.voice.positioning, "supportive but neutral");
  assert.ok(enisBrand.voice.avoid.includes("claims of personal relationship roles"));
  assert.ok(enisBrand.voice.avoid.includes("claims of professional care roles"));
  assert.ok(enisBrand.voice.avoid.includes("claims of replacing human connection"));
  assert.ok(enisBrand.voice.avoid.includes("need-based attachment language"));
});

test("logo and app icon use lowercase enis direction", () => {
  const logo = fs.readFileSync(path.join(brandAssetDir, "logo-enis.svg"), "utf8");
  const appIcon = fs.readFileSync(path.join(brandAssetDir, "app-icon.png"));
  const pngLogo = fs.readFileSync(path.join(brandAssetDir, "logo-enis.png"));

  assert.match(logo, />enis</);
  assert.match(logo, /#5D8CFF/);
  assert.match(logo, /#C084FC/);
  assert.match(logo, /conversation-flow loop mark/);
  assert.equal(enisBrand.assets.logo, "/assets/brand/logo-enis.png");
  assert.equal(enisBrand.assets.appIcon, "/assets/brand/app-icon.png");
  assert.equal(isPng(appIcon), true);
  assert.equal(isPng(pngLogo), true);
});
