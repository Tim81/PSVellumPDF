#!/usr/bin/env python3
"""Dump the public surface (types, methods, fields) of a .NET assembly.

Used to diff VellumPdf releases when planning an engine bump, e.g.:
    pip install dnfile
    python3 tools/Get-VellumPdfApiSurface.py lib/VellumPdf.Layout.dll > layout-new.txt
    comm -3 layout-old.txt layout-new.txt
Member signatures are reduced to name + parameter names; enough to spot
additions/removals, not overload type changes.
"""
import sys, dnfile

def main(path):
    pe = dnfile.dnPE(path)
    md = pe.net.mdtables
    tdefs = md.TypeDef.rows
    nested = {}
    if md.NestedClass:
        for r in md.NestedClass.rows:
            nested[r.NestedClass.row_index] = r.EnclosingClass.row_index
    def fullname(idx):
        t = tdefs[idx - 1]
        n = str(t.TypeName)
        if idx in nested:
            return fullname(nested[idx]) + '+' + n
        ns = str(t.TypeNamespace)
        return (ns + '.' if ns else '') + n
    def visible(idx):
        t = tdefs[idx - 1]
        f = t.Flags
        if idx in nested:
            return (f.tdNestedPublic or f.tdNestedFamily or f.tdNestedFamORAssem) and visible(nested[idx])
        return bool(f.tdPublic)
    params = md.Param.rows if md.Param else []
    out = set()
    for i, t in enumerate(tdefs, 1):
        if not visible(i):
            continue
        tn = fullname(i)
        kind = 'type'
        try:
            ext = t.Extends.row
            en = str(getattr(ext, 'TypeName', ''))
            if en == 'Enum': kind = 'enum'
            elif en == 'ValueType': kind = 'struct'
        except Exception:
            pass
        if t.Flags.tdInterface: kind = 'interface'
        out.add(f'{kind} {tn}')
        for m in t.MethodList:
            m = m.row
            f = m.Flags
            if not (f.mdPublic or f.mdFamily or f.mdFamORAssem):
                continue
            name = str(m.Name)
            pnames = []
            for p in m.ParamList:
                p = p.row
                if p.Sequence > 0:
                    pnames.append(str(p.Name))
            static = 'static ' if f.mdStatic else ''
            out.add(f'  {tn}::{static}{name}({", ".join(pnames)})')
        for fl in t.FieldList:
            fl = fl.row
            ff = fl.Flags
            if not (ff.fdPublic or ff.fdFamily):
                continue
            n = str(fl.Name)
            if n == 'value__': continue
            out.add(f'  {tn}::field {n}')
    for line in sorted(out):
        print(line)

main(sys.argv[1])
