# Motor de Data Masking Personalizado para Oracle

Este repositorio contiene el código fuente y los scripts de despliegue del **Motor Nactivo de Enmascaramiento de Datos (Data Masking)** para bases de datos Oracle.

---

## 🎯 ¿Por qué existe este motor?

En cumplimiento con las normativas internacionales de protección de datos (como la **LOPD / RGPD**), las organizaciones tienen la obligación legal de proteger la Información de Identificación Personal (PII) de sus clientes y empleados. 

Cuando los datos de producción se copian a entornos no productivos (Desarrollo, QA, Staging o Pruebas), existe un riesgo crítico de fuga de información si esta no es anonimizada.

### Desafío y Solución
Las herramientas tradicionales del mercado (como *Oracle Enterprise Manager Data Masking Pack*) requieren licenciamiento de coste elevado y arquitecturas complejas de configurar. 

Este motor fue diseñado como una **alternativa de alto rendimiento, nativa (PL/SQL) y de coste cero**, que se ejecuta directamente dentro del motor de base de datos Oracle, optimizando los tiempos de procesamiento y garantizando el cumplimiento normativo.

---

## 🚀 Características Principales

El motor está estructurado en tres fases operativas completamente automatizadas:

### 1. Descubrimiento Automático (`dm_descubre`)
* Escanea el diccionario de datos de la base de datos objetivo.
* Identifica de manera inteligente columnas candidatas a contener PII (DNI, NIE, CIF, Teléfonos, IBAN, Nombres, Direcciones) analizando los nombres de columnas, tipos de datos y comentarios.
* Genera un catálogo unificado de reglas propuesto para revisión del DBA.

### 2. Propagación Referencial y Enmascaramiento (`dm_enmascara`)
* **Propagación en Cascada (Union-Find):** Identifica relaciones jerárquicas (Claves Primarias, Únicas y Foráneas) y propaga de manera determinista las reglas de enmascaramiento de los padres a las tablas hijas para **mantener la integridad referencial** sin romper la base de datos.
* **Preservación de Estructura:** Genera valores ficticios pero matemáticamente válidos (letras de control de DNI/NIE/CIF correctas y checksum de IBAN módulo 97 válidos) para que las aplicaciones cliente sigan funcionando sin errores de formato.
* **Control de Dependencias:** Deshabilita automáticamente índices, disparadores y restricciones durante la carga masiva y los rehabilita al finalizar para optimizar la velocidad.

### 3. Puerta de Calidad / Quality Gate (`dm_validar_flujo`)
Valida automáticamente la ejecución del enmascaramiento ejecutando 8 controles clave (KPIs):
* **KPI-01 (Objetos Válidos):** Verifica la ausencia de objetos inválidos en el esquema (con lógica de autocuración y recompilación iterativa).
* **KPI-02 (Dependencias):** Comprueba que todas las restricciones y triggers hayan sido reactivados.
* **KPI-03 (Logs):** Audita las tablas de fallas del proceso para verificar que no hubo errores.
* **KPI-04 (Algoritmo DNI/NIE/CIF):** Comprobación matemática del dígito de control de los documentos generados.
* **KPI-05 (Algoritmo IBAN):** Comprobación matemática del checksum módulo 97.
* **KPI-06 (Unicidad):** Verifica que no existan colisiones de datos en columnas con restricciones de clave única (`UNIQUE`).
* **KPI-07 (Concurrencia):** Protege contra ejecuciones paralelas accidentales en el mismo esquema.
* **KPI-08 (Integridad Referencial):** Valida la ausencia de registros huérfanos entre tablas padre-hija.

---

## 📂 Estructura del Repositorio

El repositorio se divide en dos versiones de la arquitectura:

* **`version_sin_biyeccion/`**
  * La implementación original del motor. Utiliza algoritmos estándar de hash y Pepper para la alteración de datos sensibles. 
  * *Nota:* En esta versión existía la probabilidad de colisiones de datos en columnas con restricciones de valores únicos (`UNIQUE`), lo que requería exclusiones manuales.
  
* **`version_biyeccion/`**
  * **La versión optimizada y recomendada.** Introduce mapeos matemáticos biyectivos basados en aritmética modular (inverso multiplicativo modular).
  * Garantiza la unicidad estricta (no colisiones) manteniendo el determinismo relacional.
  * Integra lógica autocurativa de compilación iterativa de esquemas y filtro inteligente de errores ambientales (omisión de errores `ORA-00942` por esquemas ausentes en ambientes de prueba).

---

## 🛠️ Modo de Uso Rápido

Para utilizar el motor en el servidor Oracle a través de SQL*Plus:

1. **Instalar el motor en el esquema de administración (`ASTSYSADMIN`):**
   ```sql
   @99_install_datamasking.sql
   ```
2. **Ejecutar el descubrimiento de un esquema:**
   ```sql
   @dm_descubre MI_ESQUEMA_APP
   ```
3. **Ejecutar el enmascaramiento (ejemplo con ID de ejecución 3):**
   ```sql
   @dm_enmascara 3 Y
   ```
4. **Validar la calidad del proceso:**
   ```sql
   @dm_validar_flujo MI_ESQUEMA_APP 3
   ```
5. **Recompilar dependencias del esquema en cualquier momento:**
   ```sql
   @dm_recompilar MI_ESQUEMA_APP
   ```
