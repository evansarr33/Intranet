import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root = resolve(import.meta.dirname, '..');
const server = await readFile(resolve(root, 'work/edge-server.template.ts'), 'utf8');
const routes = await readFile(resolve(root, 'work/edge-routes.template.ts'), 'utf8');
const page = await readFile(resolve(root, 'index.html'), 'utf8');
const styles = await readFile(resolve(root, 'styles.css'), 'utf8');
const app = await readFile(resolve(root, 'app.js'), 'utf8');
const built = server.replace('__PAGE__', JSON.stringify(page)).replace('__STYLES__', JSON.stringify(styles)).replace('__APP__', JSON.stringify(app)).replace('__ROUTES__', routes);
await writeFile(resolve(root, 'supabase/functions/noria/index.ts'), built, 'utf8');
console.log(JSON.stringify({page:page.length,styles:styles.length,app:app.length,output:built.length}));

