

jQuery ($) ->
  target = new google.maps.LatLng(59.33, 18.07)
  markers = []
  matrix = []
  steps  = 16
  width  = 400
  bpm = 120

  # How long the beat is in milliseconds
  beatInterval = 1 / (bpm / 60) * 1000

  init = () ->


      $('#showOverlay').click ->
        if this.checked
          $('#overlay').fadeIn()
        else
          $('#overlay').fadeOut()
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

      # Drop marker in the same location
      marker = new google.maps.Marker
          map: map
          animation: google.maps.Animation.DROP
          position: mapOptions.center
          icon: 'http://www.google.com/intl/en_us/mapfiles/ms/micons/red-dot.png'

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

      turnOnCell = (row, col) ->
        matrix[row] ||= []
        matrix[row].push(col) unless col in matrix[row]
        cell = $('#matrix')[0].rows[row].cells[col]
        $(cell).addClass('on')

      window.updateMatrix = ->
        clearMatrix()
        proj = overlay.getProjection()
        for marker in markers
          pos = marker.getPosition()
          p = proj.fromLatLngToContainerPixel(pos)
          [row, col] = getCellPosition(p.y, p.x)
          if row >= 0 && row < steps && col >= 0 && col < steps
            turnOnCell(row, col)

        matrix

      for event in ['bounds_changed']
        google.maps.event.addListener map, event, ->
          updateMatrix()


      currentStep = 0
      setInterval ->
        currentStep++
        $('#matrix td').removeClass('active')
        $($('#matrix')[0].rows).find("td:nth-child(#{currentStep}).on").addClass('active')

        if activeCells = matrix[currentStep]
          for cell in activeCells
            @audioPlayer.play(cell)


        if currentStep >= steps
          currentStep = 0
      , beatInterval * 0.25

      context = new webkitAudioContext()

      class AudioPlayer

        constructor: ->
          paths = []
          for i in [1..16]
            paths.push "samples/bell#{i}.wav"
          bufferLoader = new BufferLoader(
            context
            paths
            (@bufferList) =>
          )

          bufferLoader.load()

        play: (index) ->
          note = context.createBufferSource()
          note.buffer = @bufferList[index]
          note.connect(context.destination)
          note.noteOn(0)

      @audioPlayer = window.audioPlayer = new AudioPlayer








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