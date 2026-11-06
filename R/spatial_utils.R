# Utilidades espaciales seguras para el GeoVisor PDU Anta.

CRS_GEOGRAFICO <- 4326
CRS_METRICO_ANTA <- 32718
BBOX_VALIDACION_ANTA <- c(xmin = -72.50, ymin = -13.80, xmax = -71.90, ymax = -13.10)

validar_coordenada_punto <- function(lng, lat) {
  valores <- suppressWarnings(as.numeric(c(lng, lat)))
  if (any(!is.finite(valores))) stop("Las coordenadas deben ser valores numéricos finitos.")
  if (valores[1] < BBOX_VALIDACION_ANTA["xmin"] || valores[1] > BBOX_VALIDACION_ANTA["xmax"] ||
      valores[2] < BBOX_VALIDACION_ANTA["ymin"] || valores[2] > BBOX_VALIDACION_ANTA["ymax"]) {
    stop("Las coordenadas se encuentran fuera del entorno geográfico admitido para Anta.")
  }
  invisible(TRUE)
}

normalizar_poligono_predio <- function(objeto_sf, max_entidades = 200, max_area_m2 = 2e8) {
  if (!inherits(objeto_sf, "sf") || nrow(objeto_sf) == 0) stop("El archivo no contiene entidades espaciales.")
  if (nrow(objeto_sf) > max_entidades) stop("El archivo excede el máximo de 200 entidades permitido.")
  if (is.na(sf::st_crs(objeto_sf))) stop("El archivo no declara un sistema de coordenadas (CRS).")
  if (any(sf::st_is_empty(objeto_sf))) objeto_sf <- objeto_sf[!sf::st_is_empty(objeto_sf), , drop = FALSE]
  if (nrow(objeto_sf) == 0) stop("Todas las geometrías del archivo están vacías.")

  objeto_sf <- sf::st_make_valid(objeto_sf)
  tipos <- unique(as.character(sf::st_geometry_type(objeto_sf)))
  if (!all(tipos %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION"))) {
    stop("El archivo debe contener únicamente polígonos o multipolígonos de predios.")
  }

  geom_poligono <- suppressWarnings(sf::st_collection_extract(sf::st_geometry(objeto_sf), "POLYGON"))
  if (length(geom_poligono) == 0 || all(sf::st_is_empty(geom_poligono))) {
    stop("No se encontraron polígonos utilizables en el archivo.")
  }
  geom_unificada <- sf::st_union(geom_poligono)
  predio <- sf::st_sf(id = 1L, geometry = geom_unificada)
  predio <- sf::st_transform(predio, CRS_GEOGRAFICO)

  bb <- sf::st_bbox(predio)
  if (bb["xmax"] < BBOX_VALIDACION_ANTA["xmin"] || bb["xmin"] > BBOX_VALIDACION_ANTA["xmax"] ||
      bb["ymax"] < BBOX_VALIDACION_ANTA["ymin"] || bb["ymin"] > BBOX_VALIDACION_ANTA["ymax"]) {
    stop("El predio se encuentra fuera del entorno geográfico admitido para Anta.")
  }

  area_m2 <- as.numeric(sf::st_area(sf::st_transform(predio, CRS_METRICO_ANTA)))
  if (!is.finite(area_m2) || area_m2 <= 0) stop("El predio debe tener un área mayor que cero.")
  if (area_m2 > max_area_m2) stop("El predio excede el área máxima admitida para una consulta.")
  predio
}

#' Calcula el área de intersección neta (m²) entre un predio y una capa espacial,
#' optimizado mediante filtrado previo por índice espacial (R-tree) para evitar
#' operaciones de unión sobre toda la capa cuando no hay contacto.
area_interseccion_unica_m2 <- function(predio_4326, capa_4326) {
  if (is.null(capa_4326) || nrow(capa_4326) == 0) return(0)
  
  # 1. Filtrado espacial indexado rápido antes de unir geometrías
  idx <- suppressMessages(sf::st_intersects(predio_4326, capa_4326, sparse = TRUE)[[1]])
  if (length(idx) == 0) return(0)
  
  capa_sub <- capa_4326[idx, , drop = FALSE]
  capa_unida <- if (nrow(capa_sub) == 1) {
    sf::st_geometry(capa_sub)
  } else {
    sf::st_union(sf::st_geometry(capa_sub))
  }
  
  inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(predio_4326), capa_unida))
  if (length(inter) == 0 || all(sf::st_is_empty(inter))) return(0)
  sum(as.numeric(sf::st_area(sf::st_transform(inter, CRS_METRICO_ANTA))), na.rm = TRUE)
}

#' Busca vías colindantes a una entidad espacial dentro de una distancia máxima (en metros).
#' Utiliza filtrado espacial indexado con buffer para evitar calcular distancias sobre toda la red vial.
#' @param geom_utm Geometría (punto o polígono) en CRS métrico (32718)
#' @param vias_utm Capa de vías en CRS métrico (32718)
#' @param dist_max_m Distancia máxima de búsqueda en metros (por defecto 25 m)
#' @return Lista con índices de vías cercanas, distancias calculadas, índice mínimo y distancia mínima
pdu_buscar_vias_colindantes <- function(geom_utm, vias_utm, dist_max_m = 25.0) {
  if (is.null(vias_utm) || nrow(vias_utm) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  buf <- sf::st_buffer(geom_utm, dist_max_m)
  candidatos <- suppressMessages(sf::st_intersects(buf, vias_utm)[[1]])
  if (length(candidatos) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  dists_cand <- as.numeric(sf::st_distance(geom_utm, vias_utm[candidatos, , drop = FALSE]))
  validos <- which(dists_cand <= dist_max_m)
  if (length(validos) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  indices <- candidatos[validos]
  distancias <- dists_cand[validos]
  idx_min_rel <- which.min(distancias)
  list(
    indices = indices,
    distancias = distancias,
    min_idx = indices[idx_min_rel],
    min_dist = distancias[idx_min_rel]
  )
}

extraer_zip_seguro <- function(archivo_zip, destino, max_archivos = 100, max_descomprimido = 100 * 1024^2) {
  listado <- utils::unzip(archivo_zip, list = TRUE)
  if (nrow(listado) == 0) stop("El archivo ZIP está vacío.")
  if (nrow(listado) > max_archivos) stop("El ZIP contiene demasiados archivos.")
  nombres <- gsub("\\\\", "/", listado$Name)
  inseguro <- grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", nombres)
  if (any(inseguro)) stop("El ZIP contiene rutas no permitidas.")
  if (sum(listado$Length, na.rm = TRUE) > max_descomprimido) stop("El ZIP excede 100 MB descomprimido.")
  dir.create(destino, showWarnings = FALSE, recursive = TRUE)
  utils::unzip(archivo_zip, exdir = destino)
  invisible(destino)
}

ejecutando_en_shinyapps <- function() {
  ruta_trabajo <- gsub("\\\\", "/", normalizePath(getwd(), winslash = "/", mustWork = FALSE))
  nzchar(Sys.getenv("RSCONNECT_APPLICATION")) ||
    grepl("/srv/connect/apps/", ruta_trabajo, fixed = TRUE)
}

quarto_disponible <- function() {
  if (nzchar(Sys.getenv("QUARTO_PATH")) && file.exists(Sys.getenv("QUARTO_PATH"))) {
    return(TRUE)
  }
  es_valido <- tryCatch({
    q_path <- quarto::quarto_path()
    !is.null(q_path) && nzchar(q_path) && file.exists(q_path)
  }, error = function(e) FALSE)
  if (isTRUE(es_valido)) return(TRUE)
  
  en_path <- Sys.which("quarto")
  if (nzchar(en_path) && file.exists(en_path)) {
    Sys.setenv(QUARTO_PATH = normalizePath(en_path, winslash = "/", mustWork = FALSE))
    return(TRUE)
  }
  
  candidatos <- c(
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "quarto.exe"),
    file.path(Sys.getenv("ProgramFiles"), "Quarto", "bin", "quarto.exe"),
    "C:/Program Files/Quarto/bin/quarto.exe",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
    "C:/Program Files/RStudio/bin/quarto/bin/quarto.exe"
  )
  candidatos <- candidatos[nzchar(candidatos) & file.exists(candidatos)]
  if (length(candidatos) > 0) {
    ruta <- normalizePath(candidatos[1], winslash = "/", mustWork = TRUE)
    Sys.setenv(QUARTO_PATH = ruta)
    dir_q <- dirname(ruta)
    p_actual <- Sys.getenv("PATH")
    if (!grepl(dir_q, p_actual, fixed = TRUE)) {
      Sys.setenv(PATH = paste(dir_q, p_actual, sep = ";"))
    }
    return(TRUE)
  }
  
  FALSE
}

chrome_disponible <- function() {
  # La impresión con Chrome puede agotar o detener el contenedor de shinyapps.io.
  if (ejecutando_en_shinyapps()) return(FALSE)
  tryCatch({
    ruta <- pagedown::find_chrome()
    length(ruta) == 1 && !is.na(ruta) && nzchar(ruta) && file.exists(ruta)
  }, error = function(e) FALSE)
}

pdf_motor_disponible <- function() {
  quarto_disponible() || chrome_disponible()
}

#' Copia segura de archivos blindada contra 'could not allocate copy buffer' (CWE-400)
#' Base R en Windows utiliza file.append() cuando el destino es un archivo, el cual intenta
#' un malloc() contiguo de 1MB en el heap de C. En procesos con alto consumo geoespacial o
#' fragmentación de memoria, esto detiene la ejecución.
#' Esta función utiliza en primer lugar el API nativo del sistema operativo (CopyFileW vía
#' copia a directorio contenedor o Shell), y en última instancia streaming binario en bloques pequeños.
#'
#' @param from Ruta del archivo origen
#' @param to Ruta de destino (directorio existente o ruta de archivo destino)
#' @param overwrite Sobrescribir si ya existe
#' @return TRUE si la copia fue exitosa y verificada, FALSE de lo contrario
pdu_safe_copy_file <- function(from, to, overwrite = TRUE) {
  if (!is.character(from) || length(from) != 1L || !file.exists(from)) return(FALSE)
  if (!is.character(to) || length(to) != 1L) return(FALSE)
  
  # Caso 1: Destino es un directorio existente -> file.copy nativo usa Win32 CopyFileW directamente
  if (dir.exists(to)) {
    return(isTRUE(file.copy(from, to, overwrite = overwrite)))
  }
  
  dir_dest <- dirname(to)
  if (!dir.exists(dir_dest)) {
    dir.create(dir_dest, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (file.exists(to)) {
    if (!overwrite) return(FALSE)
    unlink(to, force = TRUE)
  }
  
  # Caso 2: Si el nombre base coincide, copiar directo al directorio contenedor (usa CopyFileW del OS)
  if (identical(basename(from), basename(to))) {
    if (isTRUE(file.copy(from, dir_dest, overwrite = overwrite))) {
      return(file.exists(to))
    }
  }
  
  # Caso 3: Copiar con nombre temporal al directorio contenedor y renombrar
  tmp_dest <- file.path(dir_dest, paste0(".pdu_tmp_", as.hexmode(as.integer(runif(1, 1e5, 1e7))), "_", basename(from)))
  if (isTRUE(file.copy(from, tmp_dest, overwrite = TRUE))) {
    if (file.rename(tmp_dest, to)) {
      return(TRUE)
    }
    unlink(tmp_dest, force = TRUE)
  }
  
  # Caso 4: En Windows, invocar cmd.exe /c copy directamente con Win32
  if (.Platform$OS.type == "windows") {
    from_win <- normalizePath(from, winslash = "\\", mustWork = FALSE)
    to_win <- normalizePath(to, winslash = "\\", mustWork = FALSE)
    res <- tryCatch(
      system2("cmd.exe", args = c("/c", "copy", "/Y", sprintf('"%s"', from_win), sprintf('"%s"', to_win)),
              stdout = FALSE, stderr = FALSE),
      error = function(e) 1L
    )
    if (identical(res, 0L) && file.exists(to)) {
      sz_from <- file.info(from)$size
      sz_to <- file.info(to)$size
      if (!is.na(sz_from) && !is.na(sz_to) && sz_from == sz_to) return(TRUE)
    }
  }
  
  # Caso 5: Streaming binario en bloques pequeños (64 KB) con readBin/writeBin
  # Evita solicitar un buffer contiguo de 1MB a malloc en un heap C fragmentado
  tryCatch({
    sz <- file.info(from)$size
    if (is.na(sz)) return(FALSE)
    if (sz == 0) return(file.create(to))
    
    con_in <- file(from, "rb")
    on.exit(close(con_in), add = TRUE)
    con_out <- file(to, "wb")
    on.exit(close(con_out), add = TRUE)
    
    while ((n <- length(buf <- readBin(con_in, "raw", n = 65536L))) > 0L) {
      writeBin(buf, con_out)
    }
    file.exists(to) && file.info(to)$size == sz
  }, error = function(e) FALSE)
}

