

jQuery ($) ->
  target = new google.maps.LatLng(59.3313, 18.071)
  markers = []
  matrix = []
  steps  = 16
  width  = $('.container').width()
  bpm = 120
  markerAnimationDelay = 300
  animationStyle = google.maps.Animation.DROP

  # How long the beat is in milliseconds
  beatInterval = 1 / (bpm / 60) * 1000

  init = () ->


      $('#showOverlay').click ->
        if this.checked
          $('#overlay').fadeIn()
        else
          $('#overlay').fadeOut()


      $('#animationStyle').change (v) ->
        animationStyle = google.maps.Animation[this.value]
        if this.value == google.maps.Animation.DROP
          markerAnimationDelay = 400
        else
          markerAniamtionDelay = 0


      # Setup map options
      mapOptions =
          center: target
          zoom: 15
          streetViewControl: false
          panControl: false
          mapTypeId: google.maps.MapTypeId.ROADMAP
          zoomControlOptions:
              style: google.maps.ZoomControlStyle.SMALL
          mapTypeControlOptions:
              mapTypeIds: [google.maps.MapTypeId.ROADMAP, 'map_style']

      # Create the map with above options in div
      map = window.map = new google.maps.Map(document.getElementById("map"),mapOptions)

      # Create a request field to hold POIs
      request =
          location: target
          radius: 400

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


      highlightCell = (node, delay = 0) ->
        setTimeout ->
          node.addClass('active')
          setTimeout ->
            node.removeClass('active')
          , 500
        , delay

      bounceMarker = (marker) ->
        marker.setAnimation(animationStyle)
        setTimeout ->
          marker.setAnimation(google.maps.Animation.NONE)
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

        constructor: ->
          @compressor = context.createDynamicsCompressor()
          @compressor.connect(context.destination)
          paths = []
          for i in [1..16]
            paths.push "samples/woody/woody_#{i}.ogg"
          bufferLoader = new BufferLoader(
            context
            paths
            (@bufferList) =>
          )

          bufferLoader.load()

        play: (index, delay = 0) ->
          note = context.createBufferSource()
          note.buffer = @bufferList[index]
          note.connect(@compressor)
          setTimeout ->
            note.noteOn(0)
          , delay

      @audioPlayer = window.audioPlayer = new AudioPlayer
      @start()







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