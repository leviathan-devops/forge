#!/usr/bin/env node
/**
 * generate-icon.mjs — FORGE app icon generator
 * 
 * Creates a 1024×1024 app icon:
 *   - Background: #0A0A0F (near-black)
 *   - Letter "F": #E04307 (forge fire orange)
 *   - Style: bold, flat, centered
 * 
 * Usage: node scripts/generate-icon.mjs
 * Output: iOS/FORGE/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
 * 
 * Requirements: npm install sharp (or use canvas alternative)
 */

import sharp from 'sharp';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

const SIZE = 1024;
const BG = { r: 0x0A, g: 0x0A, b: 0x0F };       // #0A0A0F near-black
const FG = { r: 0xE0, g: 0x43, b: 0x07 };       // #E04307 forge orange

// SVG template — bold "F" centered, no rounding (iOS handles masking)
const svg = `<svg width="${SIZE}" height="${SIZE}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${SIZE}" height="${SIZE}" fill="rgb(${BG.r},${BG.g},${BG.b})"/>
  <text x="50%" y="50%" 
        font-family="Helvetica-Bold, Arial Black, sans-serif"
        font-size="680" 
        font-weight="900"
        fill="rgb(${FG.r},${FG.g},${FG.b})"
        text-anchor="middle"
        dominant-baseline="central"
        dy="20">F</text>
</svg>`;

const outputPath = join(projectRoot, 'iOS/FORGE/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png');

// Ensure directory exists
mkdirSync(dirname(outputPath), { recursive: true });

// Render SVG to PNG
sharp(Buffer.from(svg))
  .png()
  .toFile(outputPath)
  .then(() => {
    console.log(`✓ Icon generated: ${outputPath} (${SIZE}×${SIZE})`);
    console.log(`  Background: #0A0A0F`);
    console.log(`  Foreground: #E04307 (forge orange F)`);
  })
  .catch(err => {
    console.error('✗ Failed to generate icon:', err.message);
    console.error('  Install sharp: npm install sharp');
    process.exit(1);
  });
