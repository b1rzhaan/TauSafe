import { build } from 'esbuild';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const here = path.dirname(fileURLToPath(import.meta.url));
// Catalog and application must not mix schemas after a preview refresh.
const catalog = readFileSync(path.join(here, '../assets/data/places.json'));
const catalogName = 'places_' + createHash('sha256').update(catalog).digest('hex').slice(0, 10) + '.json';
writeFileSync(path.join(here, '../assets/data', catalogName), catalog);
const stateFile = path.join(here, '../lib/core/app_state.dart');
writeFileSync(stateFile, readFileSync(stateFile, 'utf8').replace(/assets\/data\/places(?:_[a-f0-9]+)?\.json/g, 'assets/data/' + catalogName));
const result = await build({
  absWorkingDir: here,
  stdin: { contents: readFileSync(path.join(here, 'viewer.js'), 'utf8'), sourcefile: 'viewer.js', resolveDir: here },
  outfile: 'viewer.bundle.js',
  write: false,
  bundle: true,
  minify: true,
  format: 'iife',
  logLevel: 'info',
  plugins: [{name:'workspace-resolver',setup(b){
    b.onResolve({filter:/.*/},args=>{
      if(args.path.startsWith('.'))return {path:path.resolve(args.resolveDir,args.path),namespace:'workspace'};
      if(args.path.startsWith('node:'))return {path:args.path,external:true};
      return {path:fileURLToPath(import.meta.resolve(args.path)),namespace:'workspace'};
    });
    b.onLoad({filter:/.*/,namespace:'workspace'},args=>({contents:readFileSync(args.path),loader:args.path.endsWith('.json')?'json':'js',resolveDir:path.dirname(args.path)}));
  }}],
});
writeFileSync(path.join(here,'..','assets','viewer','viewer.js'),result.outputFiles[0].contents);
