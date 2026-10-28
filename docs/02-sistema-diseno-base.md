# BIBLIA DE SISTEMAS DE DISEÑO Y DIRECCIÓN DE ARTE

Cuando iniciemos un proyecto o pantalla, elige o combina uno de estos 3 arquetipos estéticos (o el que defina el usuario) y traduce sus valores a variables CSS en `globals.css` y `tailwind.config.ts`.

## ARQUETIPO A: "SWISS BRUTALISM & INDUSTRIAL TECH" (Ideal para SaaS, Dashboards, DevTools)
- **Filosofía:** Precisión técnica, cuadrícula visible (bordes de 1px que separan secciones de extremo a extremo), cero adornos innecesarios. Inspirado en Linear, Teenage Engineering y Vercel.
- **Paleta:**
  - Fondo Base: `#09090B` (Obsidiana) o `#F4F4F0` (Papel técnico claro).
  - Superficies: `#121215` (Oscuro) o `#FFFFFF` (Claro).
  - Bordes de cuadrícula: `rgba(255, 255, 255, 0.08)` en oscuro / `#E2E2DC` en claro.
  - Acento Único: Naranja industrial (`#FF4F00`), Verde Fósforo (`#00FF66`) o Blanco Puro de alto contraste.
- **Geometría:** `rounded-none` o `rounded-[2px]`. Prohibido pasar de `4px` de radio.
- **Tipografía:** Sans geométrica limpia (Geist / Inter Tight) + Monospace obligatoria (JetBrains Mono / Geist Mono) para números, fechas, badges, IDs y tablas (`tabular-nums`).

## ARQUETIPO B: "EDITORIAL LUXURY & ATELIER" (Ideal para E-commerce de alta gama, Joyería, Moda, Arquitectura)
- **Filosofía:** Lujo silencioso, espacio negativo masivo (aire), ritmo asimétrico tipo revista impresa, transiciones lentas y elegantes (`duration-500 ease-out`).
- **Paleta:**
  - Fondo Base: `#F8F6F2` (Alabastro/Hueso) o `#0D0C0B` (Carbón cálido).
  - Texto Principal: `#141413` (Tinta negra cálida).
  - Texto Secundario: `#6E6A63` (Piedra).
  - Acento: Bronce viejo (`#9A7B4F`), Champán sutil o contraste puro Blanco/Negro sin color adicional.
- **Geometría:** `rounded-none` absoluto en imágenes, botones y tarjetas. Bordes finos de `1px solid #E5E0D8`.
- **Tipografía:** Serif de alto contraste en titulares (Cormorant Garamond, Playfair Display o Instrument Serif) con `tracking-tight` + Sans minimalista en cuerpo con `tracking-wide` en botones en mayúsculas (`text-xs uppercase tracking-[0.2em]`).

## ARQUETIPO C: "NEO-BENTO & ORGANIC MODERN" (Ideal para Apps de Consumo, Fitness, Productividad)
- **Filosofía:** Dinámico, modular, contraste de bloques densos con tipografía expresiva grande.
- **Paleta:** Gris cálido profundo (`#161618`), tarjetas en `#1F1F22`, textos en `#F2F2EE`, acento vibrante ácido (`#D4FF00` o `#FF3366`).
- **Geometría:** Contraste intencional entre contenedores con radio preciso (`rounded-lg` / `8px`) y píldoras (`rounded-full` solo en tags o botones de acción rápida).

## REGLAS DE MICRO-INTERACCIÓN Y UI PARA TODOS LOS ARQUETIPOS
1. **Tablas y Datos:** Nunca uses tablas con franjas grises genéricas. Usa bordes inferiores ultrafinos (`border-b border-border/40`), alineación a la derecha para importes/métricas y fuente monoespaciada.
2. **Botones:** Prohibido el botón azul/morado redondo con sombra. Diseña botones con bordes nítidos, altura precisa (`h-9` o `h-10`), tipografía medida y estados `:hover` que inviertan el color o desplacen sutilmente un icono (`group-hover:translate-x-0.5 transition-transform`).