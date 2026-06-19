-- =====================================================================
-- Consultas de comprobación del modelo ATS "LTI"
-- Buenas prácticas: JOINs explícitos, agregaciones, sin N+1
-- (una sola query resuelve lo que un ORM mal usado haría en N llamadas).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Todas las aplicaciones de una posición, con candidato y estado.
--    Índice aprovechado: Application_positionId_idx (filtro por positionId)
--    + PK de Candidate en el JOIN.
-- ---------------------------------------------------------------------
SELECT
  a.id                                   AS application_id,
  cand."firstName" || ' ' || cand."lastName" AS candidato,
  cand.email,
  a.status,
  a."applicationDate"
FROM "Application" a
JOIN "Candidate" cand ON cand.id = a."candidateId"
WHERE a."positionId" = 1
ORDER BY a."applicationDate" DESC;


-- ---------------------------------------------------------------------
-- 2) Por posición: nº de aplicaciones recibidas y nota media de entrevistas.
--    LEFT JOIN para incluir posiciones sin aplicaciones/entrevistas.
--    Índices aprovechados: Application_positionId_idx e Interview_applicationId_idx
--    en los JOINs.
-- ---------------------------------------------------------------------
SELECT
  p.id                          AS position_id,
  p.title,
  COUNT(DISTINCT a.id)          AS total_aplicaciones,
  ROUND(AVG(i.score), 2)        AS nota_media_entrevistas
FROM "Position" p
LEFT JOIN "Application" a ON a."positionId" = p.id
LEFT JOIN "Interview"   i ON i."applicationId" = a.id
GROUP BY p.id, p.title
ORDER BY total_aplicaciones DESC;


-- ---------------------------------------------------------------------
-- 3) Agenda de entrevistas de un empleado: candidato, posición y paso.
--    Índice aprovechado: Interview_employeeId_idx (filtro por employeeId)
--    + Interview_interviewDate_idx para el ORDER BY por fecha.
-- ---------------------------------------------------------------------
SELECT
  i."interviewDate",
  emp."name"                              AS entrevistador,
  cand."firstName" || ' ' || cand."lastName" AS candidato,
  p.title                                 AS posicion,
  st.name                                 AS paso,
  t.name                                  AS tipo_entrevista,
  i.result,
  i.score
FROM "Interview" i
JOIN "Employee"      emp  ON emp.id = i."employeeId"
JOIN "Application"   a    ON a.id = i."applicationId"
JOIN "Candidate"    cand  ON cand.id = a."candidateId"
JOIN "Position"     p     ON p.id = a."positionId"
JOIN "InterviewStep" st   ON st.id = i."interviewStepId"
JOIN "InterviewType" t    ON t.id = st."interviewTypeId"
WHERE i."employeeId" = 2
ORDER BY i."interviewDate";


-- ---------------------------------------------------------------------
-- 4) CTE + window function: ranking de candidatos por score medio
--    dentro de cada posición.
--    ROW_NUMBER() OVER (PARTITION BY position ORDER BY avg_score DESC).
--    Índices aprovechados: Application_positionId_idx, Application_candidateId_idx
--    e Interview_applicationId_idx en los JOINs del CTE.
-- ---------------------------------------------------------------------
WITH candidate_scores AS (
  SELECT
    p.id                AS position_id,
    p.title             AS position_title,
    cand.id             AS candidate_id,
    cand."firstName" || ' ' || cand."lastName" AS candidato,
    AVG(i.score)        AS avg_score,
    COUNT(i.id)         AS num_entrevistas
  FROM "Application" a
  JOIN "Position"  p    ON p.id = a."positionId"
  JOIN "Candidate" cand ON cand.id = a."candidateId"
  JOIN "Interview" i    ON i."applicationId" = a.id
  WHERE i.score IS NOT NULL
  GROUP BY p.id, p.title, cand.id, cand."firstName", cand."lastName"
)
SELECT
  position_title,
  candidato,
  ROUND(avg_score, 2) AS nota_media,
  num_entrevistas,
  ROW_NUMBER() OVER (PARTITION BY position_id ORDER BY avg_score DESC) AS ranking
FROM candidate_scores
ORDER BY position_title, ranking;
