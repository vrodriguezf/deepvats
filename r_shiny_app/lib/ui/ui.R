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