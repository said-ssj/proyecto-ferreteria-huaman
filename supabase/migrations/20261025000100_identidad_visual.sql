BEGIN;
SELECT set_config('app.usuario','MIGRACION_IDENTIDAD_VISUAL',true),set_config('app.equipo','SQL_EDITOR',true);
CREATE TABLE huaman.identidad_visual (
 id smallint PRIMARY KEY DEFAULT 1 CHECK (id=1),
 logo_png bytea CHECK (octet_length(logo_png)<=524288),
 logo_sha256 varchar(64) CHECK (logo_sha256 ~ '^[0-9a-f]{64}$'),
 usar_logo_favicon boolean NOT NULL DEFAULT false,
 usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
 feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
 usmod varchar(100),pcmod varchar(100),fecmod timestamp,
 CHECK ((logo_png IS NULL)=(logo_sha256 IS NULL)),
 CHECK (logo_png IS NOT NULL OR NOT usar_logo_favicon)
);
COMMENT ON TABLE huaman.identidad_visual IS 'Identidad visual compartida; un PNG normalizado pequeño, sin archivos del catálogo';
ALTER TABLE huaman.identidad_visual ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.identidad_visual FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.identidad_visual FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.identidad_visual FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.identidad_visual FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
UPDATE huaman.rol SET nombre='Administrador/a' WHERE codigo='ADM' AND nombre IS DISTINCT FROM 'Administrador/a';
COMMIT;
