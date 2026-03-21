#!/usr/bin/env node
/**
 * Strapi v5 TypeScript Compiler Patch
 *
 * Problem: @strapi/typescript-utils only compiles .ts → .js (program.emit())
 * but NEVER copies .json schema files to dist/. Strapi loads content types
 * from dist/src/api/<name>/content-types/<name>/schema.json — if missing,
 * strapi.contentType('api::name.name') returns undefined → crash on startup.
 *
 * This script patches the compiler to also copy JSON files after emit.
 *
 * Usage: node fix-compiler.js
 * Run from: the Strapi project root (where node_modules/ exists)
 */

const path = require('path');
const fs = require('fs');

const COMPILER_PATH = path.resolve(
  process.cwd(),
  'node_modules/@strapi/typescript-utils/lib/compilers/basic.js'
);

if (!fs.existsSync(COMPILER_PATH)) {
  console.error(`❌ Compiler not found at: ${COMPILER_PATH}`);
  console.error('   Make sure you run this from the Strapi project root and npm install is done.');
  process.exit(1);
}

const content = fs.readFileSync(COMPILER_PATH, 'utf8');

// Check if already patched
if (content.includes('copyJsonSchemas')) {
  console.log('✅ Compiler already patched — skipping.');
  process.exit(0);
}

// Find the emit line to inject after
const emitLine = 'program.emit();';
if (!content.includes(emitLine)) {
  console.error('❌ Could not find "program.emit();" in compiler file.');
  console.error('   Strapi version may have changed. Check the file manually:');
  console.error('  ', COMPILER_PATH);
  process.exit(1);
}

const patch = `
// === PATCH: Copy JSON schema files to dist/ after TypeScript compilation ===
(function copyJsonSchemas() {
  const path = require('path');
  const fse = require('fs-extra');
  try {
    const rootDir = compilerOptions.rootDir || path.dirname(tsConfigPath);
    const outDir = compilerOptions.outDir;
    if (!rootDir || !outDir) return;
    const srcDir = path.join(rootDir, 'src');
    const distSrcDir = path.join(outDir, 'src');
    if (!fse.existsSync(srcDir)) return;
    fse.copySync(srcDir, distSrcDir, {
      filter: (src) => {
        try {
          if (fse.statSync(src).isDirectory()) return true;
          return src.endsWith('.json');
        } catch { return false; }
      },
      overwrite: true,
    });
    console.log('[patch] JSON schema files copied to dist/src/');
  } catch (e) {
    // Non-fatal: log but don't crash
    console.warn('[patch] Warning: could not copy JSON schemas:', e.message);
  }
})();
// === END PATCH ===
`;

const patched = content.replace(emitLine, `${emitLine}${patch}`);
fs.writeFileSync(COMPILER_PATH, patched, 'utf8');

console.log('✅ Compiler patched successfully!');
console.log('   JSON schema files will now be copied to dist/ on each compile.');
console.log('');
console.log('📝 Patched file:', COMPILER_PATH);
