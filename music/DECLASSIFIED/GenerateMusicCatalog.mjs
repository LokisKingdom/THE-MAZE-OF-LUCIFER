import fs from "node:fs";
import path from "node:path";
import { albums } from "./src/data/musicCatalog.js";

const json = JSON.stringify(albums, null, 2);

const websiteOutput = path.resolve(
  "./public/musicCatalog.json"
);

// Change this path if your Android project is somewhere else.
const androidOutput = path.resolve(
  "D:/THE NERVOUS SYSTEM/USER_KC/QUOTATIONS FROM BRENDAN S ROSE/BRENDAN'S INFERNAL BIBLE/THE GLOT/THE GULLET/loki/loki/lokis-kingdom/loki/app/src/main/assets/musicCatalog.json"
);

function writeCatalog(outputPath) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, json, "utf8");

  console.log(`Generated: ${outputPath}`);
}

writeCatalog(websiteOutput);
writeCatalog(androidOutput);

const songCount = albums.reduce(
  (total, album) => total + album.songs.length,
  0
);

console.log(`Albums: ${albums.length}`);
console.log(`Songs: ${songCount}`);