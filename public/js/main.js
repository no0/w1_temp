        var margin = {top: 20, right: 80, bottom: 30, left: 50},
        width = 960 - margin.left - margin.right,
        height = 500 - margin.top - margin.bottom;

        var parseDate = d3.time.format("%Y-%m-%d %H:%M:%S").parse;

        var x = d3.time.scale()
          .range([0, width]);

        var y = d3.scale.linear()
          .range([height, 0]);

        var color = d3.scale.category10();

        var xAxis = d3.svg.axis()
          .scale(x)
          .orient("bottom");

        var yAxis = d3.svg.axis()
          .scale(y)
          .orient("left");

        var line = d3.svg.line()
          .interpolate("basis")
          .x(function(d) { return x(d.date); })
          .y(function(d) { return y(d.temperature); });

        var svg = d3.select("body").append("svg")
          .attr("style", "width: 100%; height: 40%;")
          .attr("viewBox", "0 0 " + (width + margin.left + margin.right) + " " + (height + margin.top + margin.bottom))
          .append("g")
          .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        d3.json("/temps?ago=1440", function(error, data) {
          color.domain(d3.set(data.map(function(d) { return d.loc; })).values());

          data.forEach(function(d) { d.date = parseDate(d.timestamp); });

          var cities = color.domain().map(function(name) {
            return {
              name: name,
              values: data.map(function(d) {
                if (d.loc == name) {
                  return {date: d.date, temperature: +d.reading};
                }
              }).filter(function(d) { return d; })
            };
          });

          x.domain(d3.extent(data, function(d) { return d.date; }));

        y.domain([
          d3.min(cities, function(c) { return d3.min(c.values, function(v) { return v.temperature; }); }),
          d3.max(cities, function(c) { return d3.max(c.values, function(v) { return v.temperature; }); })
        ]);

        svg.append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + height + ")")
          .call(xAxis);

        svg.append("g")
            .attr("class", "y axis")
            .call(yAxis)
        .append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 6)
            .attr("dy", ".71em")
            .style("text-anchor", "end")
            .text("Temperature (ºF)");

        var city = svg.selectAll(".city")
          .data(cities)
          .enter().append("g")
          .attr("class", "city");

        city.append("path")
          .attr("class", "line")
          .attr("d", function(d) { return line(d.values); })
          .style("stroke", function(d) { return color(d.name); });

        city.append("text")
          .datum(function(d) { return {name: d.name, value: d.values[d.values.length - 1]}; })
          .attr("transform", function(d) { return "translate(" + x(d.value.date) + "," + y(d.value.temperature) + ")"; })
          .attr("x", 3)
          .attr("dy", ".35em")
          .text(function(d) { return d.name; });
        });

var $currentTemp = $('<div></div>');
$('body').append($currentTemp);

var socket = io.connect('http://woodstock.sytes.net:3000');
socket.on('connect', function(){
  socket.on('temp', function(data){
    var msg = '';
    console.log(data);
    data.forEach(function (temp) {
      msg += temp.loc + ' ' + temp.reading.toFixed(1) + ' ' ;
    });
    $currentTemp.html( msg );
  });
});
