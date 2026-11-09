import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const SHIMS = {
  '@ohos/hypium': new URL('./hy-shim.mjs', import.meta.url).href,
  '@ohos/app.ability.Want': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos/app.ability.UIAbility': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.window': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.app.form.formBindingData': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.app.form.formProvider': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.app.form.FormExtensionAbility': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.app.form.formInfo': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.data.preferences': new URL('./shims-sdk.mjs', import.meta.url).href,
  '@ohos.data.relationalStore': new URL('./shims-sdk.mjs', import.meta.url).href,
};

export async function resolve(spec, ctx, next) {
  if (SHIMS[spec]) return { url: SHIMS[spec], format: 'module', shortCircuit: true };
  if (spec.startsWith('.')) {
    let p = spec;
    if (!/\.(ets|ts|mjs|js|json)$/.test(p)) p += '.ets';
    const url = new URL(p, ctx.parentURL);
    return { url: url.href, format: 'module', shortCircuit: true };
  }
  return next(spec, ctx);
}

const SHIMS_DIR = path.dirname(fileURLToPath(import.meta.url)) + '/shims/';
const SDK_SHIMS = JSON.parse(
  (await import('node:fs')).readFileSync(SHIMS_DIR + 'manifest.json', 'utf8'));

function rewriteSpecifiers(src) {
  // Real ArkTS uses dot-form specifiers (@ohos.app.ability.Want) which Node's
  // package-name parser rejects before the resolve hook runs. Rewrite quoted
  // specifiers to absolute file URLs of per-module shims.
  return src.replace(/(['"])(@ohos\.[A-Za-z0-9.]+)\1/g, (m, q, spec) => {
    const f = SDK_SHIMS[spec];
    return f ? q + pathToFileURL(SHIMS_DIR + f).href + q : m;
  });
}

export async function load(url, ctx, next) {
  if (url.endsWith('.ets') || url.endsWith('.ts')) {
    const raw = await readFile(fileURLToPath(url), 'utf8');
    const stripped = stripTypeScriptTypes(rewriteSpecifiers(raw), { mode: 'strip', sourceUrl: url });
    return { format: 'module', source: stripped, shortCircuit: true };
  }
  return next(url, ctx);
}
