package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("db")
public class ReturnRepository {
    private final JdbcTemplate jdbc;

    public ReturnRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private ReturnRow mapRow(ResultSet rs, int rowNum) throws SQLException {
        long id = rs.getLong("id");
        return new ReturnRow(
            id,
            String.format("DV-%06d", id),
            rs.getLong("ventaId"),
            rs.getString("comprobante"),
            rs.getString("tipoComprobante"),
            rs.getString("clienteNombre"),
            rs.getString("clienteDocumento"),
            rs.getString("fechaSolicitud"),
            rs.getString("estadoDevolucion"),
            rs.getString("formaReintegro"),
            rs.getBigDecimal("montoReintegro"),
            rs.getString("motivo"),
            rs.getLong("solicitanteId"),
            rs.getString("solicitanteNombre"),
            rs.getObject("autorizadorId") != null ? rs.getLong("autorizadorId") : null,
            rs.getString("autorizadorNombre"),
            rs.getString("fechaDecision"),
            rs.getString("motivoRechazo"),
            rs.getObject("cajaId") != null ? rs.getLong("cajaId") : null,
            rs.getString("observacionAprobacion"),
            rs.getInt("totalItems")
        );
    }

    public Summary summary(Long solicitanteId) {
        String sql = """
            select 
              count(*) filter (where d.estado_devolucion = 'PENDIENTE') as pendientes,
              count(*) filter (where d.estado_devolucion = 'APROBADA' and d.fecha_decision::date = timezone('America/Lima', now())::date) as "aprobadasHoy",
              coalesce(sum(d.monto_reintegro) filter (where d.estado_devolucion = 'APROBADA' and d.fecha_decision::date = timezone('America/Lima', now())::date), 0) as "montoReintegradoHoy"
            from huaman.devolucion d
            where d.estado = 'A'
              and (?::bigint is null or d.id_solicita = ?)
            """;
        return jdbc.queryForObject(sql, (rs, n) -> new Summary(
            rs.getLong("pendientes"),
            rs.getLong("aprobadasHoy"),
            rs.getBigDecimal("montoReintegradoHoy")
        ), solicitanteId, solicitanteId);
    }

    public Page<ReturnRow> list(String estado, String buscar, LocalDate desde, LocalDate hasta, Long solicitanteId, int pagina, int tamano) {
        int safePage = Math.max(0, pagina);
        int safeSize = Math.max(1, Math.min(tamano, 100));
        int offset = safePage * safeSize;

        String pattern = (buscar == null || buscar.isBlank()) ? null : "%" + buscar.trim().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        String normalizedEstado = (estado == null || estado.isBlank() || estado.equalsIgnoreCase("TODAS")) ? null : estado.toUpperCase();

        String countSql = """
            select count(*)
            from huaman.devolucion d
            join huaman.venta v on v.id_venta = d.id_venta
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
            left join huaman.cliente cli on cli.id_cliente = v.id_cliente
            where d.estado = 'A'
              and (?::text is null or d.estado_devolucion = ?)
              and (?::date is null or d.fecha_solicitud::date >= ?)
              and (?::date is null or d.fecha_solicitud::date <= ?)
              and (?::bigint is null or d.id_solicita = ?)
              and (?::text is null or (
                  d.id_devolucion::text ilike ? or
                  ('DV-' || lpad(d.id_devolucion::text, 6, '0')) ilike ? or
                  ('V-' || v.id_venta::text) ilike ? or
                  coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), '') ilike ? or
                  coalesce(cli.nombre_razon_social, comp.cliente_nombre, '') ilike ? or
                  coalesce(cli.nro_documento, comp.cliente_nro_doc, '') ilike ?
              ))
            """;

        long total = jdbc.queryForObject(countSql, Long.class,
            normalizedEstado, normalizedEstado,
            desde, desde,
            hasta, hasta,
            solicitanteId, solicitanteId,
            pattern,
            pattern, pattern, pattern, pattern, pattern, pattern
        );

        String dataSql = """
            select 
              d.id_devolucion id,
              d.id_venta "ventaId",
              case when comp.serie is not null then comp.serie || '-' || lpad(comp.numero::text, 8, '0') else ('V-' || v.id_venta::text) end comprobante,
              v.tipo_comprobante "tipoComprobante",
              coalesce(cli.nombre_razon_social, comp.cliente_nombre, 'CLIENTE VARIOS') "clienteNombre",
              coalesce(cli.nro_documento, comp.cliente_nro_doc, '') "clienteDocumento",
              to_char(d.fecha_solicitud, 'YYYY-MM-DD HH24:MI:SS') "fechaSolicitud",
              d.estado_devolucion "estadoDevolucion",
              d.forma_reintegro "formaReintegro",
              d.monto_reintegro "montoReintegro",
              d.motivo,
              d.id_solicita "solicitanteId",
              concat_ws(' ', u_sol.nombres, u_sol.apellidos) "solicitanteNombre",
              d.id_autoriza "autorizadorId",
              case when u_aut.id_usuario is not null then concat_ws(' ', u_aut.nombres, u_aut.apellidos) else null end "autorizadorNombre",
              to_char(d.fecha_decision, 'YYYY-MM-DD HH24:MI:SS') "fechaDecision",
              d.motivo_rechazo "motivoRechazo",
              d.id_caja "cajaId",
              d.observacion_aprobacion "observacionAprobacion",
              (select count(*) from huaman.detalle_devolucion dd where dd.id_devolucion = d.id_devolucion and dd.estado = 'A') "totalItems"
            from huaman.devolucion d
            join huaman.venta v on v.id_venta = d.id_venta
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
            left join huaman.cliente cli on cli.id_cliente = v.id_cliente
            join huaman.usuario u_sol on u_sol.id_usuario = d.id_solicita
            left join huaman.usuario u_aut on u_aut.id_usuario = d.id_autoriza
            where d.estado = 'A'
              and (?::text is null or d.estado_devolucion = ?)
              and (?::date is null or d.fecha_solicitud::date >= ?)
              and (?::date is null or d.fecha_solicitud::date <= ?)
              and (?::bigint is null or d.id_solicita = ?)
              and (?::text is null or (
                  d.id_devolucion::text ilike ? or
                  ('DV-' || lpad(d.id_devolucion::text, 6, '0')) ilike ? or
                  ('V-' || v.id_venta::text) ilike ? or
                  coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), '') ilike ? or
                  coalesce(cli.nombre_razon_social, comp.cliente_nombre, '') ilike ? or
                  coalesce(cli.nro_documento, comp.cliente_nro_doc, '') ilike ?
              ))
            order by 
              case when d.estado_devolucion = 'PENDIENTE' then 0 else 1 end,
              d.fecha_solicitud desc,
              d.id_devolucion desc
            limit ? offset ?
            """;

        List<ReturnRow> rows = jdbc.query(dataSql, this::mapRow,
            normalizedEstado, normalizedEstado,
            desde, desde,
            hasta, hasta,
            solicitanteId, solicitanteId,
            pattern,
            pattern, pattern, pattern, pattern, pattern, pattern,
            safeSize, offset
        );

        return new Page<>(rows, total, safePage, safeSize);
    }

    public Optional<ReturnRow> findById(Long id) {
        String sql = """
            select 
              d.id_devolucion id,
              d.id_venta "ventaId",
              case when comp.serie is not null then comp.serie || '-' || lpad(comp.numero::text, 8, '0') else ('V-' || v.id_venta::text) end comprobante,
              v.tipo_comprobante "tipoComprobante",
              coalesce(cli.nombre_razon_social, comp.cliente_nombre, 'CLIENTE VARIOS') "clienteNombre",
              coalesce(cli.nro_documento, comp.cliente_nro_doc, '') "clienteDocumento",
              to_char(d.fecha_solicitud, 'YYYY-MM-DD HH24:MI:SS') "fechaSolicitud",
              d.estado_devolucion "estadoDevolucion",
              d.forma_reintegro "formaReintegro",
              d.monto_reintegro "montoReintegro",
              d.motivo,
              d.id_solicita "solicitanteId",
              concat_ws(' ', u_sol.nombres, u_sol.apellidos) "solicitanteNombre",
              d.id_autoriza "autorizadorId",
              case when u_aut.id_usuario is not null then concat_ws(' ', u_aut.nombres, u_aut.apellidos) else null end "autorizadorNombre",
              to_char(d.fecha_decision, 'YYYY-MM-DD HH24:MI:SS') "fechaDecision",
              d.motivo_rechazo "motivoRechazo",
              d.id_caja "cajaId",
              d.observacion_aprobacion "observacionAprobacion",
              (select count(*) from huaman.detalle_devolucion dd where dd.id_devolucion = d.id_devolucion and dd.estado = 'A') "totalItems"
            from huaman.devolucion d
            join huaman.venta v on v.id_venta = d.id_venta
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
            left join huaman.cliente cli on cli.id_cliente = v.id_cliente
            join huaman.usuario u_sol on u_sol.id_usuario = d.id_solicita
            left join huaman.usuario u_aut on u_aut.id_usuario = d.id_autoriza
            where d.id_devolucion = ? and d.estado = 'A'
            """;
        return jdbc.query(sql, this::mapRow, id).stream().findFirst();
    }

    public List<ReturnItem> listItems(Long idDevolucion) {
        String sql = """
            select 
              dd.id_detalle_devolucion id,
              dd.id_detalle_venta "idDetalleVenta",
              dd.id_producto "productoId",
              p.codigo "codigoProducto",
              p.nombre "nombreProducto",
              dd.id_presentacion "presentacionId",
              dd.presentacion_nombre "presentacionNombre",
              dd.unidad_base_simbolo "unidadBaseSimbolo",
              dd.factor_base "factorBase",
              dd.cantidad,
              dd.estado_producto "estadoProducto",
              dd.importe,
              coalesce(dd.unidades_retorno::text, '[]') "unidadesRetorno"
            from huaman.detalle_devolucion dd
            join huaman.producto p on p.id_producto = dd.id_producto
            where dd.id_devolucion = ? and dd.estado = 'A'
            order by dd.id_detalle_devolucion asc
            """;
        return jdbc.query(sql, (rs, n) -> new ReturnItem(
            rs.getLong("id"),
            rs.getLong("idDetalleVenta"),
            rs.getLong("productoId"),
            rs.getString("codigoProducto"),
            rs.getString("nombreProducto"),
            rs.getLong("presentacionId"),
            rs.getString("presentacionNombre"),
            rs.getString("unidadBaseSimbolo"),
            rs.getBigDecimal("factorBase"),
            rs.getBigDecimal("cantidad"),
            rs.getString("estadoProducto"),
            rs.getBigDecimal("importe"),
            rs.getString("unidadesRetorno")
        ), idDevolucion);
    }

    public Optional<ReturnDetail> getDetail(Long id) {
        return findById(id).map(row -> new ReturnDetail(row, listItems(id)));
    }

    public int getReturnDays() {
        try {
            Integer days = jdbc.queryForObject(
                "select valor::integer from huaman.parametro_sistema where clave = 'VENTAS.DEVOLUCION_DIAS' and estado = 'A'",
                Integer.class
            );
            return days != null && days > 0 ? days : 30;
        } catch (Exception e) {
            return 30;
        }
    }

    public List<SaleLookup> searchSales(String termino, int maxDays) {
        String pattern = (termino == null || termino.isBlank()) ? "%" : "%" + termino.trim().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        String sql = """
            select 
              v.id_venta "idVenta",
              ('V-' || v.id_venta::text) "codigoVenta",
              v.tipo_comprobante "tipoComprobante",
              comp.serie,
              comp.numero correlativo,
              case when comp.serie is not null then comp.serie || '-' || lpad(comp.numero::text, 8, '0') else ('V-' || v.id_venta::text) end comprobante,
              to_char(v.fecha_venta, 'YYYY-MM-DD HH24:MI:SS') "fechaVenta",
              (timezone('America/Lima', now())::date - v.fecha_venta::date) "diasTranscurridos",
              coalesce(cli.nombre_razon_social, comp.cliente_nombre, 'CLIENTE VARIOS') "clienteNombre",
              coalesce(cli.nro_documento, comp.cliente_nro_doc, '') "clienteDocumento",
              v.total,
              cc.saldo "saldoDeuda",
              (select string_agg(distinct p.medio, ', ') from huaman.pago p where p.id_venta = v.id_venta and p.estado = 'A') "mediosPago"
            from huaman.venta v
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
            left join huaman.cliente cli on cli.id_cliente = v.id_cliente
            left join huaman.cuenta_por_cobrar cc on cc.id_venta = v.id_venta and cc.estado = 'A'
            where v.estado = 'A'
              and v.estado_venta = 'CONFIRMADA'
              and (timezone('America/Lima', now())::date - v.fecha_venta::date) between 0 and ?
              and not exists (
                select 1 from huaman.devolucion dev 
                where dev.id_venta = v.id_venta and dev.estado = 'A' and dev.estado_devolucion = 'PENDIENTE'
              )
              and (v.entrega_inmediata = true or exists (
                select 1 from huaman.despacho desp 
                where desp.id_venta = v.id_venta and desp.estado = 'A' and desp.estado_despacho = 'ENTREGADO'
              ))
              and (
                ('V-' || v.id_venta::text) ilike ? or
                coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), '') ilike ? or
                coalesce(cli.nombre_razon_social, comp.cliente_nombre, '') ilike ? or
                coalesce(cli.nro_documento, comp.cliente_nro_doc, '') ilike ?
              )
            order by v.fecha_venta desc
            limit 20
            """;
        return jdbc.query(sql, (rs, n) -> new SaleLookup(
            rs.getLong("idVenta"),
            rs.getString("codigoVenta"),
            rs.getString("tipoComprobante"),
            rs.getString("serie"),
            rs.getObject("correlativo") != null ? rs.getInt("correlativo") : null,
            rs.getString("comprobante"),
            rs.getString("fechaVenta"),
            rs.getInt("diasTranscurridos"),
            rs.getString("clienteNombre"),
            rs.getString("clienteDocumento"),
            rs.getBigDecimal("total"),
            rs.getBigDecimal("saldoDeuda"),
            rs.getString("mediosPago")
        ), maxDays, pattern, pattern, pattern, pattern);
    }

    public Optional<SaleDetailLookup> getSaleForReturn(Long idVenta, int maxDays) {
        String saleSql = """
            select 
              v.id_venta "idVenta",
              ('V-' || v.id_venta::text) "codigoVenta",
              v.tipo_comprobante "tipoComprobante",
              comp.serie,
              comp.numero correlativo,
              case when comp.serie is not null then comp.serie || '-' || lpad(comp.numero::text, 8, '0') else ('V-' || v.id_venta::text) end comprobante,
              to_char(v.fecha_venta, 'YYYY-MM-DD HH24:MI:SS') "fechaVenta",
              (timezone('America/Lima', now())::date - v.fecha_venta::date) "diasTranscurridos",
              coalesce(cli.nombre_razon_social, comp.cliente_nombre, 'CLIENTE VARIOS') "clienteNombre",
              coalesce(cli.nro_documento, comp.cliente_nro_doc, '') "clienteDocumento",
              v.total,
              cc.saldo "saldoDeuda",
              (select string_agg(distinct p.medio, ', ') from huaman.pago p where p.id_venta = v.id_venta and p.estado = 'A') "mediosPago"
            from huaman.venta v
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
            left join huaman.cliente cli on cli.id_cliente = v.id_cliente
            left join huaman.cuenta_por_cobrar cc on cc.id_venta = v.id_venta and cc.estado = 'A'
            where v.id_venta = ? and v.estado = 'A' and v.estado_venta='CONFIRMADA'
              and (timezone('America/Lima',now())::date-v.fecha_venta::date) between 0 and ?
              and not exists(select 1 from huaman.devolucion d where d.id_venta=v.id_venta and d.estado='A' and d.estado_devolucion='PENDIENTE')
              and (v.entrega_inmediata or exists(select 1 from huaman.despacho d where d.id_venta=v.id_venta and d.estado='A' and d.estado_despacho='ENTREGADO'))
            """;

        List<SaleLookup> saleList = jdbc.query(saleSql, (rs, n) -> new SaleLookup(
            rs.getLong("idVenta"),
            rs.getString("codigoVenta"),
            rs.getString("tipoComprobante"),
            rs.getString("serie"),
            rs.getObject("correlativo") != null ? rs.getInt("correlativo") : null,
            rs.getString("comprobante"),
            rs.getString("fechaVenta"),
            rs.getInt("diasTranscurridos"),
            rs.getString("clienteNombre"),
            rs.getString("clienteDocumento"),
            rs.getBigDecimal("total"),
            rs.getBigDecimal("saldoDeuda"),
            rs.getString("mediosPago")
        ), idVenta, maxDays);

        if (saleList.isEmpty()) {
            return Optional.empty();
        }
        SaleLookup sale = saleList.getFirst();

        String itemsSql = """
            select 
              dv.id_detalle_venta "idDetalleVenta",
              dv.id_producto "productoId",
              p.codigo "codigoProducto",
              p.nombre "nombreProducto",
              p.modo_control "modoControl",
              p.incremento_base "incrementoBase",
              dv.id_presentacion "presentacionId",
              dv.presentacion_nombre "presentacionNombre",
              dv.unidad_base_simbolo "unidadBaseSimbolo",
              dv.factor_base "factorBase",
              dv.cantidad "cantidadVendida",
              dv.precio_unitario "precioUnitario",
              dv.importe "importeOriginal",
              coalesce((
                select sum(dd.cantidad)
                from huaman.detalle_devolucion dd
                join huaman.devolucion d on d.id_devolucion = dd.id_devolucion
                where dd.id_detalle_venta = dv.id_detalle_venta
                  and d.estado_devolucion = 'APROBADA'
                  and d.estado = 'A'
                  and dd.estado = 'A'
              ), 0) "yaDevuelto"
            from huaman.detalle_venta dv
            join huaman.producto p on p.id_producto = dv.id_producto
            where dv.id_venta = ? and dv.estado = 'A'
            order by dv.id_detalle_venta asc
            """;

        List<SaleItemLookup> items = jdbc.query(itemsSql, (rs, n) -> {
            BigDecimal vendida = rs.getBigDecimal("cantidadVendida");
            BigDecimal devuelta = rs.getBigDecimal("yaDevuelto");
            BigDecimal disponible = vendida.subtract(devuelta);
            if (disponible.compareTo(BigDecimal.ZERO) < 0) disponible = BigDecimal.ZERO;

            return new SaleItemLookup(
                rs.getLong("idDetalleVenta"),
                rs.getLong("productoId"),
                rs.getString("codigoProducto"),
                rs.getString("nombreProducto"),
                rs.getString("modoControl"),
                rs.getBigDecimal("incrementoBase"),
                rs.getLong("presentacionId"),
                rs.getString("presentacionNombre"),
                rs.getString("unidadBaseSimbolo"),
                rs.getBigDecimal("factorBase"),
                vendida,
                rs.getBigDecimal("precioUnitario"),
                rs.getBigDecimal("importeOriginal"),
                devuelta,
                disponible,
                returnPresentations(rs.getLong("productoId"))
            );
        }, idVenta);

        // Monetary collections
        String moneySql = """
            select 
              (
                coalesce((select sum(monto) from huaman.pago where id_venta = ? and estado = 'A' and medio = 'EFECTIVO'), 0) +
                coalesce((select sum(a.monto) from huaman.abono_credito a join huaman.cuenta_por_cobrar cc using(id_cuenta) where cc.id_venta = ? and a.estado = 'A' and a.medio = 'EFECTIVO'), 0) -
                coalesce((select sum(monto_reintegro) from huaman.devolucion where id_venta = ? and estado = 'A' and estado_devolucion = 'APROBADA' and forma_reintegro = 'EFECTIVO'), 0)
              ) as "efectivoDisp",
              (
                coalesce((select sum(monto) from huaman.pago where id_venta = ? and estado = 'A' and medio = 'YAPE'), 0) +
                coalesce((select sum(a.monto) from huaman.abono_credito a join huaman.cuenta_por_cobrar cc using(id_cuenta) where cc.id_venta = ? and a.estado = 'A' and a.medio = 'YAPE'), 0) -
                coalesce((select sum(monto_reintegro) from huaman.devolucion where id_venta = ? and estado = 'A' and estado_devolucion = 'APROBADA' and forma_reintegro = 'YAPE'), 0)
              ) as "yapeDisp",
              (
                coalesce((select sum(monto) from huaman.pago where id_venta = ? and estado = 'A' and medio = 'DEBITO'), 0) +
                coalesce((select sum(a.monto) from huaman.abono_credito a join huaman.cuenta_por_cobrar cc using(id_cuenta) where cc.id_venta = ? and a.estado = 'A' and a.medio = 'DEBITO'), 0) -
                coalesce((select sum(monto_reintegro) from huaman.devolucion where id_venta = ? and estado = 'A' and estado_devolucion = 'APROBADA' and forma_reintegro = 'DEBITO'), 0)
              ) as "debitoDisp",
              (
                coalesce((select sum(monto) from huaman.pago where id_venta = ? and estado = 'A' and medio <> 'CREDITO'), 0) +
                coalesce((select sum(a.monto) from huaman.abono_credito a join huaman.cuenta_por_cobrar cc using(id_cuenta) where cc.id_venta = ? and a.estado = 'A'), 0) -
                coalesce((select sum(monto_reintegro) from huaman.devolucion where id_venta = ? and estado = 'A' and estado_devolucion = 'APROBADA' and forma_reintegro <> 'DESCUENTO_DEUDA'), 0)
              ) as "totalMonetarioDisp",
              coalesce((select saldo from huaman.cuenta_por_cobrar where id_venta = ? and estado = 'A' and estado_cuenta in ('PENDIENTE','VENCIDA')), 0) as "saldoDeuda"
            """;

        return jdbc.query(moneySql, (rs, n) -> new SaleDetailLookup(
            sale,
            items,
            rs.getBigDecimal("efectivoDisp"),
            rs.getBigDecimal("yapeDisp"),
            rs.getBigDecimal("debitoDisp"),
            rs.getBigDecimal("totalMonetarioDisp"),
            rs.getBigDecimal("saldoDeuda")
        ), idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta, idVenta).stream().findFirst();
    }

    private List<ReturnPresentation> returnPresentations(long productId) {
        return jdbc.query("select id_presentacion,nombre,factor_base from huaman.presentacion_producto where id_producto=? and estado='A' and id_unidad_venta is null order by factor_base,nombre",
            (r,n)->new ReturnPresentation(r.getLong(1),r.getString(2),r.getBigDecimal(3)),productId);
    }

    public Optional<CashOption> getTodayCash() {
        String sql = """
            select 
              c.id_caja id,
              c.fecha,
              c.estado_caja estado,
              coalesce((
                select sum(case when sentido = 'I' then importe else -importe end)
                from huaman.movimiento_caja
                where id_caja = c.id_caja and medio = 'EFECTIVO' and estado = 'A'
              ), 0) "efectivoDisponible"
            from huaman.caja_diaria c
            where c.estado = 'A' and c.fecha = timezone('America/Lima', now())::date
            order by c.id_caja desc
            limit 1
            """;
        return jdbc.query(sql, (rs, n) -> new CashOption(
            rs.getLong("id"),
            rs.getDate("fecha").toLocalDate(),
            rs.getString("estado"),
            rs.getBigDecimal("efectivoDisponible")
        )).stream().findFirst();
    }

    public Optional<Long> replay(long actor, String action, UUID key, String request) {
        jdbc.queryForObject("select pg_advisory_xact_lock(hashtextextended(?,0))", Object.class, "RETURN_API:" + key);
        var rows = jdbc.queryForList("""
            select id_entidad id, id_usuario=? and accion=? and valor_nuevo->'solicitud'=?::jsonb valid
            from huaman.bitacora_evento where referencia=?
            """, actor, action, request, "RETURN_API:" + key);
        if (rows.isEmpty()) return Optional.empty();
        if (rows.size()!=1 || !Boolean.TRUE.equals(rows.getFirst().get("valid")))
            throw new com.ferreteriahuaman.security.AuthFailure(409, "Esta clave ya corresponde a otra solicitud");
        return Optional.of(((Number)rows.getFirst().get("id")).longValue());
    }

    public void record(long actor, String action, long id, UUID key, String request) {
        jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) values(?,?,'devolucion',?,?,jsonb_build_object('solicitud',?::jsonb))",
            actor, action, id, "RETURN_API:"+key, request);
    }

    public Long solicitarDevolucion(Long ventaId, String forma, String motivo, String lineasJson, UUID clave) {
        String sql = "select huaman.solicitar_devolucion(?, ?, ?, ?::jsonb, ?)";
        return jdbc.queryForObject(sql, Long.class, ventaId, forma, motivo, lineasJson, clave);
    }

    public Long aprobarDevolucion(Long idDevolucion, Long idCaja, UUID clave, String referencia, String observacion) {
        String sql = "select huaman.aprobar_devolucion(?, ?, ?, ?, ?)";
        return jdbc.queryForObject(sql, Long.class, idDevolucion, idCaja, clave, referencia, observacion);
    }

    public Long rechazarDevolucion(Long idDevolucion, UUID clave, String motivo) {
        String sql = "select huaman.rechazar_devolucion(?, ?, ?)";
        return jdbc.queryForObject(sql, Long.class, idDevolucion, clave, motivo);
    }
}
