"# pdu_anta_2024_2034" 

## Seguridad y despliegue privado

No publicar `data/`, `data_pdu/`, `normativa/` ni `aprobacion/` en GitHub. GitHub
Pages aloja la máscara estática ubicada en `docs/`; el visor Shiny se ejecuta en
el computador servidor y la máscara se conecta mediante un túnel HTTPS de
Cloudflare. El endpoint público temporal se escribe en `docs/server_endpoint.json`
y debe publicarse en la rama de Pages para que la máscara encuentre el servidor.
Ejecute `iniciar_servidor_github_pages.bat` en el computador anfitrión. Para usar
un hostname estable en producción, configure un túnel Cloudflare administrado y
reemplace el flujo temporal `trycloudflare.com`.

El túnel protege el transporte y evita abrir directamente el puerto Shiny a
Internet. No vuelve secretas las capas que el navegador necesita dibujar: las
geometrías vectoriales visibles pueden recuperarse mediante herramientas del
navegador. No se debe presentar este diseño como protección contra descarga de
cartografía; para reducir la exposición hay que servir mapas rasterizados o tiles
y definir el nivel de detalle permitido, entendiendo que las imágenes visibles
también pueden capturarse.

Las credenciales reales deben residir en un archivo de entorno fuera de Git,
con permisos restringidos. Genere contraseñas aleatorias, configure `PGSSLMODE`
como `require` para conexiones remotas (idealmente `verify-full` con CA confiable)
y mantenga PostgreSQL en loopback cuando esté en el mismo equipo. El DNI se usa
para limitar el uso diario; no autentica identidad. Las coordenadas y polígonos
se procesan en memoria y no se conservan en logs.

El visor actual usa capas Leaflet vectoriales para mostrar el mapa. El navegador
recibe las geometrías de las capas cargadas; ocultar botones no impide que se
inspeccionen desde las herramientas del navegador.


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
