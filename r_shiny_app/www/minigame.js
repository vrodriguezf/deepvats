Shiny.addCustomMessageHandler('initGame', function(message) {
    let gameButton = document.getElementById('game_button');
    let gameMessage = document.getElementById('game_message');

    gameButton.onclick = function() {
        gameMessage.innerHTML = '¡Has hecho click!';
        gameButton.disabled = true;
    };
});
