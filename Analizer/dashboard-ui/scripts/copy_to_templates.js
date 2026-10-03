// copy_to_templates.js -- copia el bundle ya compilado a templates/static/,
// donde Python lo lee e inlinea en el HTML final (ver core/html_builder.py).
// Se corre como parte de `npm run build`, nunca en produccion.
const fs = require("fs");
const path = require("path");

const src = path.join(__dirname, "..", "dist", "dashboard.bundle.js");
const dest = path.join(__dirname, "..", "..", "templates", "static", "dashboard.bundle.js");
fs.copyFileSync(src, dest);
console.log(`Copiado ${src} -> ${dest}`);
