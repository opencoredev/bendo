// Runs stack.test.ts vectors in Node at its default stack size: no
// --stack-size flag and no NODE_OPTIONS. Reads [kind, schema, input] triples
// as JSON on stdin and prints one result (or the thrown error) per vector.
import { readFileSync } from "node:fs";

const [url] = process.argv.slice(2);
const { probe } = await import(url);
const vectors = JSON.parse(readFileSync(0, "utf8"));
const results = vectors.map(([kind, schema, input]) => {
  try {
    return probe(kind, schema, input);
  } catch (error) {
    return `threw: ${String(error).slice(0, 200)}`;
  }
});
process.stdout.write(JSON.stringify(results));
