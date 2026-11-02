# Script de inicio rapido del servidor Shiny GeoVisor PDU Anta
# Puerto 3838 enlazado exclusivamente a loopback; use proxy/firewall LAN con TLS.

host_local <- Sys.getenv("PDU_SHINY_HOST", "127.0.0.1")
if (!identical(host_local, "127.0.0.1") && !identical(host_local, "::1")) {
  stop("Por seguridad, el servidor Shiny solo puede enlazarse a loopback. Configure TLS y un proxy local independiente para exponerlo.")
}
options(shiny.host = host_local)
options(shiny.port = 3838)
options(shiny.launch.browser = FALSE)
options(shiny.sanitize.errors = TRUE) # Blindaje CWE-209: Oculta rutas internas y stack traces en consola del cliente

# Blindaje de Ciberseguridad SEC-05: Políticas de Enmarcado HTTP (CWE-1021)
shiny::shinyOptions(
  httpResponseHeaders = list(
    "Content-Security-Policy" = "default-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; img-src 'self' data: blob: https://*.tile.openstreetmap.org https://server.arcgisonline.com; font-src 'self' data: https://cdnjs.cloudflare.com; connect-src 'self' ws: wss: https://*.tile.openstreetmap.org https://server.arcgisonline.com; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'self' https://antapat.github.io https://*.munianta.gob.pe http://localhost:* http://127.0.0.1:*;",
    "X-Content-Type-Options" = "nosniff",
    "Referrer-Policy" = "strict-origin-when-cross-origin",
    "Permissions-Policy" = "geolocation=(self), camera=(), microphone=(), payment=()",
    "Cache-Control" = "no-store"
  )
)

cat("\n=======================================================\n")
cat(" GeoVisor PDU Anta - Servidor Shiny Inicializado\n")
cat(" Escuchando en: http://", host_local, ":3838\n", sep = "")
cat("=======================================================\n\n")

shiny::runApp(appDir = ".", host = host_local, port = 3838, launch.browser = FALSE)

