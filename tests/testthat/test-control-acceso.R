source(testthat::test_path("..", "..", "R", "mod_acceso_dni.R"), local = TRUE)

test_that("control de acceso DNI funciona correctamente", {
  # Archivo temporal de prueba para no alterar outputs de producción
  tf <- tempfile(fileext = ".rds")
  on.exit(unlink(tf), add = TRUE)
  
  dni_test <- "12345678"
  
  # 1. Consulta inicial: debe tener 2 sesiones restantes
  cuota1 <- pdu_acceso_consultar_cuota(dni_test, ruta_db = tf)
  expect_true(cuota1$permitido)
  expect_equal(cuota1$restantes, 2L)
  expect_equal(cuota1$total_hoy, 0L)
  
  # 2. Registrar sesión 1
  id1 <- pdu_acceso_registrar_sesion(dni_test, duracion_min = 10L, ruta_db = tf)
  expect_true(is.character(id1))
  expect_true(grepl("^SES-", id1))
  
  # 3. Consulta intermedia: debe tener 1 sesión restante
  cuota2 <- pdu_acceso_consultar_cuota(dni_test, ruta_db = tf)
  expect_true(cuota2$permitido)
  expect_equal(cuota2$restantes, 1L)
  expect_equal(cuota2$total_hoy, 1L)
  
  # 4. Registrar sesión 2
  id2 <- pdu_acceso_registrar_sesion(dni_test, duracion_min = 10L, ruta_db = tf)
  expect_true(is.character(id2))
  
  # 5. Consulta final: cuota agotada (0 restantes)
  cuota3 <- pdu_acceso_consultar_cuota(dni_test, ruta_db = tf)
  expect_false(cuota3$permitido)
  expect_equal(cuota3$restantes, 0L)
  expect_equal(cuota3$total_hoy, 2L)
  expect_true(grepl("ha alcanzado el límite diario", cuota3$mensaje))
})

