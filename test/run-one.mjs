import { register } from 'node:module';
register('./loader.mjs', import.meta.url);
const name = process.argv[2];
if (!name) { console.error('usage: node test/run-one.mjs <Suite.test.ets>'); process.exit(2); }
const mod = await import(new URL('../entry/src/test/' + name, import.meta.url).href);
if (typeof mod.default === 'function') mod.default();
