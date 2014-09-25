
class JchartCoordinate extends Jchart
  
  constructor: (@canvas, @data, @options=null, @ipo) ->

    @options = _.merge
      chart:
        width: 1060
        height: 480
        paddingLeft: 5
        paddingTop: 5
        paddingRight: 5
        paddingBottom: 5
        lineWidth: 2
        font:
          style: 'normal'
          weight: 'normal'
          size: '13px'
          family: 'Arial'
        color: '#888'
        background: '#ffffff'
      graph:
        border: true
        marginLeft: 'auto'
        marginBottom: 30
        marginTop: 5
        marginRight: 20
        background: '#ffffff'
        background_stripe: '#FCFCFC'
      legend:
        font: 
          style: 'italic'
          size: '13px'
        color: 'rgba(0,0,0,0.3)'
        enable: true
        layout: 'horizontal'
        marginTop: 35
        marginBottom: 0
      xAxis:
        data: []
        title: ''
        border:
          enable: true
          color: "#888"
        grid: 
          enable: true
          align: 'margin' # or center
        tick:
          enable: true
          align: 'margin'
          size: 10
        label: 
          enable: true
          align: 'margin'
          font : {}
          color: '#000'
          prefix: ''
          suffix: ''
        min: null
        max: null
        breaks: 5
      yAxis:
        data: []
        title: ''
        border:
          enable: true
          color: "#888"
        grid: 
          enable: false
          align: 'margin' # or center
        tick: 
          enable: true
          size: 10
        label: 
          enable: true
          align: 'left' # or right
          font : {}
          color: '#000'
          prefix: ''
          suffix: ''
        min: null
        max: null
        breaks: 5
    , @options

    super @canvas, @data, @options, @ipo

  preprocess_data: ->
    if @options.yAxis.min?
      @min_data = @options.yAxis.min
    if @options.yAxis.max?
      @max_data = @options.yAxis.max

    if !@options.yAxis.min? or !@options.yAxis.max?
      min_obj = _.min @data, (item) -> _min item.data
      min = _.min min_obj.data
      max_obj = _.max @data, (item) -> _max item.data
      max = _.max max_obj.data
      pad = (max-min) * 0.1
      pad = @options.yAxis.breaks if pad == 0 
      pad = 0

      @max_data = max + pad if !@options.yAxis.max?
      @min_data = min if !@options.yAxis.min?

    # auto calculate margin left from max text length
    if @options.graph.marginLeft is 'auto' # ~40
      max_text = @options.yAxis.label.prefix + @auto_format(@max_data) + @options.yAxis.label.suffix
      digit = max_text.length
      @options.graph.marginLeft = 10 + digit*8 + @options.yAxis.tick.size

    # assign variables
    @graph_width = @options.chart.width - @options.chart.paddingLeft - @options.chart.paddingRight
    @graph_height = @options.chart.height - @options.chart.paddingTop - @options.chart.paddingBottom
    
    @interval = @max_data - @min_data
    @inner_width = @graph_width - (@options.graph.marginLeft + @options.graph.marginRight)
    @inner_height = @graph_height - (@options.graph.marginTop + @options.graph.marginBottom)

    @pl = @options.chart.paddingLeft
    @pt = @options.chart.paddingTop

    ## build plot position
    for item in @data
      barWidth = @inner_width / (_.size(item.data)-1)
      item.plot = []
      for value in item.data
        if value?
          item.plot.push
            x: @pl + (_j)*barWidth + @options.graph.marginLeft
            y: @pt + @inner_height - (value-@min_data) / @interval * @inner_height + @options.graph.marginTop
        else
          item.plot.push null

    @xAxiz_zero_position = @pt + @inner_height - (0-@min_data) / @interval * @inner_height + @options.graph.marginTop

  preprocess_style: ->
    @ctx.font = @font_format(@options.chart.font)

    if @options.legend.enable
      legend_height = parseInt(@options.legend.font.size.replace('px',''))*2 + @options.legend.marginTop + @options.legend.marginBottom
      @options.chart.paddingBottom += legend_height

  drawGraph: ->
    @ctx.strokeStyle = @options.chart.color
    @horizontal_line()
    @vertical_line()

    for line in @data
      @addLine line

    @addFlag @ipo, "IPO\nDATE" if @ipo?
    @process_legend() if @options.legend.enable

    # @ctx.drawImage(c , @options.chart.paddingLeft, @options.chart.paddingTop, @graph_width, @graph_height)

  horizontal_line: () ->
    interval = @max_data - @min_data
    lines = @options.yAxis.breaks
    @ctx.beginPath()

    height = @graph_height - (@options.graph.marginTop + @options.graph.marginBottom)

    for i in [0..@options.yAxis.breaks]
      value = @min_data + interval / lines * i
      y = height - height / lines * i + @options.graph.marginTop
      
      ## fill stripe background
      if @options.graph.background_stripe
        if i % 2 is 0
          @ctx.fillStyle = @options.graph.background_stripe
          @ctx.fillRect( @pl + @options.graph.marginLeft + @options.chart.lineWidth, @pt + y-height/lines - @options.chart.lineWidth - 1, @pl + @graph_width, @pt + height/lines - @options.chart.lineWidth - 1)
        # else
        #   @ctx.fillStyle = @options.graph.background
        #   @ctx.fillRect( @pl +@options.graph.marginLeft + @options.chart.lineWidth, @pt + y, @pl + @graph_width, @pt + height/lines - @options.chart.lineWidth)

      if @options.yAxis.grid.enable
        @ctx.strokeStyle = @options.chart.color
        @dashedLine @ctx, @pl + @options.graph.marginLeft, @pt + y, @pl + @graph_width, @pt + y, 2

      # fill text label
      if @options.yAxis.label.enable
        @ctx.fillStyle = @options.yAxis.label.color or @options.chart.label.color
        @ctx.font = @font_format(@options.yAxis.label.font)
        if @options.yAxis.label.align is 'left'
          @ctx.textAlign = 'right'
          @ctx.textBaseline = 'middle'
          start_position = @pl + @options.graph.marginLeft - 10
          start_position -= @options.yAxis.tick.size if @options.yAxis.tick.enable
        else
          @ctx.textAlign = 'left'
          @ctx.textBaseline = 'bottom'
          start_position = @pl + @options.graph.marginLeft
        @ctx.fillText @options.yAxis.label.prefix + @auto_format(value) + @options.yAxis.label.suffix, start_position, @pt + y

      # draw tick
      if @options.yAxis.tick.enable
        @ctx.beginPath()
        @ctx.strokeStyle = @options.chart.color
        @ctx.moveTo @pl + @options.graph.marginLeft - @options.chart.lineWidth + 1, @pt + y
        @ctx.lineTo @pl + @options.graph.marginLeft - @options.chart.lineWidth - @options.yAxis.tick.size + 1, @pt + y
        @ctx.stroke()
        @ctx.closePath()

    @ctx.stroke()

    if @options.xAxis.border.enable
      @ctx.strokeStyle = @options.xAxis.border.color
      @ctx.lineWidth = @options.chart.lineWidth
      @ctx.moveTo @pl + @options.graph.marginLeft, @xAxiz_zero_position
      @ctx.lineTo @pl + @graph_width, @xAxiz_zero_position
      @ctx.stroke()

    @ctx.closePath()

  vertical_line: () ->
    width = @graph_width - (@options.graph.marginLeft + @options.graph.marginRight)

    @ctx.beginPath()
    @ctx.textAlign = 'center'
    @ctx.fillStyle = @options.xAxis.color or @options.chart.color
    @ctx.strokeStyle = @options.xAxis.color or @options.chart.color

    if @options.xAxis.data? and @options.xAxis.data.length > 0
      barWidth = width / @options.xAxis.data.length
      for value in @options.xAxis.data
        x = (_i+1) * barWidth + @options.graph.marginLeft
        y = @graph_height - @options.graph.marginBottom

        # label
        if @options.xAxis.label.enable
          @ctx.fillStyle = @options.xAxis.label.color or @options.chart.label.color
          @ctx.font = @font_format(@options.xAxis.label.font)
          _x = x
          if @options.xAxis.label.align is 'center'
            _x = x - barWidth/2
          # if @options.xAxis.tick.enable
          _y = y + @options.xAxis.tick.size

          @ctx.textBaseline = 'top'
          @ctx.fillText @options.xAxis.label.prefix + value + @options.xAxis.label.suffix, @pl + _x, @pt + _y

        # gird
        if @options.xAxis.grid.enable
          if @options.xAxis.grid.align is 'center'
            _x = x - barWidth/2
          else
            _x = x
          @ctx.lineWidth = 0.5
          @dashedLine @ctx, @pl + _x, @pt, @pl + _x, @pt + y, 2

        # tick
        if @options.xAxis.tick.enable
          if @options.xAxis.tick.align is 'center'
            _x = x - barWidth/2
          else
            _x = x
          @ctx.beginPath()
          @ctx.lineWidth = @options.chart.lineWidth
          @ctx.moveTo @pl + _x, @pt + y
          @ctx.lineTo @pl + _x, @pt + y + @options.xAxis.tick.size
          @ctx.stroke()

    if @options.yAxis.border.enable
      @ctx.strokeStyle = @options.yAxis.border.color
      @ctx.lineWidth = @options.chart.lineWidth
      @ctx.moveTo @pl + @options.graph.marginLeft, @pt
      @ctx.lineTo @pl + @options.graph.marginLeft, @pt + @graph_height - @options.graph.marginBottom
      @ctx.stroke()

    @ctx.closePath()

  shade: () ->
    before_above = null
    above_color = 'rgba(253, 115, 109, 0.4)' # '#fd726d'
    below_color = 'rgba(0, 183, 151, 0.4)'  # '#00bd9c'
    @ctx.fillStyle = above_color
    last_change = 0
    start = false
    for i in [0..@data[0].plot.length]
      if (!@data[0].plot[i]? or !@data[1].plot[i]?) and !start
        last_change = i + 1

      else if (!@data[0].plot[i]? or !@data[1].plot[i]?) and start
        for index in [i-1..last_change]
          @ctx.lineTo @data[1].plot[index].x, @data[1].plot[index].y
        @ctx.closePath()
        @ctx.fillStyle = if before_above then above_color else below_color
        @ctx.fill()
        break

      else if @data[0].plot[i]? and @data[1].plot[i]? and !start
        @ctx.beginPath()
        @ctx.moveTo @data[0].plot[i].x, @data[0].plot[i].y
        start = true

      else
        above = if @data[0].plot[i].y < @data[1].plot[i].y then true else false
        change = if before_above? and before_above != above then true else false

        if !change
          @ctx.lineTo @data[0].plot[i].x, @data[0].plot[i].y
        else
          if @data[0].plot[i-1]? and @data[1].plot[i-1]?
            y1 = @data[0].plot[i-1].y
            y2 = @data[0].plot[i].y
            a = y1 - _min([y1, y2])
            b = y2 - _min([y1, y2])
            barWidth = @data[0].plot[i].x - @data[0].plot[i-1].x
            x = @data[0].plot[i-1].x + (a * barWidth / (a + b))
            y = _min([y1, y2]) + (a*b) / (a+b)
            @ctx.lineTo x, y
            @ctx.lineTo @data[1].plot[index].x, @data[1].plot[index].y for index in [i..last_change]
            @ctx.closePath()
            @ctx.fillStyle = if above then below_color else above_color
            @ctx.fill()

            @ctx.beginPath()
            @ctx.moveTo @data[0].plot[i-1].x, @data[0].plot[i-1].y
            @ctx.lineTo x, y
            @ctx.lineTo @data[0].plot[i].x, @data[0].plot[i].y

            last_change = i

        before_above = above