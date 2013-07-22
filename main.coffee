

jQuery ($) ->
  coords = (hash.get('coords') || "").split(',')
  target = new google.maps.LatLng(coords[0] || 59.32815833916834, coords[1] || 18.079346359863283)
  markers = []
  matrix = []
  steps  = 16
  width  = $('.container').width()
  bpm = 120
  window.markerAnimationDelay = 300
  animationStyle = google.maps.Animation.DROP
  currentDataset = hash.get('dataset') || 'restaurant'
  options =
    sequencer: hash.get('sequencer') || 'off'
    tempo: hash.get('tempo') || '120'
    instrument: hash.get('instrument') || 'wood'
    animation: hash.get('animation') || 'drop'

  # How long the beat is in milliseconds
  beatInterval = 1 / (bpm / 60) * 1000

  init = () ->

      generateURL = ->
        coords = map.getCenter().toUrlValue()
        hash.add coords: coords
        hash.add dataset: currentDataset
        hash.add options
        $("#datalist ul").empty()

        for type, index in datatypes
          li = document.createElement('li')
          li.className = 'datatype'

          if Array.isArray(type)
            text = type[1]
            $(li).attr('data-type', type[0])
          else
            $(li).attr('data-type', type)
            text = "#{type}s"
          text = text.split('_').join(' ')
          li.innerHTML = text
          column = Math.floor(index / 30)
          $("#datalist .column#{column}").append(li)

      $('body').click (event) ->
        if event.target.id != 'currentDataset' && !$(event.target).closest('#datalist').length
          $('#datalist').fadeOut('fast')

      $('#currentDataset').click (event) ->
        $('#datalist').fadeIn('fast')

      $('#datalist').on 'click', '.datatype', (event) =>
        $('#currentDataset').text($(event.target).text())
        $('#datalist').fadeOut('fast')
        currentDataset = $(event.target).data('type')
        generateURL()
        @search()


      updateOptions = ->
        if options.sequencer == 'on' then $('#overlay').fadeIn() else $('#overlay').fadeOut()

        if (newInterval = 1 / (options.tempo / 60) * 1000) != beatInterval
          beatInterval = newInterval
          @start()

        animationStyle = google.maps.Animation[options.animation.toUpperCase()]
        if animationStyle == google.maps.Animation.DROP
          markerAnimationDelay = 300
        else
          markerAnimationDelay = 0

        for key, value of options
          el = $("#navigation [data-property=#{key}]")
          el.find('.currentState').text(value)

        format = $("#navigation [data-name=#{options.instrument}]").data('format')
        @audioPlayer.selectInstrument(options.instrument, format)

        generateURL()


      $('.subitem').click ->
        value = $(this).text()
        parent = $(this).parents('.item')
        property = parent.data('property')
        options[property] = value.toLowerCase()
        updateOptions()

      # Setup map options
      mapOptions =
          center: target
          zoom: 14
          streetViewControl: false
          panControl: false
          mapTypeId: google.maps.MapTypeId.ROADMAP
          zoomControlOptions:
              style: google.maps.ZoomControlStyle.SMALL
          mapTypeControlOptions:
              mapTypeIds: [google.maps.MapTypeId.ROADMAP, 'map_style']

      # Create the map with above options in div
      map = window.map = new google.maps.Map(document.getElementById("map"),mapOptions)

      @search = ->
        # Clean up all existing markers first
        for marker in markers
          marker.setMap(null)

        markers = []
        # Create a request field to hold POIs
        request =
            location: target
            radius: 4000
            types: [currentDataset]

        # Setup places nearby search (it setups points near the center marker)
        service = new google.maps.places.PlacesService(map)
        service.nearbySearch(request, callback)

      overlay = new google.maps.OverlayView();
      overlay.draw = ->
      overlay.setMap(map)

      for i in [0..steps-1]
        row = document.createElement('tr')
        $('#matrix').prepend(row)
        for j in [0..steps-1]
          row.appendChild(document.createElement('td'))

      getCellPosition = (x, y) ->
        row = Math.floor(x / width * steps)
        col = Math.floor(y / width * steps)
        [row, col]

      clearMatrix = ->
        matrix = []
        $('table td').removeClass('on')

      turnOnCell = (row, col, marker) ->
        matrix[col] ||= {}

        cell = matrix[col][row] ||= {}
        cell.markers ||= []
        cell.markers.push marker

        cell.node = $($('#matrix')[0].rows[row].cells[col])
        cell.node.addClass('on')

      window.updateMatrix = ->
        clearMatrix()
        proj = overlay.getProjection()
        for marker in markers
          pos = marker.getPosition()
          p = proj.fromLatLngToContainerPixel(pos)
          [row, col] = getCellPosition(p.y, p.x)
          if row >= 0 && row < steps && col >= 0 && col < steps
            turnOnCell(row, col, marker)

        matrix

      for event in ['bounds_changed']
        google.maps.event.addListener map, event, ->
          updateMatrix()

      google.maps.event.addListener map, 'idle', ->
        generateURL()


      highlightCell = (node, delay = 0) ->
        setTimeout ->
          node.addClass('active')
          setTimeout ->
            node.removeClass('active')
          , 100
        , delay

      bounceMarker = (marker) ->
        marker.setAnimation(animationStyle)
        setTimeout ->
          marker.setAnimation(google.maps.Animation)
        , 700

      @start = ->
        clearInterval(@interval)
        currentStep = 0
        @interval = setInterval ->
          if activeCells = matrix[currentStep]
            for row, cell of activeCells
              for marker in cell.markers
                bounceMarker(marker)

              highlightCell(cell.node, markerAnimationDelay)
              @audioPlayer.play(row, markerAnimationDelay)


          currentStep++
          if currentStep >= steps
            currentStep = 0
        , beatInterval * 0.25

      context = new webkitAudioContext()

      class AudioPlayer

        constructor: () ->
          @instruments = {}
          @compressor = context.createDynamicsCompressor()
          @compressor.connect(context.destination)

        selectInstrument: (name, format)->
          unless @bufferList = @instruments[name]
            paths = []
            for i in [1..16]
              paths.push "samples/#{name}/#{name}#{i}.#{format}"
            bufferLoader = new BufferLoader(
              context
              paths
              (@bufferList) =>
                @instruments[name] = @bufferList
            )
            bufferLoader.load()

        play: (index, delay = 0) ->
          return unless @bufferList
          note = context.createBufferSource()
          note.buffer = @bufferList[index]
          note.connect(@compressor)
          setTimeout ->
            note.noteOn(0)
          , delay

      @search()
      @audioPlayer = new AudioPlayer
      @start()
      updateOptions()



  # Create the callback function to loop thru the places (object)
  callback = (results, status) ->
    if status is google.maps.places.PlacesServiceStatus.OK
        for index, attrs of results
             createMarker results[index]
    updateMatrix()


  # Create the actual markers for the looped places
  createMarker = (place) ->
    marker = new google.maps.Marker
     map: map
     title:place.types.join '-'
     position: place.geometry.location

    markers.push marker


  init()