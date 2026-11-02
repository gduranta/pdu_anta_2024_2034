# ==============================================================================
# GENERADOR DE MANIFEST.JSON PARA PUBLICAR SOLO LA MÁSCARA DE GITHUB PAGES
# GDUR - MUNICIPALIDAD PROVINCIAL DE ANTA
# ==============================================================================

# Fijar directorio de trabajo en la raíz del proyecto
directorio_raiz <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")
    dirname(dirname(script_path))
  } else {
    getwd()
  }
}, error = function(e) getwd())

if (file.exists(file.path(directorio_raiz, "app.R"))) {
  setwd(directorio_raiz)
} else if (file.exists("app.R")) {
  directorio_raiz <- getwd()
} else if (file.exists("pdu_anta_2024_2034/app.R")) {
  setwd("pdu_anta_2024_2034")
  directorio_raiz <- getwd()
}

message("GitHub Pages sirve únicamente docs/. El despliegue privado del backend requiere un repositorio privado y no se genera desde aquí.")
