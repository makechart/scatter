scale-pr = (opt = {}) ->
  domain-vals = []
  range-vals = [0, 1]
  do-clamp = if opt.clamp? then !!opt.clamp else false
  tie-method = opt.tie or 'min'  # 'min' | 'max' | 'average'

  sorted = []
  counts = []
  cumulative = []
  total = 0

  rescale = ->
    if !(domain-vals? and domain-vals.length > 0)
      sorted := []
      counts := []
      cumulative := []
      total := 0
      return

    m = new Map
    for v in domain-vals
      m.set v, (m.get(v) or 0) + 1

    sorted := [...m.keys!]sort (a, b) -> a - b
    counts := sorted.map (v) -> m.get v

    cumulative := []
    s = 0
    for c in counts
      s += c
      cumulative.push s

    total := s

  # helper to get rank position for a value at index using tie-method
  get-rank-pos = (idx) ->
    switch tie-method
    | 'min' =>
        if idx is 0 then 0 else cumulative[idx - 1]
    | 'max' =>
        cumulative[idx] - 1
    | 'average' =>
        first = if idx is 0 then 0 else cumulative[idx - 1]
        last = cumulative[idx] - 1
        (first + last) / 2
    | otherwise =>
        if idx is 0 then 0 else cumulative[idx - 1]

  rank-of = (x) ->
    if sorted.length is 0 => return 0
    if total <= 1 => return 0

    lo = 0
    hi = sorted.length - 1

    while lo <= hi
      mid = (lo + hi) .>>>. 1
      if sorted[mid] < x
        lo = mid + 1
      else
        hi = mid - 1

    pos = lo

    ci = if sorted[pos] is x
      # exact match
      get-rank-pos pos
    else if pos is 0
      # extrapolate below min using first two values
      if sorted.length < 2
        0
      else
        v0 = sorted[0]
        v1 = sorted[1]
        c0 = 0
        c1 = counts[0]
        slope = (c1 - c0) / (v1 - v0)
        c0 + (x - v0) * slope
    else if pos >= sorted.length
      # extrapolate above max using last two values
      v0 = sorted[sorted.length - 2]
      v1 = sorted[sorted.length - 1]
      c0 = cumulative[sorted.length - 2] - 1
      c1 = cumulative[sorted.length - 1] - 1
      slope = (c1 - c0) / (v1 - v0)
      c1 + (x - v1) * slope
    else
      # interpolate between sorted[pos-1] and sorted[pos]
      v0 = sorted[pos - 1]
      v1 = sorted[pos]
      c0 = get-rank-pos (pos - 1)
      c1 = get-rank-pos pos
      t = (x - v0) / (v1 - v0)
      c0 + (c1 - c0) * t

    pr = (ci / (total - 1)) * 100

    if do-clamp
      if pr < 0 then pr = 0
      if pr > 100 then pr = 100

    return pr

  scale = (x) ->
    pr = rank-of x
    t = pr / 100
    a = range-vals[0]
    b = range-vals[1]
    return a * (1 - t) + b * t

  scale.invert = (px) ->
    if sorted.length is 0 => return undefined

    a = range-vals[0]
    b = range-vals[1]

    if a is b => return sorted[0]

    t = (px - a) / (b - a)

    if do-clamp
      if t < 0 then t = 0
      if t > 1 then t = 1

    target = t * (total - 1)

    for i from 0 til cumulative.length
      if cumulative[i] > target
        return sorted[i]

    return sorted[sorted.length - 1]

  scale.domain = (v) ->
    if !v? => return domain-vals
    domain-vals := v.slice!
    rescale!
    return scale

  scale.range = (v) ->
    if !v? => return range-vals
    range-vals := v.slice!
    return scale

  scale.clamp = (v) ->
    if !v? => return do-clamp
    do-clamp := !!v
    return scale

  scale.tie = (v) ->
    if !v? => return tie-method
    tie-method := v
    return scale

  scale.ticks = (count = 10) ->
    if sorted.length is 0 => return []

    min = sorted[0]
    max = sorted[sorted.length - 1]

    if min is max => return [min]

    span = max - min
    step = Math.pow 10, Math.floor(Math.log10(span / count))

    # adjust step to nice values: 1, 2, 5, 10, ...
    err = count / (span / step)
    if err >= 9.5 then step *= 10
    else if err >= 4.5 then step *= 5
    else if err >= 1.9 then step *= 2

    start = Math.ceil(min / step) * step
    stop = Math.floor(max / step) * step

    ticks = []
    i = start
    while i <= stop
      ticks.push i
      i += step

    return ticks

  scale._debug = ->
    { sorted, counts, cumulative, total, do-clamp, 'tie-method': tie-method }

  return scale

module.exports = scale-pr
