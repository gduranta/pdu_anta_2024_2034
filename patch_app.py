# -*- coding: utf-8 -*-
import sys

def patch_app_r():
    with open('app.R', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update header subtitle and badge-aprobado in app.R
    old_header = '''      # Fila 1: Marca institucional + Vigencia normativa + Fecha oficial
      div(
        class = "d-flex align-items-center gap-2",
        span(class = "header-brand-title", "GEOVISOR PDU ANTA"),
        span(class = "pdu-badge-title", "2024 - 2034"),
        span(
          class = "header-badge-aprobado d-none d-sm-inline-flex",
          icon("calendar-check"), " Aprobado: 11 de abril del 2025 (Act. 04/09/2026)"
        )
      ),
      # Fila 2: Subtítulo territorial institucional
      tags$small(
        class = "header-subtitle d-none d-md-inline-block",
        "Municipalidad Provincial de Anta • Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial"
      )'''

    new_header = '''      # Fila 1: Marca institucional + Vigencia normativa + Fecha oficial
      div(
        class = "d-flex align-items-center gap-2 flex-wrap",
        span(class = "header-brand-title", "GEOVISOR PDU ANTA"),
        span(class = "pdu-badge-title", "2024 - 2034"),
        span(
          class = "header-badge-aprobado d-none d-xl-inline-flex",
          icon("calendar-check"), " Aprobado: 11 de abril del 2025 (Act. 04/09/2026)"
        )
      ),
      # Fila 2: Subtítulo territorial institucional (con truncado inteligente en pantallas estándar)
      tags$small(
        class = "header-subtitle d-none d-lg-inline-block text-truncate",
        style = "max-width: 480px;",
        title = "Municipalidad Provincial de Anta • Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial",
        "Municipalidad Provincial de Anta • Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial"
      )'''

    if old_header in content:
        content = content.replace(old_header, new_header)
        print("Header in app.R updated successfully.")
    else:
        print("Header in app.R not matched directly, checking normalized...")
        old_norm = old_header.replace('\r\n', '\n')
        content_norm = content.replace('\r\n', '\n')
        if old_norm in content_norm:
            content_norm = content_norm.replace(old_norm, new_header.replace('\r\n', '\n'))
            content = content_norm
            print("Header in app.R updated via normalization.")
        else:
            print("ERROR: Header pattern not found in app.R")
            sys.exit(1)

    # 2. Update tags$style block in app.R
    old_style = '''    tags$style(HTML("
      .leaflet-container { height: calc(100vh - 78px) !important; width: 100% !important; }
      @media (max-width: 767.98px) {
        .leaflet-container {
          height: calc(100dvh - 66px) !important;
          height: calc(100vh - 66px) !important;
          width: 100% !important;
        }
      }
      .nav-link { font-weight: 600; }
      
      /* Habilitar scroll vertical en el contenedor de pestañas y páginas de contenido */
      .tab-content {
        flex: 1 1 auto !important;
        overflow-y: auto !important;
        -webkit-overflow-scrolling: touch;
      }
      .tab-pane {
        height: auto !important;
        min-height: 100% !important;
        overflow-y: auto !important;
        -webkit-overflow-scrolling: touch;
      }
      /* El visor del mapa ocupa la pantalla y gestiona su propio canvas */
      .tab-pane#tab_visor,
      .tab-pane[data-value='tab_visor'] {
        height: 100% !important;
        overflow: hidden !important;
      }
      /* El sidebar de consultas debe poder hacer scroll si los controles superan la altura de pantalla */
      .bslib-sidebar-layout > .sidebar,
      .bslib-sidebar-layout .sidebar-content {
        overflow-y: auto !important;
        max-height: 100% !important;
        -webkit-overflow-scrolling: touch;
      }
    "))'''

    new_style = '''    tags$style(HTML("
      /* Navbar institucional no deformable */
      .navbar {
        flex-shrink: 0 !important;
        min-height: 56px !important;
      }
      .nav-link { font-weight: 600; white-space: nowrap !important; }
      
      /* Contenedor principal de pestañas: ajusta al 100% del espacio restante sin desbordar el viewport */
      .tab-content {
        flex: 1 1 0% !important;
        height: 0 !important;
        min-height: 0 !important;
        max-height: 100% !important;
        overflow: hidden !important;
        position: relative !important;
      }
      
      /* Páginas de contenido secundarias (Ficha Informativa, Catálogo, Información, Privacidad):
         Actúan como el ÚNICO contenedor de scroll vertical para evitar bloqueos táctiles en móviles */
      .tab-pane:not(#tab_visor):not([data-value='tab_visor']) {
        height: 100% !important;
        max-height: 100% !important;
        min-height: 100% !important;
        overflow-y: auto !important;
        overflow-x: hidden !important;
        -webkit-overflow-scrolling: touch !important;
        touch-action: pan-y !important;
        overscroll-behavior-y: contain !important;
        box-sizing: border-box !important;
        padding-bottom: 3.5rem !important;
      }
      
      /* Visor Territorial en escritorio: ocupa el 100% sin scroll global y gestiona mapa + sidebar */
      @media (min-width: 768px) {
        .tab-pane#tab_visor,
        .tab-pane[data-value='tab_visor'] {
          height: 100% !important;
          max-height: 100% !important;
          overflow: hidden !important;
          display: flex !important;
          flex-direction: column !important;
          min-height: 0 !important;
        }
        .tab-pane#tab_visor .bslib-sidebar-layout {
          height: 100% !important;
          max-height: 100% !important;
          flex: 1 1 0% !important;
          min-height: 0 !important;
        }
        .tab-pane#tab_visor .bslib-sidebar-layout > .main {
          height: 100% !important;
          min-height: 0 !important;
          overflow: hidden !important;
        }
        .tab-pane#tab_visor .bslib-sidebar-layout > .sidebar,
        .tab-pane#tab_visor .bslib-sidebar-layout .sidebar-content {
          height: 100% !important;
          max-height: 100% !important;
          overflow-y: auto !important;
          overflow-x: hidden !important;
          -webkit-overflow-scrolling: touch !important;
        }
        .leaflet-container,
        #mapa_pdu {
          height: 100% !important;
          width: 100% !important;
          min-height: 0 !important;
          max-height: 100% !important;
        }
      }
      
      /* Visor Territorial en móviles (<768px): permite scroll fluido entre panel y mapa */
      @media (max-width: 767.98px) {
        .tab-pane#tab_visor,
        .tab-pane[data-value='tab_visor'] {
          height: 100% !important;
          max-height: 100% !important;
          overflow-y: auto !important;
          overflow-x: hidden !important;
          -webkit-overflow-scrolling: touch !important;
          touch-action: pan-y !important;
          padding-bottom: 2rem !important;
        }
        .leaflet-container,
        #mapa_pdu {
          height: 520px !important;
          min-height: 480px !important;
          width: 100% !important;
        }
      }
    "))'''

    content_norm = content.replace('\r\n', '\n')
    old_style_norm = old_style.replace('\r\n', '\n')
    new_style_norm = new_style.replace('\r\n', '\n')

    if old_style_norm in content_norm:
        content_norm = content_norm.replace(old_style_norm, new_style_norm)
        print("tags$style in app.R updated successfully.")
    else:
        print("ERROR: tags$style block not found in app.R")
        sys.exit(1)

    with open('app.R', 'w', encoding='utf-8', newline='\n') as f:
        f.write(content_norm)
    print("app.R written successfully.")

patch_app_r()

