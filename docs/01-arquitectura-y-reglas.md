# ESTÁNDAR DE ARQUITECTURA Y CONVENCIONES DE CÓDIGO

## 1. Estructura de Directorios (Next.js App Router)
Todo proyecto debe respetar estrictamente esta jerarquía:
- `/src/app`: Rutas, `layout.tsx`, `page.tsx`, `loading.tsx`, `error.tsx` y `api/` (Route Handlers).
- `/src/components/ui`: Primitivas atómicas de interfaz (Botones, Inputs, Modales, Tablas) sin lógica de negocio.
- `/src/components/features`: Componentes complejos ligados a un dominio del proyecto.
- `/src/components/layout`: Header, Sidebar, Footer, contenedores de cuadrícula (Swiss Grids).
- `/src/lib`: Instancias singleton (`prisma.ts`), utilidades (`cn.ts`), clientes externos y helpers puros.
- `/src/store`: Stores globales de Zustand divididos por dominio (ej. `useUIStore.ts`, `useCartStore.ts`).
- `/src/actions`: Server Actions de Next.js con validación Zod de entrada y retorno tipado `{ success: boolean, data?: T, error?: string }`.
- `/src/types`: Interfaces y tipos globales de TypeScript.

## 2. Reglas de Componentes y Estado
- **Server First:** Todo componente es Server Component por defecto. Solo se añade `'use client'` en el nodo más bajo posible que requiera hooks (`useState`, `useEffect`, Zustand) o eventos del navegador.
- **Zustand:** Prohibido meter datos del servidor que puedan pasarse por props directas o gestionarse por URL searchParams en Zustand. Zustand se reserva para estado de UI complejo o estado cliente transversal.
- **Tipado Estricto:** Prohibido usar `any` o `@ts-ignore`. Las props de cada componente se definen con `interface NombreProps`.

## 3. Reglas de Base de Datos (Prisma + PostgreSQL)
- Usar siempre `camelCase` para campos en Prisma y `@map("snake_case")` / `@@map("plural_snake_case")` si se requiere compatibilidad SQL limpia.
- Incluir siempre `createdAt DateTime @default(now())` y `updatedAt DateTime @updatedAt` en los modelos principales.