// Generates public/robots.txt and public/sitemap.xml for the static export.
//
// Runs before `expo export` (see the `build` script). The site is fully static and every
// route maps to a known URL: the handful of top-level pages plus one page per markdown
// file in content/docs. We enumerate the same content the app renders so the sitemap can
// never drift from what actually ships.
//
//   node scripts/generate-sitemap.mjs
//
// The absolute origin comes from EXPO_PUBLIC_SITE_URL (the same var Seo.tsx reads) and
// defaults to the production domain.

import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.resolve(here, "..");
const docsDir = path.join(appDir, "content/docs");
const publicDir = path.join(appDir, "public");

const SITE_URL = (process.env.EXPO_PUBLIC_SITE_URL || "https://companionapp.cloud").replace(/\/+$/, "");

// Top-level routes under app/ that aren't data-driven. `/docs/[slug]` is expanded below,
// and +html / +not-found / _layout aren't real pages.
const STATIC_ROUTES = [
  { path: "/", priority: "1.0", changefreq: "weekly" },
  { path: "/docs", priority: "0.9", changefreq: "weekly" },
  { path: "/contact", priority: "0.5", changefreq: "yearly" },
  { path: "/privacy", priority: "0.3", changefreq: "yearly" },
  { path: "/terms", priority: "0.3", changefreq: "yearly" },
];

// Last time a given file changed, per git, as an ISO date. Git may be unavailable (e.g. a
// shallow Docker layer) — fall back to today so lastmod stays present but harmless.
function lastmodFor(file) {
  try {
    const out = execFileSync("git", ["log", "-1", "--format=%cs", "--", file], {
      cwd: appDir,
      encoding: "utf8",
    }).trim();
    if (out) return out;
  } catch {
    // git not available or file untracked
  }
  return new Date().toISOString().slice(0, 10);
}

function docRoutes() {
  return readdirSync(docsDir)
    .filter((f) => f.endsWith(".md"))
    .map((f) => ({
      path: `/docs/${f.replace(/\.md$/, "")}`,
      priority: "0.7",
      changefreq: "monthly",
      lastmod: lastmodFor(path.join(docsDir, f)),
    }));
}

function urlEntry({ path: routePath, priority, changefreq, lastmod }) {
  const loc = SITE_URL + (routePath === "/" ? "/" : routePath);
  return [
    "  <url>",
    `    <loc>${loc}</loc>`,
    lastmod ? `    <lastmod>${lastmod}</lastmod>` : null,
    `    <changefreq>${changefreq}</changefreq>`,
    `    <priority>${priority}</priority>`,
    "  </url>",
  ]
    .filter(Boolean)
    .join("\n");
}

function main() {
  const routes = [...STATIC_ROUTES, ...docRoutes()];

  const sitemap = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...routes.map(urlEntry),
    "</urlset>",
    "",
  ].join("\n");

  const robots = [
    "User-agent: *",
    "Allow: /",
    "",
    `Sitemap: ${SITE_URL}/sitemap.xml`,
    "",
  ].join("\n");

  writeFileSync(path.join(publicDir, "sitemap.xml"), sitemap);
  writeFileSync(path.join(publicDir, "robots.txt"), robots);

  process.stdout.write(`sitemap: ${routes.length} urls → public/sitemap.xml (origin ${SITE_URL})\n`);
}

main();
