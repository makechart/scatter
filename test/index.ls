# scatter 的 test case ( @makechart/viewer 的 mctest )
cats = <[Apple Banana Peach Melon Orange]>
# 每份資料用自己的種子, 跟產生的先後順序無關
mk = (n, seed = n) ->
  rnd = mctest.random seed
  raw: [0 til n].map (i) ->
    x: Math.round(rnd! * 1000) / 10, y: Math.round(rnd! * 500) / 10
    s: Math.round(rnd! * 20), c: cats[Math.floor(rnd! * 5)], name: "Node #i", o: i
  binding:
    x: {key: \x, unit: \KM}, y: {key: \y, unit: \KG}, size: {key: \s, unit: \Days}
    cat: {key: \c}, name: {key: \name}, order: {key: \o}
plain = (n, seed = n) ->
  d = mk n, seed
  d.binding = d.binding{x, y}
  d
# 標籤一開始都在圓心上, label force 遇到重疊會用 Math.random 決定推開的方向.
# 測標籤時換成固定種子, 並重設模擬
_random = Math.random
seeded = (c) ->
  Math.random = mctest.random 1
  c.resize!; c.render!
unseed = -> Math.random = _random
# legend.select 不發事件, 照 scatter 的 legend select handler 重畫
pick = (keys) -> (c) ->
  c.legend.select keys
  c.bind!; c.resize!; c.render!

mctest.suite do
  size: [560, 400]
  data:
    many: mk 60
    few: mk 8
    plain: plain 30
  cases:
    * name: "many", data: \many
    * name: "few", data: \few
    * name: "plain", data: \plain
    * name: "log", data: \many, config: {xaxis: {scale: \log}, yaxis: {scale: \log}}
    * name: "pr", data: \many, config: {xaxis: {scale: \pr}, yaxis: {scale: \pr}}
    * name: "grid", data: \many, config: {xaxis: {grid: {enabled: true}}, yaxis: {grid: {enabled: true, stroke-dasharray: '3 3'}}}
    * name: "align-range", data: \many, config: {align-range: true}
    * name: "trend:linear", data: \few, config: {trend: {enabled: true}}
    * name: "trend:curve", data: \few, config: {trend: {enabled: true, mode: \curve}}
    * name: "no-regression", data: \many, config: {regression: {enabled: false}}
    * name: "dot", data: \many, config: {dot: {min-radius: 2, max-radius: 12, opacity: 0.4, stroke: \#f00, stroke-width: 2}}
    * name: "legend:bottom", data: \many, config: {legend: {position: \bottom}}
    * name: "legend:pick", data: \many, steps: pick <[Apple Peach]>
    * name: "focus", data: \many, steps: (c) -> c.fire \focus, names: ["Node 3", "Node 7"]
    * name: "update", data: \many, steps: (c) -> d = mk 40, 9; c.set-raw d.raw, d.binding
    # 標籤用 force 排開, 模擬約 690 步 ( alpha 從 1 以 0.01 衰減到 alphaMin ) 才結束.
    # lite 版的模擬跟著 anim 時鐘走, 直接推 700 格; d3 版靠 d3-timer, 只能等它跑完
    * name: "label", data: \few, config: {label: {enabled: true}}
      # 先重設模擬 ( 切到 manual 前已用真實時間跑過幾格, 格數不固定 )
      steps:
        * seeded
        * (c, ctx) ->
            if c.anim => for i from 0 til 700 => c.anim.step 16
            else ctx.wait 13000
        * unseed

# lite 版才有: anim 的 manual 時鐘拍動畫中間格, 標籤的模擬也跟著時鐘一格格走
mctest.suite do
  size: [560, 400]
  data:
    many: mk 60
    few: mk 8
  cases:
    * name: "anim:update-frames", data: \many
      steps:
        * (c) -> d = mk 40, 9; c.set-raw d.raw, d.binding
        # legend 變了會觸發 layout 的 resize 再重畫一次, 等它跑完再推時鐘
        * (c, ctx) -> ctx.wait 300
        * (c, ctx) ->
            for i from 1 to 4
              c.anim.step 70
              ctx.capture "t#{i * 70}"
    * name: "anim:label-frames", data: \few, config: {label: {enabled: true}}
      steps:
        * seeded
        * (c, ctx) ->
            for i from 1 to 3
              for j from 0 til 10 => c.anim.step 16
              ctx.capture "f#{i * 10}"
        * unseed
