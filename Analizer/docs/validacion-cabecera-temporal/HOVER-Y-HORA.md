# Corrección del hover y hora de captura

El tooltip aparece únicamente en el gráfico bajo el puntero. Los demás gráficos visibles reciben una línea temporal, sin tooltips replicados ni recalcular las series. El tooltip presenta valores con hasta tres decimales, conserva el entero de los extremos y omite rutas completas. Los datos originales permanecen intactos.

Se retiraron los paneles generales de resumen A/B y calidad. Se mantienen el detalle por recurso, las evidencias y los máximos de procesos.

Con una única zona documentada y sin fuentes auxiliares de zona desconocida, toda la presentación usa el offset de captura. El caso CSV muestra 05/10/2026 10:30–11:30 UTC+02:00; el filtro convierte sus entradas a los instantes internos originales. Legacy conserva su hora sin atribuirle una zona. Fuentes con offsets distintos usan una referencia común UTC.

Validación: pruebas temporales y estadísticas de JavaScript, compilación TypeScript y bundle, smoke Python, compileall y diff --check. Chromium comprueba CSV y legacy en Madrid, Los Ángeles y Tokio: tooltip único, dimensiones estables, scroll libre, filtros, carga diferida y ausencia de desbordamiento en móvil.
