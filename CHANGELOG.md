# Change Logs

## v0.0.4

 - extend the lite base ( `@makechart/base` `lite/index.html`, no d3 ): needs `@makechart/base` >= 0.2.0
   and `@plotdb/chart` >= 3.7.0. scales / shapes / transitions use `chart.utils`, and transitions run on
   `chart.anim`, so animation can be recorded frame by frame ( `anim.manual` / `step` )
 - `d3-force` / `d3-quadtree` ( with `d3-dispatch`, `d3-timer` ) are loaded as dependencies for label layout.
   the label simulation advances one step per frame in `mod.tick` instead of running on its own timer
 - fix bug: grid `stroke-width` / `stroke-dasharray` were never applied
 - add test cases ( `test/index.ls`, run with `npm test` via `@makechart/viewer` )


## v0.0.3

 - support tie method in scale-pr


## v0.0.2

 - support centered axes
 - support dynamic labels
 - support label configurations
 - add label dimension for showing customized text in label
 - add `minRadius` option
 - support data range conversion (including Linear Scale, Percentile Rank and Log Scale)
 - use `charts.utils.format` instead of `d3.format`
 - fix trend line rendering issue
 - add `align-range` config, which makes x-axis and y-axis use the same value range.
 - add grid lines


## v0.0.1

init release
