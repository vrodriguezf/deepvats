#HTML script for logging renderization times.

log_script <- HTML("
    function saveLogInLocalStorage(functionName, timeDiff) {
      var filename = 'app/witc2024_6';
      var existingLogs = localStorage.getItem(filename);
      existingLogs = existingLogs ? JSON.parse(existingLogs) : [];
      existingLogs.push({ functionName: functionName, timeDiff: timeDiff, timestamp: new Date().toISOString() });
      localStorage.setItem(filename, JSON.stringify(existingLogs));
    }

    function showLogs() {
      var filename = 'app/witc2024_6';
      var logs = localStorage.getItem(filename);
      if (logs) {
        // Mostrar los logs en el contenedor de la UI
        Shiny.setInputValue('logData', logs);
      }
    }

    $(document).ready(function() {
      Shiny.addCustomMessageHandler('showLogs', function(message) {
        showLogs();
      });
    });
  

    var timers = {
      'projections_plot': null,
      'ts_plot_dygraph': null
    }

    var timeTaken = {
      'projections_plot': null,
      'ts_plot_dygraph': null
    }

    var renderTimes = {
      'projections_plot': [],
      'ts_plot_dygraph': []
    }

    $(document).on('shiny:outputinvalidated', function(event) {
      if (timers.hasOwnProperty(event.target.id)) {
        timers[event.target.id] = new Date().getTime();
        console.log('Start rendering ' + event.target.id);
      }
    });

    $(document).on('shiny:value', function(event) {
      if (timers.hasOwnProperty(event.target.id) && timers[event.target.id] != null) {
          var endTime = new Date().getTime();
          var timeDiff = endTime - timers[event.target.id];
          console.log('Pushing time for ' + event.target.id + ': ' + timeDiff + ' ms');
          renderTimes[event.target.id].push(timeDiff);
          Shiny.setInputValue('renderTimes', JSON.stringify(renderTimes)); // Enviar el objeto como un string JSON
          console.log('Render time for ' + event.target.id + ': ' + timeDiff + ' ms');
          
          timers[event.target.id] = null;
          timeTaken[event.target.id] = null;
        }
      }); 
    ")

rotate_script <- HTML("
  #TB {
    transform: rotate(-90deg);
    transform-origin: left top 0;
    position: absolute;
    left: -300px; /* Ajusta este valor para posicionar la gráfica rotada */
    top: 50px; /* Ajusta este valor para posicionar la gráfica rotada */
  }
")

tsb_style <- "transform: rotate(-90deg); transform-origin: left top 0; position: absolute; left: -300px; top: 50px;"

# Define a function to rotate any plot output
rotate_plot <- function(id, degree = -90, left = "-300px", top = "50px") {
  tags$head(
    tags$style(HTML(sprintf("
      #%s {
        transform: rotate(%ddeg);
        transform-origin: left top 0;
        position: absolute;
        left: %s;
        top: %s;
      }
    ", id, degree, left, top)))
  )
}


rotate_plot_style <- "
  .rotated-container {
    position: relative;
    width:  100%;
    height: 100%;
  }
  .rotated {
    transform:        rotate(-90deg);
    transform-origin: left top;
    position:         absolute;
    width:            100%;
    height:           100%;
    top:              0;
    left:             0;
    
  }
  .grid-container {
    display: grid;
    grid-template-areas: 
      'header'
      'tb mplot'
      'tb mplot';
    grid-template-rows: auto 1fr auto;
    grid-template-columns: 1fr 4fr;
    gap: 10px;
    width: 100%;
    height: 100%; 
  }
  .grid-header {
    grid-area: header;
    width: 100%;
  }
  .grid-tb {
    grid-area: tb;
    position:relative;
  }
  .grid-ta {
    grid-area: ta;
    width: 100%;
  }
  .grid-mplot {
    grid-area: mplot;
    width: 100%;
  }
"