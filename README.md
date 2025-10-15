# @makechart/scatter

Config:

 - `alignRange`: boolean. when true, X-axis and Y-axis shares the same value range.


Events:

 - `focus`: highlight certain points by their name.
   - options: an object with following fields:
     - `names`: a (list of) string of the name of node(s) to highlight.
   - to dismiss focus mode, simply fire `focus` event without parameter.
