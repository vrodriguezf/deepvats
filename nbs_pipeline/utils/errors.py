def custom_error(message):
    # Código ANSI para texto en rojo
    red_start = "\033[91m"
    # Código ANSI para restablecer el color
    reset = "\033[0m"
    raise Exception(red_start + message + reset)