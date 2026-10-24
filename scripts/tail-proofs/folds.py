# Generates equivalence proofs for right folds rewritten as tail loops over the
# reversed input:  spec(h <> t) = step(h, spec(t)),  impl(xs) = go(rev(xs), base).
# Each fold gets: onto (the spec's fold onto any accumulator), onto_base,
# reverse (the loop reads onto), and equiv.
def fold(f):
    n = f['name']; R = f['res']; L = f['list']; E = f.get('elem')
    pat = f['pat']; rpat = f.get('rpat', pat)  # rpat: pattern rebuilt as a term
    xd = f.get('extra_decl', ''); xa = f.get('extra_args', '')
    xd_ = (', ' + xd) if xd else ''; xa_ = (', ' + xa) if xa else ''
    string = f.get('string', False)
    revgo = (lambda xs, r: 'String.reverse.go(%s, %s)' % (xs, r)) if string else (lambda xs, r: 'List.reverse.go(&2, %s, %s, %s)' % (E, xs, r))
    nil = 'SNil{}' if string else 'Nil{}'
    empty = '""' if string else '[]'
    cons = (lambda h, t: 'SCon{%s, %s}' % (h, t)) if string else (lambda h, t: '%s <> %s' % (h, t))
    step = f['step']  # format with {acc}
    spec = f['spec']; go = f['go']; impl = f['impl']; base = f['base']
    onto = n + '_onto'
    o = []
    o.append('''def %(onto)s(+xs: %(L)s%(xd_)s, acc: %(R)s) -> %(R)s:
  match xs:
    case %(nil)s:
      acc
    case %(patc)s:
      %(stepr)s
''' % dict(onto=onto, L=L, xd_=xd_.replace(', ', ', ', 1), R=R, nil=nil, patc=cons(pat, 't'), stepr=step.format(acc='%s(t%s, acc)' % (onto, xa_))))
    o.append('''def %(n)s_onto_base(+xs: %(L)s%(xdp)s) -> {%(onto)s(xs%(xa_)s, %(base)s) == %(spec)s(xs%(xa_)s) : %(R)s}:
  match xs:
    case %(nil)s:
      {==}
    case %(patc)s:
      Equal.cong(%(R)s, %(R)s, folded => %(stepx)s, %(onto)s(t%(xa_)s, %(base)s), %(spec)s(t%(xa_)s), %(n)s_onto_base(t%(xa_)s))
''' % dict(n=n, L=L, xdp=plus(xd_), onto=onto, xa_=xa_, base=base, spec=spec, R=R, nil=nil, patc=cons(pat, 't'), stepx=step.format(acc='folded')))
    o.append('''def %(n)s_reverse(+xs: %(L)s, +r: %(L)s%(xdp)s, +acc: %(R)s) -> {%(go)s(%(rg)s%(xa_)s, acc) == %(go)s(r%(xa_)s, %(onto)s(xs%(xa_)s, acc)) : %(R)s}:
  match xs:
    case %(nil)s:
      {==}
    case %(patc)s:
      %(n)s_reverse(t, %(rc)s%(xa_)s, acc)
''' % dict(n=n, L=L, xdp=plus(xd_), go=go, rg=revgo('xs', 'r'), xa_=xa_, onto=onto, R=R, nil=nil, patc=cons(pat, 't'), rc=cons(rpat, 'r')))
    o.append('''def %(n)s_equiv(+xs: %(L)s%(xdp)s) -> {%(impl)s(xs%(xa_)s) == %(spec)s(xs%(xa_)s) : %(R)s}:
  Equal.trans(%(R)s, %(impl)s(xs%(xa_)s), %(onto)s(xs%(xa_)s, %(base)s), %(spec)s(xs%(xa_)s), %(n)s_reverse(xs, %(empty)s%(xa_)s, %(base)s), %(n)s_onto_base(xs%(xa_)s))
''' % dict(n=n, L=L, xdp=plus(xd_), impl=impl, xa_=xa_, spec=spec, R=R, onto=onto, base=base, empty=empty))
    return '\n'.join(o)

def plus(xd_):
    return xd_

def module(header, folds):
    return header.rstrip() + '\n\n' + '\n'.join(fold(f) for f in folds)
