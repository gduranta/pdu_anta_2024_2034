# GeoVisor PDU Anta (2024 - 2034)
### Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR)

Plataforma oficial de difusión y consulta ciudadana del **Plan de Desarrollo Urbano de Anta (2024 - 2034)**, aprobado mediante Ordenanza Municipal N° 04-2025-A-MPA/C y actualizado mediante Ordenanza Municipal N° 008-2026-A-MPA-C.

---

## 🌐 Portal Oficial en GitHub Pages

El portal público de acceso para la ciudadanía se encuentra disponible en:
👉 **[https://gduranta.github.io/pdu_anta_2024_2034/](https://gduranta.github.io/pdu_anta_2024_2034/)**

---

## 🏛️ Arquitectura de Privacidad y Seguridad Territorial

Conforme a las políticas de seguridad institucional, soberanía de la información territorial y la Ley N° 29733 (Ley de Protección de Datos Personales del Perú):

1. **Cartografía y Código Fuente Desacoplados:**
   - La base de datos geoespacial (capas Shapefile, zonificación, vías, servidumbres) y el motor analítico R Shiny se ejecutan **exclusivamente en los servidores autorizados de la Municipalidad Provincial de Anta**.
   - No se almacenan capas territoriales nativas ni código del backend en este repositorio público.

2. **Conexión Segura vía Túnel Cifrado:**
   - Este repositorio aloja únicamente el portal estático seguro ([`docs/`](docs/)) servido por GitHub Pages.
   - La transmisión interactiva entre el portal web y el motor cartográfico municipal se realiza a través de un canal cifrado con TLS de extremo a extremo, verificando el origen institucional del enmarcado (*frame-ancestors*).

---

## 📞 Canales Institucionales de Atención

Para trámites formales, certificados de zonificación oficial o consultas técnicas:
- **Mesa de Partes Virtual:** [mesadepartesvirtual@munianta.gob.pe](mailto:mesadepartesvirtual@munianta.gob.pe)
- **Sede Institucional:** Casa de la Cultura: Av. los Andes S/N, Anta, Cusco.
- **Horario:** Lunes a Viernes de 8:00 a 17:00 horas.
