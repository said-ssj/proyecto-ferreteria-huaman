import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const rawOrigin = process.env.BACKEND_ORIGIN?.trim();
let backend;
try {
  backend = new URL(rawOrigin);
} catch {
  console.error('Configura BACKEND_ORIGIN con la URL HTTPS pública de Render.');
  process.exit(1);
}

if (backend.protocol !== 'https:' || backend.username || backend.password
    || backend.pathname !== '/' || backend.search || backend.hash) {
  console.error('BACKEND_ORIGIN debe contener solo el origen HTTPS, sin /api, credenciales ni parámetros.');
  process.exit(1);
}

const cli = fileURLToPath(new URL('../node_modules/@angular/cli/bin/ng.js', import.meta.url));
const build = spawnSync(process.execPath, [
  cli, 'build', '--configuration=production',
  '--define', '__DEPLOY_API_ORIGIN__=' + JSON.stringify(backend.origin),
], { stdio: 'inherit' });

if (build.error) console.error(build.error.message);
process.exit(build.status ?? 1);
