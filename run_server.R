# Script de inicio rapido del servidor Shiny GeoVisor PDU Anta
# Puerto 3838, accesible en localhost y red local (0.0.0.0)

options(shiny.host = "0.0.0.0")
options(shiny.port = 3838)
options(shiny.launch.browser = FALSE)
options(shiny.sanitize.errors = TRUE) # Blindaje CWE-209: Oculta rutas internas y stack traces en consola del cliente

# Blindaje de Ciberseguridad SEC-05: Políticas de Enmarcado HTTP (CWE-1021)
shiny::shinyOptions(
  httpResponseHeaders = list(
    "Content-Security-Policy" = "frame-ancestors 'self' https://antapat.github.io https://*.munianta.gob.pe http://localhost:* http://127.0.0.1:*;",
    "X-Content-Type-Options" = "nosniff",
    "Referrer-Policy" = "strict-origin-when-cross-origin"
  )
)

cat("\n=======================================================\n")
cat(" GeoVisor PDU Anta - Servidor Shiny Inicializado\n")
cat(" Escuchando en: http://0.0.0.0:3838\n")
cat("=======================================================\n\n")

shiny::runApp(appDir = ".", host = "0.0.0.0", port = 3838, launch.browser = FALSE)

