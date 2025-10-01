const fs = require("fs");
const { createCanvas } = require("canvas");

// Create 32x32 canvas
const size = 32;
const canvas = createCanvas(size, size);
const ctx = canvas.getContext("2d");

// Fill background with purple (#8a5cdb)
ctx.fillStyle = "#8a5cdb";
ctx.fillRect(0, 0, size, size);

// Optional: Draw initials or icon in white
ctx.fillStyle = "#fff";
ctx.font = "bold 20px sans-serif";
ctx.textAlign = "center";
ctx.textBaseline = "middle";
ctx.fillText("JS", size / 2, size / 2);

// Save as PNG first
const buffer = canvas.toBuffer("image/png");
fs.writeFileSync("favicon.png", buffer);
console.log("favicon.png created!");
