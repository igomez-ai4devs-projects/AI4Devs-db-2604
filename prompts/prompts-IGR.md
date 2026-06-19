# Prompts

## Prompt 1:

Agent: Claude Code - Sonnet 4.6

### Request:

Actúa como ingeniero de software senior experto en bases de datos PostgreSQL y en Prisma. Vamos a trabajar sobre un proyecto real (sistema ATS de selección de personal "LTI").

Contexto del proyecto:

- Backend en TypeScript con Prisma ORM 5.13 y PostgreSQL corriendo en Docker (docker-compose.yml).
- El schema está en backend/prisma/schema.prisma.
- Conexión (de .env): postgresql://LTIdbUser:\*\*\*\*@localhost:5432/LTIdb
- El schema ACTUAL ya contiene estos modelos: Candidate, Education, WorkExperience, Resume.

Objetivo global: ampliar la base de datos con nuevas entidades para operar el flujo completo de aplicación a posiciones, partiendo de un ERD en Mermaid que te pasaré. Reglas de trabajo:

1. NO dupliques entidades existentes (Candidate ya existe: hay que fusionarlo, no recrearlo).
2. Aplica buenas prácticas: normalización hasta 3FN, índices, claves foráneas, constraints (UNIQUE, NOT NULL, CHECK), tipos adecuados y enums donde proceda.
3. Mantén la coherencia de estilo con el schema actual (nombres de modelos en PascalCase, campos en camelCase, @db.VarChar con longitudes explícitas).
4. Iremos por pasos; no generes nada hasta que te lo pida explícitamente en cada paso.

Confírmame que entiendes el contexto y espera a que te pase el schema actual y el ERD.

### Response:

Entendido. Asumo el rol de ingeniero senior de bases de datos PostgreSQL + Prisma para el proyecto ATS "LTI".

He registrado el contexto y las reglas:

Contexto

Backend TypeScript, Prisma 5.13, PostgreSQL en Docker (docker-compose.yml). Schema en backend/prisma/schema.prisma. Conexión: postgresql://LTIdbUser:\*\*\*\*@localhost:5432/LTIdb. Modelos existentes: Candidate, Education, WorkExperience, Resume. Reglas que seguiré

No duplicar entidades existentes — Candidate se fusiona, no se recrea (conservando educations, workExperiences, resumes). Buenas prácticas: normalización hasta 3FN, índices, FKs, constraints (UNIQUE, NOT NULL, CHECK), tipos adecuados y enums donde aporten. Coherencia de estilo: modelos en PascalCase, campos en camelCase, @db.VarChar(n) con longitudes explícitas. Trabajo por pasos: no genero nada (ni schema, ni migración, ni SQL) hasta que me lo pidas explícitamente en cada paso. Quedo a la espera de que me pases:

El schema.prisma actual completo. El ERD en Mermaid objetivo. En cuanto los reciba, mi primera entrega será únicamente el informe de análisis (sin código): entidades existentes vs. nuevas, conflictos de fusión de Candidate, problemas de normalización del ERD, e índices/constraints faltantes.

</br>

## Prompt 2:

Agent: Claude Code - Sonnet 4.6

### Request:

Este es el schema.prisma ACTUAL del proyecto: backend/prisma/schema.prisma

Y este es el ERD objetivo en formato Mermaid que debemos incorporar:

![alt text](image.png)

Analiza ambos y entrégame un INFORME (todavía sin escribir código):

1. Qué entidades del ERD ya existen, cuáles son nuevas y dónde hay conflicto/solape (especialmente Candidate, que aparece en ambos con campos distintos).
2. Cómo propones fusionar Candidate sin perder los campos/relaciones actuales (educations, workExperiences, resumes).
3. Problemas de diseño o normalización del ERD (campos que deberían ser enums, tipos genéricos como "string"/"text" mal tipados, relaciones 1:1 vs 1:N mal expresadas, posibles dependencias transitivas que violen la 3FN).
4. Lista de índices y constraints que faltan en el ERD y deberíamos añadir. Devuélvelo como tabla/resumen. No generes Prisma todavía.

### Response:

# Informe de análisis del ERD vs. schema actual

> Proyecto: Sistema ATS "LTI" — PostgreSQL + Prisma 5.13 Estado: análisis previo (sin código)

## 1. Entidades: existentes, nuevas y conflictos

| Entidad (ERD) | Estado | Observación |
| --- | --- | --- |
| `CANDIDATE` | ⚠️ Conflicto / solape | Ya existe en Prisma con más campos y 3 relaciones. El ERD la define empobrecida. |
| `COMPANY` | 🆕 Nueva | — |
| `EMPLOYEE` | 🆕 Nueva | FK a Company. |
| `POSITION` | 🆕 Nueva | FK a Company y a InterviewFlow. La PK aparece como `id2` (error de diagrama → debe ser `id`). |
| `INTERVIEW_FLOW` | 🆕 Nueva | — |
| `INTERVIEW_STEP` | 🆕 Nueva | FK a InterviewFlow e InterviewType. |
| `INTERVIEW_TYPE` | 🆕 Nueva | — |
| `APPLICATION` | 🆕 Nueva | FK a Position y Candidate. |
| `INTERVIEW` | 🆕 Nueva | FK a Application, InterviewStep, Employee. |
| `Education` / `WorkExperience` / `Resume` | ✅ Solo Prisma | No están en el ERD; se conservan tal cual colgando de Candidate. |

### Detalle del conflicto en `Candidate`

| Campo | Prisma actual | ERD | Resolución |
| --- | --- | --- | --- |
| `firstName` | `VarChar(100)` NOT NULL | `string` | Mantener Prisma |
| `lastName` | `VarChar(100)` NOT NULL | `string` | Mantener Prisma |
| `email` | `VarChar(255)` UNIQUE | `string` | Mantener Prisma (el ERD pierde el UNIQUE) |
| `phone` | `VarChar(15)` opcional | `string` | Mantener Prisma |
| `address` | `VarChar(100)` opcional | `string` | Mantener Prisma |
| `educations`, `workExperiences`, `resumes` | relaciones 1:N | — | Conservar |
| `applications` | — | (vía `submits`) | Añadir relación inversa 1:N |

## 2. Fusión de `Candidate` sin pérdida

- **No se recrea** el modelo. Se mantiene íntegro el `Candidate` actual (campos, tipos, `@unique` en email y las relaciones `educations` / `workExperiences` / `resumes`).
- **Única adición:** la relación inversa `applications Application[]` para materializar `CANDIDATE ||--o{ APPLICATION : submits`.
- A nivel de migración es **aditivo y no destructivo**: no hay `DROP`, no se tocan columnas existentes. El ERD se trata como subconjunto del modelo real.

## 3. Problemas de diseño / normalización del ERD

| Problema | Dónde | Propuesta |
| --- | --- | --- | --- | --- | --- | --- |
| PK mal nombrada | `Position.id2` | Renombrar a `id`. |
| Campos `string` que deben ser ENUM | `Position.status`, `Position.employmentType`, `Application.status`, `Interview.result`, `Employee.role` | Convertir a `enum`. |
| Tipos genéricos mal tipados | `salary_min/max` (`numeric` → `Decimal(10,2)`), fechas `date` (`DateTime`), `score` (`Int`), `is_visible`/`is_active` (`Boolean`) | Tipado explícito. |
| Longitudes sin definir | Todos los `string` del ERD | Asignar `@db.VarChar(n)` coherente con el estilo actual. |
| Relación 1:1 dudosa | `POSITION |  | -- |  | INTERVIEW_FLOW` | Un flujo se reutiliza en varias posiciones → debería ser InterviewFlow 1:N Position. |
| Relación 1:1 dudosa | `INTERVIEW |  | -- |  | INTERVIEW_STEP` | Un paso se ejecuta en muchas entrevistas → InterviewStep 1:N Interview. |
| Posible violación 3FN | `Position.company_description` / `Position.contact_info` | Dependen de la Company, no de la Position (dependencia transitiva). Normalizar a Company o documentar como snapshot intencional. |
| `benefits` como `text` plano | `Position` | Aceptable para MVP; normalizar solo si se quiere consultar por beneficio. |
| Sin timestamps | Todas | Añadir `createdAt` / `updatedAt`. |

## 4. Índices y constraints faltantes en el ERD

| Tabla | Índices (FK / filtros) | Constraints |
| --- | --- | --- |
| `Employee` | `@@index([companyId])` | `email` UNIQUE; `isActive` default `true` |
| `Position` | `@@index([companyId])`, `@@index([interviewFlowId])`, `@@index([status])`, `@@index([isVisible])`, `@@index([applicationDeadline])` | `CHECK (salaryMin <= salaryMax)`; `isVisible` default `false` |
| `InterviewStep` | `@@index([interviewFlowId])`, `@@index([interviewTypeId])` | `@@unique([interviewFlowId, orderIndex])` |
| `Application` | `@@index([positionId])`, `@@index([candidateId])`, `@@index([status])`, `@@index([applicationDate])` | `@@unique([positionId, candidateId])`; `applicationDate` default `now()` |
| `Interview` | `@@index([applicationId])`, `@@index([interviewStepId])`, `@@index([employeeId])`, `@@index([interviewDate])` | `CHECK (score BETWEEN 0 AND 100)` (rango a confirmar) |
| `Candidate` | (ya tiene unique en email) | — |
| Todas las FK | — | Definir `onDelete` / `onUpdate` explícito |

## Conclusión

El ERD es un buen punto de partida pero llega "plano": sin enums, sin índices, sin constraints, con dos relaciones 1:1 que conviene revisar y una posible violación de 3FN en `Position`. La fusión de `Candidate` es segura y puramente aditiva.

**Puntos a confirmar antes de generar código:**

1. `InterviewFlow` → `Position` como relación **1:N**.
2. Rango real válido para `Interview.score`.
3. Si `company_description` / `contact_info` se **normalizan a `Company`** o se dejan como **snapshot** en `Position`.

</br>

## Prompt 3:

Agent: Claude Code - Sonnet 4.6

### Request:

De tu informe, quiero cerrar decisiones antes de generar código. Propón y justifica:

1. Qué campos convertir a enum de Prisma (p. ej. Position.status, Position.employmentType, Application.status, Interview.result, Employee.role) y qué valores tendría cada enum.
2. Tipos finales: usa Decimal con @db.Decimal(10,2) para salary_min/salary_max, DateTime para fechas, longitudes VarChar razonables para strings, Text para campos largos.
3. Reglas de integridad:
   - relaciones 1:1 (Position–InterviewFlow) vs 1:N correctamente modeladas,
   - onDelete/onUpdate adecuados en cada FK,
   - constraints UNIQUE (p. ej. (interviewFlowId, orderIndex) en InterviewStep; email único en Employee).
4. CHECK constraints útiles (p. ej. score entre 0 y N, salary_min <= salary_max). Dame la propuesta cerrada en forma de lista por entidad. Sin código aún.

### Response:

# Decisiones de diseño cerradas

> Proyecto: Sistema ATS "LTI" — PostgreSQL + Prisma 5.13 Estado: decisiones previas a la generación del schema (sin código)

## 1. Enums

| Enum | Valores | Justificación |
| --- | --- | --- |
| `PositionStatus` | `DRAFT`, `OPEN`, `CLOSED`, `ARCHIVED` | Ciclo de vida de una oferta. Evita strings libres ("abierta"/"Open"/"opened"). |
| `EmploymentType` | `FULL_TIME`, `PART_TIME`, `CONTRACT`, `INTERNSHIP`, `TEMPORARY` | Conjunto cerrado y estándar de tipos de contrato. |
| `ApplicationStatus` | `RECEIVED`, `UNDER_REVIEW`, `INTERVIEWING`, `OFFERED`, `HIRED`, `REJECTED`, `WITHDRAWN` | Estados del pipeline de una candidatura; permite filtrar el funnel. |
| `InterviewResult` | `PENDING`, `PASSED`, `FAILED`, `ON_HOLD` | Resultado de una entrevista; `PENDING` cubre la entrevista aún no evaluada. |
| `EmployeeRole` | `RECRUITER`, `HIRING_MANAGER`, `INTERVIEWER`, `ADMIN` | Roles internos que participan en el proceso. |

> `Interview.result` arranca en `PENDING` (default), no nullable.

## 2. Tipos finales por entidad

### Company

- `id` Int PK autoincrement
- `name` `VarChar(255)` NOT NULL
- `createdAt` DateTime default now(), `updatedAt` DateTime @updatedAt

### Employee

- `id` Int PK
- `companyId` Int FK NOT NULL
- `name` `VarChar(255)` NOT NULL
- `email` `VarChar(255)` NOT NULL UNIQUE
- `role` `EmployeeRole` NOT NULL
- `isActive` Boolean default `true`
- timestamps

### Position

- `id` Int PK (corrige `id2`)
- `companyId` Int FK NOT NULL
- `interviewFlowId` Int FK NOT NULL
- `title` `VarChar(255)` NOT NULL
- `description` `Text`
- `status` `PositionStatus` default `DRAFT`
- `isVisible` Boolean default `false`
- `location` `VarChar(255)`
- `jobDescription` `Text`
- `requirements` `Text`
- `responsibilities` `Text`
- `salaryMin` `Decimal(10,2)`
- `salaryMax` `Decimal(10,2)`
- `employmentType` `EmploymentType`
- `benefits` `Text`
- `companyDescription` `Text` (snapshot intencional — ver punto 3)
- `applicationDeadline` DateTime (`@db.Date`)
- `contactInfo` `VarChar(255)`
- timestamps

### InterviewFlow

- `id` Int PK
- `description` `VarChar(255)` NOT NULL
- timestamps

### InterviewStep

- `id` Int PK
- `interviewFlowId` Int FK NOT NULL
- `interviewTypeId` Int FK NOT NULL
- `name` `VarChar(255)` NOT NULL
- `orderIndex` Int NOT NULL
- timestamps

### InterviewType

- `id` Int PK
- `name` `VarChar(255)` NOT NULL UNIQUE
- `description` `Text`
- timestamps

### Application

- `id` Int PK
- `positionId` Int FK NOT NULL
- `candidateId` Int FK NOT NULL
- `applicationDate` DateTime default now()
- `status` `ApplicationStatus` default `RECEIVED`
- `notes` `Text`
- timestamps

### Interview

- `id` Int PK
- `applicationId` Int FK NOT NULL
- `interviewStepId` Int FK NOT NULL
- `employeeId` Int FK NOT NULL
- `interviewDate` DateTime
- `result` `InterviewResult` default `PENDING`
- `score` Int (nullable hasta evaluar)
- `notes` `Text`
- timestamps

### Candidate (fusión)

- Sin cambios de tipo; solo se añade la relación inversa `applications Application[]`.

## 3. Reglas de integridad (cardinalidad + onDelete/onUpdate)

| Relación | Cardinalidad final | onDelete | onUpdate | Justificación |
| --- | --- | --- | --- | --- |
| Company → Employee | 1:N | `Restrict` | `Cascade` | No borrar una empresa con empleados vivos. |
| Company → Position | 1:N | `Restrict` | `Cascade` | Proteger histórico de ofertas. |
| InterviewFlow → Position | 1:N (corrige el 1:1 del ERD) | `Restrict` | `Cascade` | Un flujo se reutiliza en muchas posiciones. |
| InterviewFlow → InterviewStep | 1:N | `Cascade` | `Cascade` | Los pasos no tienen sentido sin su flujo. |
| InterviewType → InterviewStep | 1:N | `Restrict` | `Cascade` | No borrar un tipo usado por pasos existentes. |
| Position → Application | 1:N | `Restrict` | `Cascade` | Conservar candidaturas. |
| Candidate → Application | 1:N | `Cascade` | `Cascade` | Borrado del candidato (GDPR) arrastra sus candidaturas. |
| Application → Interview | 1:N | `Cascade` | `Cascade` | Las entrevistas dependen de la candidatura. |
| InterviewStep → Interview | 1:N (corrige el 1:1 del ERD) | `Restrict` | `Cascade` | Un paso se ejecuta en muchas entrevistas. |
| Employee → Interview | 1:N | `Restrict` | `Cascade` | No borrar entrevistador con histórico; usar `isActive=false`. |

### UNIQUE constraints

- `Employee.email` — UNIQUE
- `InterviewType.name` — UNIQUE
- `InterviewStep (interviewFlowId, orderIndex)` — UNIQUE (no repetir orden en un flujo)
- `Application (positionId, candidateId)` — UNIQUE (un candidato no aplica dos veces a la misma posición)
- `Candidate.email` — ya UNIQUE (se mantiene)

## 4. CHECK constraints

| Tabla           | CHECK                                            | Motivo                         |
| --------------- | ------------------------------------------------ | ------------------------------ |
| `Position`      | `salaryMin >= 0` y `salaryMax >= 0`              | Sin salarios negativos.        |
| `Position`      | `salaryMin <= salaryMax` (cuando ambos no nulos) | Coherencia del rango salarial. |
| `Interview`     | `score BETWEEN 0 AND 100` (cuando no nulo)       | Escala de puntuación acotada.  |
| `InterviewStep` | `orderIndex >= 0`                                | Orden no negativo.             |

> Los CHECK no son nativos del schema de Prisma; se añaden en la migración SQL (editando el `.sql` generado).

## Puntos a confirmar antes de generar el schema

1. `InterviewFlow → Position` e `InterviewStep → Interview` como **1:N** (corrigiendo los 1:1 del ERD).
2. `Interview.score` en rango **0–100** (¿o prefieres 1–10 / 1–5?).
3. `companyDescription` / `contactInfo` se quedan como **snapshot en `Position`** (no se normalizan a `Company`).

En cuanto me confirmes estos 3 puntos, genero el schema.prisma completo.

</br>

## Prompt 4:

Agent: Claude Code - Sonnet 4.6

### Request:

Confirmo los 3 puntos.

Confirmado. Genero el schema.prisma completo y lo escribo en el fichero, conservando intactos Candidate, Education, WorkExperience y Resume.

### Response:

He generado el schema.prisma completo. Resumen de lo aplicado:

Qué se mantuvo intacto Candidate, Education, WorkExperience, Resume — sin tocar tipos ni @unique. Solo se añadió la relación inversa applications Application[] en Candidate y un @@index([candidateId]) en las tres tablas hijas (FKs que no estaban indexadas).

Qué se añadió 5 enums: PositionStatus, EmploymentType, ApplicationStatus, InterviewResult, EmployeeRole. 8 modelos nuevos: Company, Employee, Position, InterviewFlow, InterviewType, InterviewStep, Application, Interview. Cardinalidades corregidas: InterviewFlow→Position e InterviewStep→Interview como 1:N. Tipos: Decimal(10,2) para salarios, @db.Date para applicationDeadline, Text para campos largos, VarChar(n) explícito. onDelete/onUpdate en cada FK según lo acordado. Timestamps (createdAt/updatedAt) en todas las entidades nuevas. Constraints e índices UNIQUE: Employee.email, InterviewType.name, InterviewStep(interviewFlowId, orderIndex), Application(positionId, candidateId). @@index: en todas las FK y en columnas de filtro frecuente (status, isVisible, fechas). Pendiente para el paso de migración Los CHECK constraints (salaryMin <= salaryMax, score BETWEEN 0 AND 100, orderIndex >= 0, salarios >= 0) no se pueden expresar en el schema de Prisma → se añadirán editando el .sql de la migración.

</br>
