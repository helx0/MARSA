#!/usr/bin/env python3
"""Offline structural validation. Does not compile Dart, execute SQL, or build Android.
Requires PyYAML and Pygments on the verifier workstation.
"""
from pathlib import Path
import sys
import tomllib
import xml.etree.ElementTree as ET
import yaml
from pygments import lex
from pygments.lexers import DartLexer
from pygments.token import Token

ROOT=Path(__file__).resolve().parents[1]

with (ROOT/'supabase/config.toml').open('rb') as f:
    config=tomllib.load(f)
assert config['db']['major_version']==15
print('PASS: Supabase TOML syntactically valid (NOT applied)')

for file in (ROOT/'android').rglob('*.xml'):
    ET.parse(file)
print('PASS: Android XML syntactically valid (NOT Android resource compilation)')

with (ROOT/'pubspec.yaml').open(encoding='utf-8') as f:
    pubspec=yaml.safe_load(f)
assert pubspec['name']=='marsa' and 'flutter' in pubspec['dependencies']
print('PASS: pubspec YAML parses (NOT dependency resolution)')

pairs={')':'(', ']':'[', '}':'{'}
files=sorted((ROOT/'lib').rglob('*.dart')) + sorted((ROOT/'test').rglob('*.dart')) + sorted((ROOT/'integration_test').rglob('*.dart'))
for dart in files:
    stack=[]
    for kind,part in lex(dart.read_text(encoding='utf-8'), DartLexer()):
        if kind not in Token.Punctuation:
            continue
        for c in part:
            if c in '([{':
                stack.append(c)
            elif c in ')]}':
                assert stack and stack.pop()==pairs[c], f'{dart}: unmatched {c}'
    assert not stack, f'{dart}: {len(stack)} unmatched open delimiters'
print(f'PASS: Dart punctuation tokens have balanced brackets across {len(files)} files (NOT Dart analyzer)')

sqlfiles=sorted((ROOT/'supabase/migrations').glob('*.sql'))
assert len(sqlfiles)>=10
for sql in sqlfiles:
    text=sql.read_text()
    assert text.count('$$')%2==0, f'{sql}: unpaired plpgsql dollar quote'
print(f'PASS: PL/pgSQL $$ delimiters paired in {len(sqlfiles)} migration files (NOT SQL execution)')
