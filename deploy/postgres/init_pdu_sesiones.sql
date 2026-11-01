-- ==============================================================================
-- GEOVISOR DEL PLAN DE DESARROLLO URBANO (PDU) DE ANTA (2024 - 2034)
-- MUNICIPALIDAD PROVINCIAL DE ANTA - GERENCIA DE DESARROLLO URBANO Y RURAL
--
-- Script Oficial de Despliegue de Base de Datos PostgreSQL / PostGIS
-- Módulo Corporativo de Control de Acceso y Gestión de Cuotas (CWE-362)
-- Ubicación: deploy/postgres/init_pdu_sesiones.sql
-- Ejecución: psql -U postgres -d geovisor_anta_pdu -f init_pdu_sesiones.sql
-- ==============================================================================

-- 1. Crear Base de Datos Institucional (opcional si ya existe)
-- CREATE DATABASE geovisor_anta_pdu WITH ENCODING 'UTF8';
-- \c geovisor_anta_pdu;

-- 2. Habilitar extensión espacial PostGIS (requerida por el PDU)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 3. Crear Usuario Institucional con Principio de Menor Privilegio
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pdu_app_user') THEN
    CREATE ROLE pdu_app_user WITH LOGIN PASSWORD 'CambiarClaveSegura2026!';
  END IF;
END
$$;

-- 4. Tabla Transaccional de Sesiones de Acceso Ciudadano
-- Cumplimiento: Ley N° 29733 (Sin almacenamiento de DNI en texto claro)
CREATE TABLE IF NOT EXISTS control_acceso_sesiones (
    id VARCHAR(64) PRIMARY KEY,
    id_dni_hash VARCHAR(64) NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIMESTAMP NOT NULL,
    duracion_min INTEGER NOT NULL DEFAULT 10,
    ip_origen VARCHAR(45) DEFAULT 'local',
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Índices de Alto Rendimiento para Búsquedas en Microsegundos
CREATE INDEX IF NOT EXISTS idx_pdu_sesiones_hash_fecha 
    ON control_acceso_sesiones (id_dni_hash, fecha);

CREATE INDEX IF NOT EXISTS idx_pdu_sesiones_fecha 
    ON control_acceso_sesiones (fecha);

-- 6. Asignar Permisos Restringidos a la Aplicación Shiny
GRANT CONNECT ON DATABASE geovisor_anta_pdu TO pdu_app_user;
GRANT USAGE ON SCHEMA public TO pdu_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE control_acceso_sesiones TO pdu_app_user;

-- 7. Vista Institucional para Auditoría Anónima de la GDUR
CREATE OR REPLACE VIEW vista_estadisticas_acceso_pdu AS
SELECT 
    fecha,
    COUNT(DISTINCT id_dni_hash) AS ciudadanos_unicos_atendidos,
    COUNT(*) AS total_sesiones_generadas,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT id_dni_hash), 0), 2) AS promedio_sesiones_por_ciudadano
FROM control_acceso_sesiones
GROUP BY fecha
ORDER BY fecha DESC;

GRANT SELECT ON vista_estadisticas_acceso_pdu TO pdu_app_user;

-- 8. Función para Purga Automática de Registros Mayores a 7 Días (Principio de Limitación de Plazo - Ley 29733)
CREATE OR REPLACE FUNCTION purgar_sesiones_antiguas_pdu(dias_retencion INTEGER DEFAULT 7)
RETURNS INTEGER AS $$
DECLARE
    filas_eliminadas INTEGER;
BEGIN
    DELETE FROM control_acceso_sesiones 
    WHERE fecha < (CURRENT_DATE - dias_retencion * INTERVAL '1 day');
    
    GET DIAGNOSTICS filas_eliminadas = ROW_COUNT;
    RETURN filas_eliminadas;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE control_acceso_sesiones IS 'Registro transaccional ACID de cuotas ciudadanas de consulta territorial PDU Anta.';
COMMENT ON COLUMN control_acceso_sesiones.id_dni_hash IS 'Identificador criptografico seudonimizado (SHA-256 + Salt secreta de 256 bits).';
