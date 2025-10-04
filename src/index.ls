get-label-force = (d3) ->
  # helpers -----------------------------------------------------
  clamp = (v, lo, hi) -> if v < lo then lo else if v > hi then hi else v
  nearest-on-rect = (cx, cy, d) ->
    hw = (d.w or 0) / 2
    hh = (d.h or 0) / 2
    left   = d.x - hw
    right  = d.x + hw
    top    = d.y - hh
    bottom = d.y + hh
    [ clamp(cx, left, right), clamp(cy, top, bottom) ]

  # === Custom force: 矩形環帶 + 矩形/圓碰撞 + X 對齊 + 內邊界限制 =========
  force-label-rect-band = (opts={}) ->
    # 目標圓心/半徑
    get-px = opts.get-px or ((d)-> d.data.px)
    get-py = opts.get-py or ((d)-> d.data.py)
    get-pr = opts.get-pr or ((d)-> d.data.radius)

    # 規格參數
    band-margin = opts.band-margin or 5
    rect-pad    = opts.rect-pad or 2
    circle-pad  = opts.circle-pad or 0
    k-band      = opts.k-band or 0.35
    k-collide   = opts.k-collide or 0.7
    it-rect     = opts.it-rect or 2
    it-circle   = opts.it-circle or 1
    k-alignx    = opts.k-alignx or 0.12
    align-dead  = opts.align-deadband or 1

    # ★ 畫布範圍（必填）＋ 邊界保留距（可選）
    canvas-w    = opts.canvas-w or 800
    canvas-h    = opts.canvas-h or 600
    bounds-pad  = opts.bounds-pad or 0      # 例如想距離邊緣保留 8px，就設 8
    k-bounds    = opts.k-bounds or 0.9      # 邊界推回力（建議偏強些）

    nodes = null
    circles = null

    resolve-circles = ->
      circles := (for d in nodes
        { x: +get-px(d), y: +get-py(d), r: +get-pr(d) })

    # 1) band：讓「資料點→矩形外殼最近點」距離 ≈ r + margin
    apply-band = (alpha) ->
      for d in nodes
        cx = +get-px d; cy = +get-py d; pr = +get-pr d
        target = pr + band-margin
        [px, py] = nearest-on-rect cx, cy, d
        dx = px - cx; dy = py - cy
        dist = Math.hypot dx, dy
        if dist is 0
          dx = d.x - cx; dy = d.y - cy
          if dx is 0 and dy is 0
            dx = (Math.random! - 0.5) * 1e-6
            dy = (Math.random! - 0.5) * 1e-6
          dist = Math.hypot dx, dy
        if dist < target
          k = (target - dist) / dist * (k-band * alpha)
          d.vx = (d.vx or 0) + dx * k
          d.vy = (d.vy or 0) + dy * k
        else if dist > target
          k = (dist - target) / dist * (k-band * alpha)
          d.vx = (d.vx or 0) - dx * k
          d.vy = (d.vy or 0) - dy * k

    # 1.5) X 對齊（弱）：把 label 中心往 px 拉，僅作用於 vx
    apply-align-x = (alpha) ->
      return unless k-alignx > 0
      for d in nodes
        px = +get-px d
        dx = px - d.x
        if Math.abs(dx) > align-dead
          d.vx = (d.vx or 0) + dx * k-alignx * alpha

    # 2) 矩形-矩形碰撞（AABB，最小重疊軸）
    apply-rect-collide = (alpha) ->
      qt = d3.quadtree!.x((d)->d.x).y((d)->d.y).addAll nodes
      for d in nodes
        ahw = (d.w or 0)/2 + rect-pad
        ahh = (d.h or 0)/2 + rect-pad
        x0 = d.x - (ahw + 200); y0 = d.y - (ahh + 200)
        x1 = d.x + (ahw + 200); y1 = d.y + (ahh + 200)
        qt.visit (nd, nx0, ny0, nx1, ny1) ->
          q = nd.data
          if q? and q isnt d
            bhw = (q.w or 0)/2 + rect-pad
            bhh = (q.h or 0)/2 + rect-pad
            dx = q.x - d.x; dy = q.y - d.y
            if Math.abs(dx) < (ahw + bhw) and Math.abs(dy) < (ahh + bhh)
              ox = (ahw + bhw) - Math.abs(dx)
              oy = (ahh + bhh) - Math.abs(dy)
              if ox < oy
                sgn = if dx >= 0 then 1 else -1
                sep = ox * sgn; k = (k-collide * alpha) * 0.5
                d.vx = (d.vx or 0) - sep * k
                q.vx = (q.vx or 0) + sep * k
              else
                sgn = if dy >= 0 then 1 else -1
                sep = oy * sgn; k = (k-collide * alpha) * 0.5
                d.vy = (d.vy or 0) - sep * k
                q.vy = (q.vy or 0) + sep * k
          (nx0 > x1) or (nx1 < x0) or (ny0 > y1) or (ny1 < y0)

    # 3) 矩形-圓碰撞（label vs 所有資料點）
    apply-rect-circle = (alpha) ->
      qt = d3.quadtree!.x((c)->c.x).y((c)->c.y).addAll circles
      for d in nodes
        ahw = (d.w or 0)/2; ahh = (d.h or 0)/2
        x0 = d.x - (ahw + 300); y0 = d.y - (ahh + 300)
        x1 = d.x + (ahw + 300); y1 = d.y + (ahh + 300)
        qt.visit (nd, nx0, ny0, nx1, ny1) ->
          c = nd.data
          if c?
            [px, py] = nearest-on-rect c.x, c.y, d
            dx = px - c.x; dy = py - c.y
            dist = Math.hypot dx, dy
            need = c.r + circle-pad
            if dist < need
              if dist is 0
                dx = d.x - c.x; dy = d.y - c.y
                if dx is 0 and dy is 0
                  dx = (Math.random! - 0.5) * 1e-6
                  dy = (Math.random! - 0.5) * 1e-6
                dist = Math.hypot dx, dy
              sep = (need - dist); k = (k-collide * alpha)
              d.vx = (d.vx or 0) + (dx / dist) * sep * k
              d.vy = (d.vy or 0) + (dy / dist) * sep * k
          (nx0 > x1) or (nx1 < x0) or (ny0 > y1) or (ny1 < y0)

    # 4) ★ 邊界力：避免越界（以矩形外框 + bounds-pad 為準）
    apply-bounds = (alpha) ->
      lw = bounds-pad
      tw = bounds-pad
      rw = canvas-w - bounds-pad
      bw = canvas-h - bounds-pad
      for d in nodes
        hw = (d.w or 0) / 2
        hh = (d.h or 0) / 2
        # 左邊
        overL = (d.x - hw) - lw
        if overL < 0
          d.vx = (d.vx or 0) - overL * k-bounds * alpha
        # 右邊
        overR = (d.x + hw) - rw
        if overR > 0
          d.vx = (d.vx or 0) - overR * k-bounds * alpha
        # 上邊
        overT = (d.y - hh) - tw
        if overT < 0
          d.vy = (d.vy or 0) - overT * k-bounds * alpha
        # 下邊
        overB = (d.y + hh) - bw
        if overB > 0
          d.vy = (d.vy or 0) - overB * k-bounds * alpha

    force = (alpha) ->
      return unless nodes? and nodes.length
      apply-band alpha           # 半徑帶
      apply-align-x alpha        # X 置中（弱）
      for i from 0 til it-rect   # 矩形-矩形
        apply-rect-collide alpha
      for i from 0 til it-circle # 矩形-圓
        apply-rect-circle alpha
      apply-bounds alpha         # ★ 邊界推回
      return

    force.initialize = (_) ->
      nodes := _
      resolve-circles!
      return

    force.update-circles = ->
      resolve-circles!
      force

    force
  force-label-rect-band

module.exports =
  pkg:
    extend: {name: "@makechart/base"}
    dependencies: []
  init: ({root, context, t, pubsub}) ->
    pubsub.fire \init, mod: mod({context, t})

_corr = (data) ->
  [x,y] = [data.map((d) -> d.x), data.map((d) -> d.y)]
  if (n = x.length) <= 0 => return [0,0]
  sx = x.reduce(((a,b) -> a + b), 0)
  sy = y.reduce(((a,b) -> a + b), 0)
  sxq = x.reduce(((a,b) -> a + b * b), 0)
  syq = y.reduce(((a,b) -> a + b * b), 0)
  sp = [(x[i] * y[i]) for i from 0 til n].reduce(((a,b) -> a + b), 0)
  num = sp - (sx * sy / n)
  den = sxq - (sx * sx / n)
  if !den => return [0,0]
  return [
    ((sy * sxq / n) - (sx * sp / n)) / den,
    num / den
  ]

mod = ({context, t}) ->
  {chart,d3,debounce} = context
  sample: ->
    raw: [0 to 300].map (v) ~>
      name: "Node #v"
      x: Math.round(Math.random! * 100)
      y: Math.round(Math.random! * 100)
      s: Math.round(Math.random! * 10) + 5
      c: <[Apple Banana Peach Melon Orange]>[Math.floor(Math.random! * 5)]
      o: v
    binding:
      x: {key: \x, unit: 'KM'}
      y: {key: \y, unit: 'KG'}
      size: {key: \s, unit: 'Days'}
      cat: {key: \c}
      name: {key: \name}
      order: {key: \o}
  config: {
    legend: {} <<< chart.utils.config.preset.legend
    tip: {} <<< chart.utils.config.preset.tip
    xaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
    yaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
  } <<< chart.utils.config.preset.default <<< do
    dot:
      max-radius: type: \number, default: 10, min: 0.1, max: 100, step: 0.1
      opacity: type: \number, default: 0.75, min: 0, max: 1, step: 0.01
      stroke: type: \color, default: \#000
      stroke-width: type: \number, default: 1, min: 0, max: 100, step: 0.5
    # the result of force-label-rect-band isn't good enough, sometimes labels just overlap with nodes.
    # so we by default hide this option.
    /*
    label:
      enabled: type: \boolean, default: false
      font: {} <<< chart.utils.config.preset.font
      cap:
        type: \quantity, default: \100p
        units:
          * name: \﹪, max: 100, min: 0, step: 1, default: 10
          * name: \pts, step: 1, default: 100
    */

    trend:
      enabled: type: \boolean, default: false
      stroke: type: \color, default: 'rgba(0,0,0,.3)'
      stroke-width: type: \number, default: 1, min: 0, max: 100, step: 0.5
      stroke-dasharray: type: \text, default: '5 5'
      opacity: type: \number, default: 0.5, min: 0, max: 1, step: 0.01
      mode: type: \choice, values: <[curve linear]>, default: \linear
      cap: type: \choice, values: <[butt round square]>, default: \round
      join: type: \choice, values: <[bevel miter round]>, default: \round
    regression:
      enabled: type: \boolean, default: true
      stroke: type: \color, default: \#000
      stroke-width: type: \number, default: 1, min: 0, max: 100, step: 0.5
      stroke-dasharray: type: \text, default: '5 5'
      opacity: type: \number, default: 0.5, min: 0, max: 1, step: 0.01
  dimension:
    name: {type: \NC, name: "name"}
    label: {type: \N, name: "label", desc: "text dedicated for showing in label. name will be used if omitted"}
    cat: {type: \C, name: "category"}
    size: {type: \R, name: "size"}
    x: {type: \R, name: "X coordinate"}
    y: {type: \R, name: "Y coordinate"}
    order: {type: \O, name: "Order"}
  init: ->
    @label-force = get-label-force d3
    @tint = tint = new chart.utils.tint!
    @sim = d3.forceSimulation!
    @g = Object.fromEntries <[view xaxis yaxis legend]>.map ~> [it, d3.select(@layout.get-group it)]
    @regression = @g.view.append \line .attr(\opacity, 0) .attr(\class, \regression)
    @trend = @g.view.append \path .attr(\opacity, 0) .attr(\class, \trend)
    @trend-ani = @trend.append \animate
      .attr \attributeName, \stroke-dashoffset
      .attr \repeatCount, \indefinite
      .attr \dur, \1s
      .attr \values, "0;1"
      .attr \times, "0;1"
    @scale = scale = {}
    @yaxis = new chart.utils.axis layout: @layout, name: \yaxis, direction: \left
    @xaxis = new chart.utils.axis layout: @layout, name: \xaxis, direction: \bottom
    @line = d3.line!
      .defined (d) ~> !(isNaN(d.y) or isNaN(d.x))
      .x (d) ~> @scale.x d.x
      .y (d) ~> @scale.y d.y
    @legend = new chart.utils.legend do
      layout: @layout
      name: \legend
      root: @root
      shape: (d) -> d3.select(@).attr \fill, tint.get d.key
    @legend.on \select, ~> @bind!; @resize!; @render!
    @tip = new chart.utils.tip {
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and data = d3.select(evt.target).datum!) => return null
        v = if isNaN(data.size) => '-'
        else "#{d3.format(@cfg.tip.format or '.3s')(data.size)}#{((@binding or {}).size or {}).unit or ''}"
        return do
          name: [
            if data.cat? => "#{data.cat} / " else ''
            (data.name or '')
            if data.order => " / #{data.order}" else ''
          ].join('')
          value: v
      range: ~> @layout.get-node \view .getBoundingClientRect!
    }
  destroy: -> if @tip => @tip.destroy!
  parse: ->
    @parsed = @data.map (d) ->
      ret = {} <<< d
      ret.size = if isNaN(d.size) => 0 else d.size
      ret.x = if isNaN(d.x) => 0 else d.x
      ret.y = if isNaN(d.y) => 0 else d.y
      ret
    @parsed.sort (a,b) -> if a.size < b.size => -1 else if a.size > b.size => 1 else 0

  resize: ->
    ret = /(\d+)(\D+)/.exec((@cfg.label or {}).cap)
    if ret =>
      len = +ret.1
      if ret.2 == \﹪ => len = Math.round(len * @parsed.length / 100)
    else len = @parsed.length
    @parsed.map (d,i) -> d.label-capped = i > len
    @nodes = @parsed.map (data) ->
      ret = {data}
      data.node = ret
      ret

    @tint.set @cfg.palette
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    @line.curve if @cfg.trend.mode == \curve => d3.curveCatmullRom else d3.curveLinear
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, @cfg.legend.position == \bottom
    @root.querySelector('.pdl-layout').classList.toggle \xaxis-center, @cfg.xaxis.center == true
    @root.querySelector('.pdl-layout').classList.toggle \yaxis-center, @cfg.yaxis.center == true
    @legend.config @cfg.legend
    ticks = if !@binding.cat => []
    else Array.from(new Set(@parsed.map -> it.cat)).map -> {key: it, text: it}
    @legend.data ticks
    @layout.update false
    ext =
      y: d3.extent @parsed.map(-> it.y)
      x: d3.extent @parsed.map(-> it.x)
      s: d3.extent @parsed.map(-> it.size)

    axising = ~>
      @layout.update false
      box = @layout.get-box \view
      maxr = @cfg.dot.max-radius * box.width * 0.2 / 100
      pad = maxr + @cfg.dot.stroke-width

      @scale.s = d3.scaleSqrt!domain(ext.s).range [0, maxr]
      @scale.y = d3.scaleLinear!domain(ext.y).range [box.height - pad, pad]
      max-tick = Math.ceil(@layout.get-box \yaxis .height / 16) >? 2
      yticks = @scale.y.ticks((@cfg.{}xaxis.tick.count or 4) <? max-tick)
      ybind = (@binding.y or {})
      @yaxis.config @cfg.yaxis
      @yaxis.ticks yticks
      @yaxis.scale @scale.y
      ycap = (@cfg.yaxis.caption.text or ybind.name or ybind.key or '')
      if ybind.unit => ycap += "(#{ybind.unit})"
      @yaxis.caption ycap
      @yaxis.render!

      @scale.x = d3.scaleLinear!domain(ext.x).range [pad, box.width - pad]
      max-tick = Math.ceil(@layout.get-box \xaxis .width / 80) >? 2
      xticks = @scale.x.ticks((@cfg.{}xaxis.tick.count or 4) <? max-tick)
      xbind = (@binding.x or {})
      @xaxis.config @cfg.xaxis
      @xaxis.ticks xticks
      @xaxis.scale @scale.x
      xcap = (@cfg.xaxis.caption.text or xbind.name or xbind.key or '')
      if xbind.unit => xcap += "(#{xbind.unit})"
      @xaxis.caption xcap
      @xaxis.render!

    for i from 0 til 2 => axising!
    @parsed.map (d) ~>
      d.radius = if @binding.size? => @scale.s(d.size) >? 1 else (@cfg.dot.max-radius / 2) >? 1
      d.px = @scale.x d.x
      d.py = @scale.y d.y
    @sim.nodes @nodes

    box = @layout.get-box \view
    # the result of force-label-rect-band isn't good enough, sometimes labels just overlap with nodes.
    # so we by default hide this option.
    if (@cfg.label or {}).enabled =>
      @sim
        .force \label, @label-force do
          band-margin: 0
          rect-pad: 2       # 文字框留白
          circle-pad: 2     # 文字框對圓的額外留白
          k-band: 2.35
          k-collide: 13.7
          it-rect: 2
          it-circle: 1
          k-alignx: 0.02      # ★ X 置中力（可依視覺調強弱）
          align-deadband: 1
          canvas-w: box.width
          canvas-h: box.height
          bounds-pad: 4        # 邊緣 padding
          k-bounds: 0.9        # 邊界力
      @sim
        .alpha 1
        .alphaDecay 0.03
        .velocityDecay 0.4
      @sim.restart!


  render: ->
    {data, line, binding, scale, tint, legend, cfg} = @
    @g.view.selectAll \circle.data .data @parsed
      ..exit!remove!
      ..enter!append \circle
        .attr \class, \data
        .attr \r, 0
        .attr \cx, (d) -> scale.x d.x
        .attr \cy, (d) -> scale.y d.y
        .attr \fill, (d) -> tint.get(if d.cat? => d.cat else '')
        .attr \stroke, (d) -> cfg.dot.stroke
        .attr \strokeWidth, (d) -> cfg.dot.strokeWidth
    @g.view.selectAll \circle.data
      .transition!duration 350
      .attr \r, (d) -> d.radius
      .attr \cx, (d) -> scale.x d.x
      .attr \cy, (d) -> scale.y d.y
      .attr \fill, (d) -> tint.get(if d.cat? => d.cat else '')
      .attr \opacity, (d) ->
        if !(binding.cat?) or legend.is-selected d.cat => (cfg.dot.opacity >? 0.1)
        else (0.1 <? (cfg.dot.opacity/2))
      .attr \stroke, (d) -> cfg.dot.stroke
      .attr \stroke-width, (d) -> cfg.dot.strokeWidth

    @g.view.selectAll \text.label .data(if (@cfg.label or {}).enabled => @parsed else [])
      ..exit!remove!
      ..enter!append \text
        .attr \class, ->
          family = ((cfg.label or {}).font or {}).family
          "label #{if family => that.className or '' else ''}"
        .attr \dominant-baseline, \middle
        .attr \text-anchor, \middle
        .attr \transform, (d,i) -> "translate(#{d.px},#{d.py})"
        .style \opacity, 0
        .attr \font-size, 0

    @g.view.selectAll \text.label
      .attr \font-size, (((cfg.label or {}).font or {}).size or \.75em)
      .style \pointer-events, (d) -> if d.label-capped => \none else ''
      .text (d,i) ~> if @binding.label => (d.label or '') else (d.name or '')
      .each (d) ->
        box = @.getBBox!
        d.node.w = box.width
        d.node.h = box.height
    @g.view.selectAll \text.label
      .transition!duration 350
      .style \opacity, (d) -> if d.label-capped => 0 else 1

    corr = _corr @parsed.filter (d,i) -> !(binding.cat?) or legend.is-selected(d.cat)

    [x1, x2] = scale.x.domain!
    [y1, y2] = [x1,x2].map -> it * corr.1 + corr.0
    if y1 < scale.y.domain!0 =>
      y1 = scale.y.domain!0
      x1 = (y1 - corr.0) / (corr.1 or 1)
    if y2 > scale.y.domain!1 =>
      y2 = scale.y.domain!1
      x2 = (y2 - corr.0) / (corr.1 or 1)
    [x1, x2, y1, y2] = [scale.x(x1), scale.x(x2), scale.y(y1), scale.y(y2)]
    hide-line = (isNaN(x1) or isNaN(x2) or isNaN(y1) or isNaN(y2)) or !(corr.0 or corr.1) or !cfg.regression.enabled

    @regression
      .transition \regression .duration 350
      .attr \x1, if hide-line => 0 else x1
      .attr \x2, if hide-line => 0 else x2
      .attr \y1, if hide-line => 0 else y1
      .attr \y2, if hide-line => 0 else y2
      .attr \opacity, if hide-line => 0 else cfg.regression.opacity
      .attr \stroke, cfg.regression.stroke
      .attr \stroke-width, cfg.regression.strokeWidth
      .attr \stroke-dasharray, cfg.regression.strokeDasharray

    sorted = data.map(-> it{x,y,order})
    sorted.sort (a,b) -> if a.order < b.order => -1 else if a.o > b.o => 1 else 0
    @trend
      .attr \d, -> line sorted
      .attr \fill, \none
      .attr \opacity, if cfg.trend.enabled => 1 else 0
      .attr \stroke, cfg.trend.stroke
      .attr \stroke-width, cfg.trend.strokeWidth
      .attr \stroke-dasharray, cfg.trend.strokeDasharray
      .attr \stroke-linecap, cfg.trend.cap
      .attr \stroke-linejoin, cfg.trend.join
    dashoffset = cfg.trend.strokeDasharray.split(' ').filter(->it?).reduce(((a,b)->a + +b),0)
    @trend-ani.attr \values, "#dashoffset;0"

    @legend.render!
    @yaxis.render!
    @xaxis.render!
    if (@cfg.label or {}).enabled => @start!

  tick: ->
    {data, line, binding, scale, tint, legend, cfg} = @
    if !(@cfg.label or {}).enabled => return
    @_tick = (@_tick or 0) + 1
    @g.view.selectAll \text.label
      .attr \transform, (d) -> "translate(#{d.node.x},#{d.node.y})"
