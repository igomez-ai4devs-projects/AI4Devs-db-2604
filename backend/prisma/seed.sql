-- =====================================================================
-- Datos de ejemplo — flujo completo del ATS "LTI"
-- Orden de inserción respetando las claves foráneas:
--   Company -> Employee
--   InterviewType -> InterviewFlow -> InterviewStep
--   Company + InterviewFlow -> Position
--   Candidate -> Application (Position + Candidate)
--   Application + InterviewStep + Employee -> Interview
-- Todo dentro de una transacción para que sea atómico.
--
-- NOTA: la columna "updatedAt" la rellena Prisma Client (@updatedAt) en runtime,
-- pero NO tiene default en la BD. Al insertar por SQL plano hay que asignarla
-- explícitamente (usamos CURRENT_TIMESTAMP). "createdAt" sí tiene default.
-- =====================================================================

BEGIN;

-- 1) Empresa
INSERT INTO "Company" ("name", "updatedAt")
VALUES ('LTI Talent S.L.', CURRENT_TIMESTAMP);

-- 2) Empleados de esa empresa (reclutador + entrevistador técnico)
INSERT INTO "Employee" ("companyId", "name", "email", "role", "isActive", "updatedAt")
VALUES
  ((SELECT id FROM "Company" WHERE "name" = 'LTI Talent S.L.'),
   'Ana Gómez',  'ana.gomez@lti.com',  'RECRUITER',   true, CURRENT_TIMESTAMP),
  ((SELECT id FROM "Company" WHERE "name" = 'LTI Talent S.L.'),
   'Luis Pérez', 'luis.perez@lti.com', 'INTERVIEWER', true, CURRENT_TIMESTAMP);

-- 3) Tipos de entrevista (catálogo reutilizable)
INSERT INTO "InterviewType" ("name", "description", "updatedAt")
VALUES
  ('HR Screening',    'Entrevista inicial de recursos humanos',   CURRENT_TIMESTAMP),
  ('Technical Test',  'Prueba técnica práctica',                  CURRENT_TIMESTAMP),
  ('Final Interview', 'Entrevista final con el hiring manager',   CURRENT_TIMESTAMP);

-- 4) Flujo de entrevistas
INSERT INTO "InterviewFlow" ("description", "updatedAt")
VALUES ('Flujo estándar para roles de ingeniería', CURRENT_TIMESTAMP);

-- 5) Pasos del flujo (orden 1..3), enlazando flujo + tipo
INSERT INTO "InterviewStep" ("interviewFlowId", "interviewTypeId", "name", "orderIndex", "updatedAt")
VALUES
  ((SELECT id FROM "InterviewFlow" WHERE "description" = 'Flujo estándar para roles de ingeniería'),
   (SELECT id FROM "InterviewType" WHERE "name" = 'HR Screening'),    'Filtro RRHH',      1, CURRENT_TIMESTAMP),
  ((SELECT id FROM "InterviewFlow" WHERE "description" = 'Flujo estándar para roles de ingeniería'),
   (SELECT id FROM "InterviewType" WHERE "name" = 'Technical Test'),  'Prueba técnica',   2, CURRENT_TIMESTAMP),
  ((SELECT id FROM "InterviewFlow" WHERE "description" = 'Flujo estándar para roles de ingeniería'),
   (SELECT id FROM "InterviewType" WHERE "name" = 'Final Interview'), 'Entrevista final', 3, CURRENT_TIMESTAMP);

-- 6) Posición publicada (visible y abierta), con su empresa y flujo
INSERT INTO "Position" (
  "companyId", "interviewFlowId", "title", "description", "status", "isVisible",
  "location", "jobDescription", "requirements", "responsibilities",
  "salaryMin", "salaryMax", "employmentType", "benefits",
  "companyDescription", "applicationDeadline", "contactInfo", "updatedAt"
)
VALUES (
  (SELECT id FROM "Company" WHERE "name" = 'LTI Talent S.L.'),
  (SELECT id FROM "InterviewFlow" WHERE "description" = 'Flujo estándar para roles de ingeniería'),
  'Senior Backend Engineer',
  'Desarrollo de APIs y servicios backend',
  'OPEN', true,
  'Madrid (híbrido)',
  'Diseño e implementación de microservicios en Node.js + PostgreSQL',
  'Node.js, TypeScript, PostgreSQL, 5+ años de experiencia',
  'Diseñar APIs, revisar PRs, mentorizar al equipo',
  45000.00, 65000.00, 'FULL_TIME',
  'Seguro médico, teletrabajo, formación',
  'LTI es una consultora tecnológica especializada en talento',
  DATE '2026-09-30',
  'jobs@lti.com',
  CURRENT_TIMESTAMP
);

-- 7) Candidato (esta tabla no tiene timestamps)
INSERT INTO "Candidate" ("firstName", "lastName", "email", "phone", "address")
VALUES ('María', 'López', 'maria.lopez@example.com', '600111222', 'Calle Mayor 1, Madrid');

-- 8) Aplicación del candidato a la posición
INSERT INTO "Application" ("positionId", "candidateId", "applicationDate", "status", "notes", "updatedAt")
VALUES (
  (SELECT id FROM "Position"  WHERE "title" = 'Senior Backend Engineer'),
  (SELECT id FROM "Candidate" WHERE "email" = 'maria.lopez@example.com'),
  CURRENT_TIMESTAMP, 'INTERVIEWING', 'Perfil muy alineado con el puesto', CURRENT_TIMESTAMP
);

-- 9) Entrevista: paso "Prueba técnica" conducida por el entrevistador Luis Pérez
INSERT INTO "Interview" (
  "applicationId", "interviewStepId", "employeeId",
  "interviewDate", "result", "score", "notes", "updatedAt"
)
VALUES (
  (SELECT a.id FROM "Application" a
     JOIN "Candidate" c ON c.id = a."candidateId"
     WHERE c."email" = 'maria.lopez@example.com'),
  (SELECT id FROM "InterviewStep" WHERE "name" = 'Prueba técnica'),
  (SELECT id FROM "Employee" WHERE "email" = 'luis.perez@lti.com'),
  CURRENT_TIMESTAMP, 'PASSED', 85, 'Buen dominio técnico, resolvió el ejercicio', CURRENT_TIMESTAMP
);

COMMIT;
