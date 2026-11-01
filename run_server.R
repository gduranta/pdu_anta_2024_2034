# Script de inicio rapido del servidor Shiny GeoVisor PDU Anta
# Puerto 3838, accesible en localhost y red local (0.0.0.0)

options(shiny.host = "0.0.0.0")
options(shiny.port = 3838)
options(shiny.launch.browser = FALSE)

cat("\n=======================================================\n")
cat(" GeoVisor PDU Anta - Servidor Shiny Inicializado\n")
cat(" Escuchando en: http://0.0.0.0:3838\n")
cat("=======================================================\n\n")

shiny::runApp(appDir = ".", host = "0.0.0.0", port = 3838, launch.browser = FALSE)

