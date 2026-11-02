"# pdu_anta_2024_2034" 

## Seguridad y despliegue privado

Las capas territoriales y documentos normativos son privados. No publicar `data/`,
`data_pdu/`, `normativa/` ni `aprobacion/` en GitHub. GitHub Pages solo debe alojar
la máscara estática ubicada en `docs/`; esta no incluye datos ni inicia túneles.
El visor se ejecuta en un computador municipal dentro de la LAN mediante
`Rscript run_server.R`, enlazado a `127.0.0.1`. Para acceso desde otros equipos
de la red local, habilite una regla de firewall solo desde la subred autorizada;
no use túneles públicos. Nginx es una alternativa si se configura con TLS y una
subred autorizada explícita.

Las credenciales reales deben residir en un archivo de entorno fuera de Git,
con permisos restringidos. Genere contraseñas aleatorias, configure `PGSSLMODE`
como `require` para conexiones remotas (idealmente `verify-full` con CA confiable)
y mantenga PostgreSQL en loopback cuando esté en el mismo equipo. El DNI se usa
para limitar el uso diario; no autentica identidad. Las coordenadas y polígonos
se procesan en memoria y no se conservan en logs.

El visor actual usa capas Leaflet vectoriales para mostrar el mapa. El navegador
recibe las geometrías de las capas cargadas; ocultar botones no impide que se
inspeccionen desde las herramientas del navegador.

La sustitución del mapa por raster requiere un cambio separado y pruebas visuales
antes de afirmar que las geometrías ya no se transfieren al navegador.


## Optimizacion del visor

El mapa Leaflet se prepara una vez por proceso y usa Canvas. Sus capas son copias
de visualizacion simplificadas a 0,5 m en UTM 18S, con los atributos necesarios para
estilos, etiquetas y ventanas. No usar esas copias para mediciones: las consultas,
intersecciones y reportes siguen usando las geometrías originales. Las vias UTM y
el encuadre se calculan una sola vez y se comparten entre sesiones.

El backend privado usa `Rscript scripts/preparar_cache_pdu.R` para crear `data_pdu/pdu_preparado.rds` con las
geometrias originales, la normativa vinculada y firmas MD5. El cargador comprueba
las fuentes presentes y descarta una cache desactualizada. No se escribe cache al
iniciar la aplicacion. Los shapefiles se mantienen locales; el despliegue puede
usar la cache local. No genere ni publique manifiestos de backend desde este repositorio;
GitHub Pages solo publica `docs/index.html` y los recursos gráficos de la máscara.

Despues de cambiar fuentes o cargadores, ejecutar desde la raiz:

```r
source("scripts/preparar_cache_pdu.R")
testthat::test_file("tests/testthat/test-optimizacion.R")
source("scripts/generate_manifest.R")
```

La construccion compartida evita repetir procesamiento por visitante; cada visita
todavia recibe el mapa. La reduccion del widget no representa una medicion de
transferencia HTTP: comprobar esta ultima en el navegador y las metricas de Posit.
