#!/usr/bin/env python3
"""Generate three equivalent exact-path route dispatchers and executable drivers."""
from pathlib import Path
import argparse

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--counts', nargs='+', type=int, default=[5, 50, 500])
args = parser.parse_args()
out = root / 'generated'
out.mkdir(exist_ok=True)
for n in args.counts:
    if not 1 <= n <= 500:
        parser.error('counts must be between 1 and 500')
    for shape in ['list', 'data', 'chain']:
        code = 'import Base\nimport ../shapes.bend as S\nimport ../runtime.bend as R\n\n'
        for i in range(1, n+1):
            code += f'def h{i}(nonce: U32) -> U32:\n  ({i} + nonce : U32)\n\n'
        if shape == 'list':
            routes = ',\n    '.join(f'S.FnRoute{{"/r{i:03}", h{i}}}' for i in range(1, n+1))
            code += f'def routes() -> List<S.FnRoute>:\n  [\n    {routes}\n  ]\n\ndef dispatch(path: String, nonce: U32) -> U32:\n  S.template_list(~routes(), path, nonce)\n'
        elif shape == 'data':
            routes = ',\n    '.join(f'S.Route{{"/r{i:03}", {i}}}' for i in range(1, n+1))
            code += f'def routes() -> List<&2, S.Route>:\n  [\n    {routes}\n  ]\n\n'
            # Runtime table is built once by the driver, then shared across requests.
            code += 'def invoke_pure(tag: U32, nonce: U32) -> U32:\n  match tag:\n'
            for i in range(1, n+1):
                code += f'    case {i}:\n      h{i}(nonce)\n'
            code += '    case _:\n      0\n\n'
            code += 'def dispatch_with(+table: List<&2, S.Route>, path: String, nonce: U32) -> U32:\n  invoke_pure(S.data_walk(table, path), nonce)\n\n'
            code += 'def dispatch(path: String, nonce: U32) -> U32:\n  dispatch_with(routes(), path, nonce)\n'
        else:
            for i in range(n, 0, -1):
                nxt = 'S.missing' if i == n else f'c{i+1}'
                code += f'def c{i}(path: String, nonce: U32) -> U32:\n  S.chain(~h{i}, ~{nxt}, "/r{i:03}", path, nonce)\n\n'
            code += 'def dispatch(path: String, nonce: U32) -> U32:\n  c1(path, nonce)\n'
        # Full environment reaches each top-level IO handler through the closed app.
        if shape == 'data':
            for i in range(1, n+1):
                code += f'\ndef serve_h{i}(env: R.Env) -> IO(String):\n  R.respond(env, {i})\n'
            code += '\ndef invoke(tag: U32, env: R.Env) -> IO(String):\n  match tag:\n'
            for i in range(1, n+1):
                code += f'    case {i}:\n      serve_h{i}(env)\n'
            code += '    case _:\n      IO.pure(String, "missing")\n'
            code += '\ndef app(env: R.Env, path: String) -> IO(String):\n  R.Env{counter, table, counting} = env\n  +t = table\n  invoke(S.data_walk(t, path), R.Env{counter, t, counting})\n'
        else:
            code += '\ndef app(env: R.Env, path: String) -> IO(String):\n  R.respond(env, dispatch(path, 0))\n'
        # The dispatcher template is closed; the shared table is a runtime argument.
        code += '\ndef bench_dispatch(table: List<&2, S.Route>, path: String, nonce: U32) -> U32:\n  '
        code += 'dispatch_with(table, path, nonce)\n' if shape == 'data' else 'dispatch(path, nonce)\n'
        table = 'routes()' if shape == 'data' else 'Nil{}'
        code += f'\ndef main() -> IO(Unit):\n  R.run(~app, ~bench_dispatch, {table}, {n})\n'
        (out / f'{shape}-{n}.bend').write_text(code)
