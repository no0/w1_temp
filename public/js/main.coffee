require.config
  paths:
    jquery: '../bower_components/jquery/jquery'
    d3: '../bower_components/d3/d3.min'
    socketio: '../socket.io/socket.io'

require ['jquery', 'd3', 'socketio'], ->
  class TempGraph
    constructor: ->
      @margin = {top: 20, right: 80, bottom: 30, left: 50}
      @width = 960 - @margin.left - @margin.right
      @height = 500 - @margin.top - @margin.bottom
      @parseDate = d3.time.format("%Y-%m-%d %H:%M:%S").parse
      @x = d3.time.scale().range([0, @width])
      @y = d3.scale.linear().range([@height, 0])
      @color = d3.scale.category10()
      @minAgo = 1440

    buildBits: ->
      @xAxis = d3.svg.axis()
        .scale(@x)
        .orient("bottom")

      @yAxis = d3.svg.axis()
        .scale(@y)
        .orient("left")

      @line = d3.svg.line()
        .interpolate("basis")
        .x((d) -> @x(d.date))
        .y((d) -> @y(d.temperature))

      @svg = d3.select("body").append("svg")
        .attr("style", "width: 100%; height: 40%;")
        .attr("viewBox", "0 0 " + (@width + @margin.left + @margin.right) + " " + (@height + @margin.top + @margin.bottom))
        .append("g")
        .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")
      return this

    grabData: ->
      d3.json "/temps?ago=#{@minAgo}", @render
      return this

    renderSlider: ->
      $('body').append @$slider = $ '<input type="range">'

    render: (err, @data) =>
      @color.domain(d3.set(@data.map((d) -> return d.loc )).values())

      @data.forEach((d) => d.date = @parseDate(d.timestamp) )

      @cities = @color.domain().map((name) =>
        return {
          name: name,
          values: @data.map((d) ->
            if (d.loc == name) 
              return {date: d.date, temperature: +d.reading}
          ).filter((d) -> return d )
        }
      )

      @x.domain(d3.extent(@data, (d) -> return d.date ))

      @y.domain([
        d3.min(@cities, (c) -> return d3.min(c.values, (v) -> return v.temperature ) ),
        d3.max(@cities, (c) -> return d3.max(c.values, (v) -> return v.temperature ) )
      ])

      @svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + @height + ")")
        .call(@xAxis)

      @svg.append("g")
          .attr("class", "y axis")
          .call(@yAxis)
        .append("text")
          .attr("transform", "rotate(-90)")
          .attr("y", 6)
          .attr("dy", ".71em")
          .style("text-anchor", "end")
          .text("Temperature (ºF)")

      @city = @svg.selectAll(".city")
        .data(@cities)
        .enter().append("g")
        .attr("class", "city")

      @city.append("path")
        .attr("class", "line")
        .attr("d", (d) => return @line(d.values) )
        .style("stroke", (d) => return @color(d.name) )

      @city.append("text")
        .datum((d) -> return {name: d.name, value: d.values[d.values.length - 1]} )
        .attr("transform", (d) => return "translate(" + @x(d.value.date) + "," + @y(d.value.temperature) + ")" )
        .attr("x", 3)
        .attr("dy", ".35em")
        .text((d) -> return d.name )
      return this

  class CurrentTemp
    constructor: ->
      $('body').append @$el = $ '<div></div>'
      @socket = io.connect '/'
      @socket.on 'connect', => @socket.on 'temp', @render
      $.get '/last', @render
    render: (data) =>
      msg = ''
      data.forEach (temp) -> msg += "#{temp.loc} #{temp.reading.toFixed(1)} "
      @$el.html msg

  graph = new TempGraph().buildBits().grabData()
  ct = new CurrentTemp()
