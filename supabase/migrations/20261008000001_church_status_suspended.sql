-- ============================================================
-- DiscipleTrack - Migration 022: church status SUSPENDED
-- ============================================================
--
-- Slice 8 (ADR-022 decision 13). A church is ACTIVE, SUSPENDED
-- (reversible) or ARCHIVED (final in the app).
--
-- Alone in its file: a value added by ALTER TYPE ... ADD VALUE
-- cannot be used in the transaction that adds it, and the next
-- migrations use it.
--
-- References:
--   ADR-022, DATABASE_CONSTRAINTS.md section 1 (Church Status)
-- ============================================================

alter type public.church_status add value if not exists 'SUSPENDED' before 'ARCHIVED';
