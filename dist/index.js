(function(){
  var _corr, mod;
  module.exports = {
    pkg: {
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: []
    },
    init: function(arg$){
      var root, context, t, pubsub;
      root = arg$.root, context = arg$.context, t = arg$.t, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          context: context,
          t: t
        })
      });
    }
  };
  _corr = function(data){
    var ref$, x, y, n, sx, sy, sxq, syq, sp, i, num, den;
    ref$ = [
      data.map(function(d){
        return d.x;
      }), data.map(function(d){
        return d.y;
      })
    ], x = ref$[0], y = ref$[1];
    if ((n = x.length) <= 0) {
      return [0, 0];
    }
    sx = x.reduce(function(a, b){
      return a + b;
    }, 0);
    sy = y.reduce(function(a, b){
      return a + b;
    }, 0);
    sxq = x.reduce(function(a, b){
      return a + b * b;
    }, 0);
    syq = y.reduce(function(a, b){
      return a + b * b;
    }, 0);
    sp = (function(){
      var i$, to$, results$ = [];
      for (i$ = 0, to$ = n; i$ < to$; ++i$) {
        i = i$;
        results$.push(x[i] * y[i]);
      }
      return results$;
    }()).reduce(function(a, b){
      return a + b;
    }, 0);
    num = sp - sx * sy / n;
    den = sxq - sx * sx / n;
    if (!den) {
      return [0, 0];
    }
    return [(sy * sxq / n - sx * sp / n) / den, num / den];
  };
  mod = function(arg$){
    var context, t, chart, d3, debounce;
    context = arg$.context, t = arg$.t;
    chart = context.chart, d3 = context.d3, debounce = context.debounce;
    return {
      sample: function(){
        return {
          raw: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30].map(function(v){
            return {
              name: "Node " + v,
              x: Math.round(Math.random() * 100),
              y: Math.round(Math.random() * 100),
              s: Math.round(Math.random() * 10) + 5,
              c: ['Apple', 'Banana', 'Peach', 'Melon', 'Orange'][Math.floor(Math.random() * 5)],
              o: v
            };
          }),
          binding: {
            x: {
              key: 'x',
              unit: 'KM'
            },
            y: {
              key: 'y',
              unit: 'KG'
            },
            size: {
              key: 's',
              unit: 'Days'
            },
            cat: {
              key: 'c'
            },
            name: {
              key: 'name'
            },
            order: {
              key: 'o'
            }
          }
        };
      },
      config: import$(import$({
        legend: import$({}, chart.utils.config.preset.legend),
        tip: import$({}, chart.utils.config.preset.tip),
        xaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis)),
        yaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
      }, chart.utils.config.preset['default']), {
        dot: {
          maxRadius: {
            type: 'number',
            'default': 10,
            min: 0.1,
            max: 100,
            step: 0.1
          },
          opacity: {
            type: 'number',
            'default': 0.75,
            min: 0,
            max: 1,
            step: 0.01
          },
          stroke: {
            type: 'color',
            'default': '#000'
          },
          strokeWidth: {
            type: 'number',
            'default': 1,
            min: 0,
            max: 100,
            step: 0.5
          }
        },
        trend: {
          enabled: {
            type: 'boolean',
            'default': false
          },
          stroke: {
            type: 'color',
            'default': 'rgba(0,0,0,.3)'
          },
          strokeWidth: {
            type: 'number',
            'default': 1,
            min: 0,
            max: 100,
            step: 0.5
          },
          strokeDasharray: {
            type: 'text',
            'default': '5 5'
          },
          opacity: {
            type: 'number',
            'default': 0.5,
            min: 0,
            max: 1,
            step: 0.01
          },
          mode: {
            type: 'choice',
            values: ['curve', 'linear'],
            'default': 'linear'
          },
          cap: {
            type: 'choice',
            values: ['butt', 'round', 'square'],
            'default': 'round'
          },
          join: {
            type: 'choice',
            values: ['bevel', 'miter', 'round'],
            'default': 'round'
          }
        },
        regression: {
          enabled: {
            type: 'boolean',
            'default': true
          },
          stroke: {
            type: 'color',
            'default': '#000'
          },
          strokeWidth: {
            type: 'number',
            'default': 1,
            min: 0,
            max: 100,
            step: 0.5
          },
          strokeDasharray: {
            type: 'text',
            'default': '5 5'
          },
          opacity: {
            type: 'number',
            'default': 0.5,
            min: 0,
            max: 1,
            step: 0.01
          }
        }
      }),
      dimension: {
        name: {
          type: 'NC',
          name: "name"
        },
        cat: {
          type: 'C',
          name: "category"
        },
        size: {
          type: 'R',
          name: "size"
        },
        x: {
          type: 'R',
          name: "X coordinate"
        },
        y: {
          type: 'R',
          name: "Y coordinate"
        },
        order: {
          type: 'O',
          name: "Order"
        }
      },
      init: function(){
        var tint, scale, this$ = this;
        this.tint = tint = new chart.utils.tint();
        this.g = Object.fromEntries(['view', 'xaxis', 'yaxis', 'legend'].map(function(it){
          return [it, d3.select(this$.layout.getGroup(it))];
        }));
        this.regression = this.g.view.append('line').attr('opacity', 0).attr('class', 'regression');
        this.trend = this.g.view.append('path').attr('opacity', 0).attr('class', 'trend');
        this.trendAni = this.trend.append('animate').attr('attributeName', 'stroke-dashoffset').attr('repeatCount', 'indefinite').attr('dur', '1s').attr('values', "0;1").attr('times', "0;1");
        this.scale = scale = {};
        this.yaxis = new chart.utils.axis({
          layout: this.layout,
          name: 'yaxis',
          direction: 'left'
        });
        this.xaxis = new chart.utils.axis({
          layout: this.layout,
          name: 'xaxis',
          direction: 'bottom'
        });
        this.line = d3.line().defined(function(d){
          return !(isNaN(d.y) || isNaN(d.x));
        }).x(function(d){
          return this$.scale.x(d.x);
        }).y(function(d){
          return this$.scale.y(d.y);
        });
        this.legend = new chart.utils.legend({
          layout: this.layout,
          name: 'legend',
          root: this.root,
          shape: function(d){
            return d3.select(this).attr('fill', tint.get(d.key));
          }
        });
        this.legend.on('select', function(){
          this$.bind();
          this$.resize();
          return this$.render();
        });
        return this.tip = new chart.utils.tip({
          root: this.root,
          accessor: function(arg$){
            var evt, data, v;
            evt = arg$.evt;
            if (!(evt.target && (data = d3.select(evt.target).datum()))) {
              return null;
            }
            v = isNaN(data.size)
              ? '-'
              : d3.format(this$.cfg.tip.format || '.3s')(data.size) + "" + (((this$.binding || {}).size || {}).unit || '');
            return {
              name: [data.cat != null ? data.cat + " / " : '', data.name || '', data.order ? " / " + data.order : ''].join(''),
              value: v
            };
          },
          range: function(){
            return this$.layout.getNode('view').getBoundingClientRect();
          }
        });
      },
      destroy: function(){
        if (this.tip) {
          return this.tip.destroy();
        }
      },
      parse: function(){
        return this.data.map(function(d){
          d.size = isNaN(d.size)
            ? 0
            : d.size;
          d.x = isNaN(d.x)
            ? 0
            : d.x;
          return d.y = isNaN(d.y)
            ? 0
            : d.y;
        });
      },
      resize: function(){
        var ref$, ticks, ext, axising, i$, i, this$ = this, results$ = [];
        this.tint.set(this.cfg.palette);
        this.tip.toggle(((ref$ = this.cfg).tip || (ref$.tip = {})).enabled != null ? this.cfg.tip.enabled : true);
        this.line.curve(this.cfg.trend.mode === 'curve'
          ? d3.curveCatmullRom
          : d3.curveLinear);
        this.root.querySelector('.pdl-layout').classList.toggle('legend-bottom', this.cfg.legend.position === 'bottom');
        this.legend.config(this.cfg.legend);
        ticks = !this.binding.cat
          ? []
          : Array.from(new Set(this.data.map(function(it){
            return it.cat;
          }))).map(function(it){
            return {
              key: it,
              text: it
            };
          });
        this.legend.data(ticks);
        this.layout.update(false);
        ext = {
          y: d3.extent(this.data.map(function(it){
            return it.y;
          })),
          x: d3.extent(this.data.map(function(it){
            return it.x;
          })),
          s: d3.extent(this.data.map(function(it){
            return it.size;
          }))
        };
        axising = function(){
          var box, maxr, pad, maxTick, ref$, yticks, ref1$, ybind, ycap, xticks, xbind, xcap;
          this$.layout.update(false);
          box = this$.layout.getBox('view');
          maxr = this$.cfg.dot.maxRadius * box.width * 0.2 / 100;
          pad = maxr + this$.cfg.dot.strokeWidth;
          this$.scale.s = d3.scaleSqrt().domain(ext.s).range([0, maxr]);
          this$.scale.y = d3.scaleLinear().domain(ext.y).range([box.height - pad, pad]);
          maxTick = (ref$ = Math.ceil(this$.layout.getBox('yaxis').height / 16)) > 2 ? ref$ : 2;
          yticks = this$.scale.y.ticks((ref$ = ((ref1$ = this$.cfg).xaxis || (ref1$.xaxis = {})).tick.count || 4) < maxTick ? ref$ : maxTick);
          ybind = this$.binding.y || {};
          this$.yaxis.config(this$.cfg.yaxis);
          this$.yaxis.ticks(yticks);
          this$.yaxis.scale(this$.scale.y);
          ycap = this$.cfg.yaxis.caption.text || ybind.name || ybind.key || '';
          if (ybind.unit) {
            ycap += "(" + ybind.unit + ")";
          }
          this$.yaxis.caption(ycap);
          this$.yaxis.render();
          this$.scale.x = d3.scaleLinear().domain(ext.x).range([pad, box.width - pad]);
          maxTick = (ref$ = Math.ceil(this$.layout.getBox('xaxis').width / 80)) > 2 ? ref$ : 2;
          xticks = this$.scale.x.ticks((ref$ = ((ref1$ = this$.cfg).xaxis || (ref1$.xaxis = {})).tick.count || 4) < maxTick ? ref$ : maxTick);
          xbind = this$.binding.x || {};
          this$.xaxis.config(this$.cfg.xaxis);
          this$.xaxis.ticks(xticks);
          this$.xaxis.scale(this$.scale.x);
          xcap = this$.cfg.xaxis.caption.text || xbind.name || xbind.key || '';
          if (xbind.unit) {
            xcap += "(" + xbind.unit + ")";
          }
          this$.xaxis.caption(xcap);
          return this$.xaxis.render();
        };
        for (i$ = 0; i$ < 2; ++i$) {
          i = i$;
          results$.push(axising());
        }
        return results$;
      },
      render: function(){
        var data, line, binding, scale, tint, legend, cfg, x$, corr, ref$, x1, x2, y1, y2, hideLine, sorted, dashoffset;
        data = this.data, line = this.line, binding = this.binding, scale = this.scale, tint = this.tint, legend = this.legend, cfg = this.cfg;
        x$ = this.g.view.selectAll('circle.data').data(this.data);
        x$.exit().remove();
        x$.enter().append('circle').attr('class', 'data').attr('r', 0).attr('cx', function(d){
          return scale.x(d.x);
        }).attr('cy', function(d){
          return scale.y(d.y);
        }).attr('fill', function(d){
          return tint.get(d.cat != null ? d.cat : '');
        }).attr('stroke', function(d){
          return cfg.dot.stroke;
        }).attr('strokeWidth', function(d){
          return cfg.dot.strokeWidth;
        });
        this.g.view.selectAll('circle.data').transition().duration(350).attr('r', function(d){
          var ref$;
          if (binding.size != null) {
            return (ref$ = scale.s(d.size)) > 1 ? ref$ : 1;
          } else {
            return (ref$ = cfg.dot.maxRadius / 2) > 1 ? ref$ : 1;
          }
        }).attr('cx', function(d){
          return scale.x(d.x);
        }).attr('cy', function(d){
          return scale.y(d.y);
        }).attr('fill', function(d){
          return tint.get(d.cat != null ? d.cat : '');
        }).attr('opacity', function(d){
          var ref$;
          if (!(binding.cat != null) || legend.isSelected(d.cat)) {
            return (ref$ = cfg.dot.opacity) > 0.1 ? ref$ : 0.1;
          } else {
            return 0.1 < (ref$ = cfg.dot.opacity / 2) ? 0.1 : ref$;
          }
        }).attr('stroke', function(d){
          return cfg.dot.stroke;
        }).attr('stroke-width', function(d){
          return cfg.dot.strokeWidth;
        });
        corr = _corr(this.data.filter(function(d, i){
          return !(binding.cat != null) || legend.isSelected(d.cat);
        }));
        ref$ = scale.x.domain(), x1 = ref$[0], x2 = ref$[1];
        ref$ = [x1, x2].map(function(it){
          return it * corr[1] + corr[0];
        }), y1 = ref$[0], y2 = ref$[1];
        if (y1 < scale.y.domain()[0]) {
          y1 = scale.y.domain()[0];
          x1 = (y1 - corr[0]) / (corr[1] || 1);
        }
        if (y2 > scale.y.domain()[1]) {
          y2 = scale.y.domain()[1];
          x2 = (y2 - corr[0]) / (corr[1] || 1);
        }
        ref$ = [scale.x(x1), scale.x(x2), scale.y(y1), scale.y(y2)], x1 = ref$[0], x2 = ref$[1], y1 = ref$[2], y2 = ref$[3];
        hideLine = (isNaN(x1) || isNaN(x2) || isNaN(y1) || isNaN(y2)) || !(corr[0] || corr[1]) || !cfg.regression.enabled;
        this.regression.transition('regression').duration(350).attr('x1', hideLine ? 0 : x1).attr('x2', hideLine ? 0 : x2).attr('y1', hideLine ? 0 : y1).attr('y2', hideLine ? 0 : y2).attr('opacity', hideLine
          ? 0
          : cfg.regression.opacity).attr('stroke', cfg.regression.stroke).attr('stroke-width', cfg.regression.strokeWidth).attr('stroke-dasharray', cfg.regression.strokeDasharray);
        sorted = data.map(function(it){
          return {
            x: it.x,
            y: it.y,
            order: it.order
          };
        });
        sorted.sort(function(a, b){
          if (a.order < b.order) {
            return -1;
          } else if (a.o > b.o) {
            return 1;
          } else {
            return 0;
          }
        });
        this.trend.attr('d', function(){
          return line(sorted);
        }).attr('fill', 'none').attr('opacity', cfg.trend.enabled ? 1 : 0).attr('stroke', cfg.trend.stroke).attr('stroke-width', cfg.trend.strokeWidth).attr('stroke-dasharray', cfg.trend.strokeDasharray).attr('stroke-linecap', cfg.trend.cap).attr('stroke-linejoin', cfg.trend.join);
        dashoffset = cfg.trend.strokeDasharray.split(' ').filter(function(it){
          return it != null;
        }).reduce(function(a, b){
          return a + +b;
        }, 0);
        this.trendAni.attr('values', dashoffset + ";0");
        this.legend.render();
        this.yaxis.render();
        return this.xaxis.render();
      }
    };
  };
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
