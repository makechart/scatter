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
    raw: [0 to 30].map (v) ~>
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
    cat: {type: \C, name: "category"}
    size: {type: \R, name: "size"}
    x: {type: \R, name: "X coordinate"}
    y: {type: \R, name: "Y coordinate"}
    order: {type: \O, name: "Order"}
  init: ->
    @tint = tint = new chart.utils.tint!
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
    @data.map (d) ->
      d.size = if isNaN(d.size) => 0 else d.size
      d.x = if isNaN(d.x) => 0 else d.x
      d.y = if isNaN(d.y) => 0 else d.y
  resize: ->
    @tint.set @cfg.palette
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    @line.curve if @cfg.trend.mode == \curve => d3.curveCatmullRom else d3.curveLinear
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, @cfg.legend.position == \bottom
    @legend.config @cfg.legend
    ticks = if !@binding.cat => []
    else Array.from(new Set(@data.map -> it.cat)).map -> {key: it, text: it}
    @legend.data ticks
    @layout.update false
    ext =
      y: d3.extent @data.map(-> it.y)
      x: d3.extent @data.map(-> it.x)
      s: d3.extent @data.map(-> it.size)

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

  render: ->
    {data, line, binding, scale, tint, legend, cfg} = @
    @g.view.selectAll \circle.data .data @data
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
      .attr \r, (d) -> if binding.size? => scale.s(d.size) >? 1 else (cfg.dot.max-radius / 2) >? 1
      .attr \cx, (d) -> scale.x d.x
      .attr \cy, (d) -> scale.y d.y
      .attr \fill, (d) -> tint.get(if d.cat? => d.cat else '')
      .attr \opacity, (d) ->
        if !(binding.cat?) or legend.is-selected d.cat => (cfg.dot.opacity >? 0.1)
        else (0.1 <? (cfg.dot.opacity/2))
      .attr \stroke, (d) -> cfg.dot.stroke
      .attr \stroke-width, (d) -> cfg.dot.strokeWidth

    corr = _corr @data.filter (d,i) -> !(binding.cat?) or legend.is-selected(d.cat)

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

