package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.CreditModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("db")
public class CreditRepository {
    private final JdbcTemplate jdbc;

    public CreditRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private Map<String, Object> row(ResultSet r, int n) throws SQLException {
        var map = new LinkedHashMap<String, Object>();
        var meta = r.getMetaData();
        for (int i = 1; i <= meta.getColumnCount(); i++) {
            Object v = r.getObject(i);
            if (v instanceof BigDecimal d) v = d.toPlainString();
            else if (v instanceof Timestamp t) v = t.toLocalDateTime().toString();
            else if (v instanceof java.sql.Date d) v = d.toLocalDate().toString();
            else if (v instanceof UUID u) v = u.toString();
            map.put(meta.getColumnLabel(i), v);
        }
        return map;
    }

    public Summary summary() {
        return jdbc.queryForObject("""
            select 
              coalesce(sum(case when c.estado='A' and c.estado_cuenta in ('PENDIENTE','VENCIDA') then c.saldo else 0 end), 0) "totalPorCobrar",
              coalesce(sum(case when c.estado='A' and (c.estado_cuenta='VENCIDA' or (c.estado_cuenta='PENDIENTE' and c.fecha_vencimiento < timezone('America/Lima', now())::date)) and c.saldo>0 then c.saldo else 0 end), 0) "totalVencido",
              coalesce(count(distinct case when c.estado='A' and c.estado_cuenta in ('PENDIENTE','VENCIDA') and c.saldo>0 then c.id_cliente else null end), 0) "clientesDeudores"
            from huaman.cuenta_por_cobrar c
            """, (rs, rowNum) -> new Summary(
                rs.getBigDecimal("totalPorCobrar"),
                rs.getBigDecimal("totalVencido"),
                rs.getLong("clientesDeudores")
            ));
    }

    public Page<Map<String, Object>> list(String q, String estado, Boolean soloVencidas, LocalDate desde, LocalDate hasta, int page, int size) {
        String e = Character.toString(92);
        String pattern = "%" + q.replace(e, e + e).replace("%", e + "%").replace("_", e + "_") + "%";
        String from = " from huaman.cuenta_por_cobrar c join huaman.cliente cli on cli.id_cliente = c.id_cliente join huaman.venta v on v.id_venta = c.id_venta left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta ";
        
        StringBuilder where = new StringBuilder("where c.estado='A' ");
        var args = new ArrayList<Object>();

        if (!q.isBlank()) {
            where.append("and (cli.nombre_razon_social ilike ? or coalesce(cli.nro_documento, '') ilike ? or coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), '') ilike ? or v.id_venta::text ilike ?) ");
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
        }

        if (Boolean.TRUE.equals(soloVencidas)) {
            where.append("and (c.saldo > 0 and (c.estado_cuenta = 'VENCIDA' or c.fecha_vencimiento < timezone('America/Lima', now())::date) and c.estado_cuenta <> 'ANULADA') ");
        } else if (!estado.isBlank()) {
            switch (estado.toUpperCase(Locale.ROOT)) {
                case "PENDIENTE" -> where.append("and (c.saldo > 0 and c.fecha_vencimiento >= timezone('America/Lima', now())::date and c.estado_cuenta <> 'ANULADA') ");
                case "VENCIDA" -> where.append("and (c.saldo > 0 and (c.estado_cuenta = 'VENCIDA' or c.fecha_vencimiento < timezone('America/Lima', now())::date) and c.estado_cuenta <> 'ANULADA') ");
                case "CANCELADA" -> where.append("and (c.saldo = 0 and c.estado_cuenta = 'CANCELADA') ");
                case "ANULADA" -> where.append("and c.estado_cuenta = 'ANULADA' ");
            }
        }

        if (desde != null) {
            where.append("and c.fecha_vencimiento >= ?::date ");
            args.add(desde);
        }
        if (hasta != null) {
            where.append("and c.fecha_vencimiento <= ?::date ");
            args.add(hasta);
        }

        long count = jdbc.queryForObject("select count(*)" + from + where, Long.class, args.toArray());

        String sql = """
            select 
              c.id_cuenta id,
              c.id_venta "ventaId",
              c.id_cliente "clienteId",
              cli.nombre_razon_social cliente,
              coalesce(cli.tipo_documento || ' ' || cli.nro_documento, cli.nro_documento) documento,
              comp.tipo_comprobante "tipoComprobante",
              comp.serie,
              comp.numero,
              coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), 'V-' || v.id_venta) comprobante,
              v.fecha_venta::date "fechaVenta",
              c.monto_original "montoOriginal",
              (select coalesce(sum(a.monto),0) from huaman.abono_credito a where a.id_cuenta=c.id_cuenta and a.estado='A') "montoAbonado",
              c.saldo,
              c.fecha_vencimiento "fechaVencimiento",
              case 
                when c.saldo = 0 then 'CANCELADA' 
                when c.fecha_vencimiento < timezone('America/Lima', now())::date then 'VENCIDA' 
                when c.fecha_vencimiento <= timezone('America/Lima', now())::date + 7 then 'POR_VENCER' 
                else 'AL_DIA' 
              end situacion,
              case 
                when c.estado_cuenta = 'ANULADA' then 'ANULADA' 
                when c.saldo = 0 then 'CANCELADA' 
                when c.fecha_vencimiento < timezone('America/Lima', now())::date then 'VENCIDA' 
                else 'PENDIENTE' 
              end "estadoCuenta",
              coalesce(c.fecmod, c.feccre) version
            """ + from + where + """
            order by c.saldo > 0 desc, c.fecha_vencimiento asc, c.id_cuenta desc limit ? offset ?
            """;

        var queryArgs = new ArrayList<>(args);
        queryArgs.add(size);
        queryArgs.add((long) page * size);

        return new Page<>(jdbc.query(sql, this::row, queryArgs.toArray()), count, page, size);
    }

    public Optional<CustomerCreditInfo> customerCredit(long clienteId) {
        return jdbc.query("""
            select 
              cli.id_cliente id,
              cli.nombre_razon_social nombre,
              cli.tipo_documento "tipoDocumento",
              cli.nro_documento documento,
              cli.telefono,
              cli.correo,
              cli.direccion,
              cli.limite_credito "limiteCredito",
              (select coalesce(sum(saldo), 0) from huaman.cuenta_por_cobrar where id_cliente=cli.id_cliente and estado='A' and estado_cuenta in ('PENDIENTE','VENCIDA')) "deudaTotal",
              greatest(0, cli.limite_credito - (select coalesce(sum(saldo), 0) from huaman.cuenta_por_cobrar where id_cliente=cli.id_cliente and estado='A' and estado_cuenta in ('PENDIENTE','VENCIDA'))) "creditoDisponible"
            from huaman.cliente cli
            where cli.id_cliente = ? and cli.estado = 'A'
            """, (rs, rowNum) -> new CustomerCreditInfo(
                rs.getLong("id"),
                rs.getString("nombre"),
                rs.getString("tipoDocumento"),
                rs.getString("documento"),
                rs.getString("telefono"),
                rs.getString("correo"),
                rs.getString("direccion"),
                rs.getBigDecimal("limiteCredito"),
                rs.getBigDecimal("deudaTotal"),
                rs.getBigDecimal("creditoDisponible")
            ), clienteId).stream().findFirst();
    }

    public List<Map<String, Object>> customerAccounts(long clienteId) {
        return jdbc.query("""
            select 
              c.id_cuenta id,
              c.id_venta "ventaId",
              v.fecha_venta "fechaVenta",
              coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), 'V-' || v.id_venta) comprobante,
              comp.tipo_comprobante "tipoComprobante",
              c.monto_original "montoOriginal",
              (select coalesce(sum(a.monto),0) from huaman.abono_credito a where a.id_cuenta=c.id_cuenta and a.estado='A') "montoAbonado",
              c.saldo,
              c.fecha_vencimiento "fechaVencimiento",
              case 
                when c.saldo = 0 then 'CANCELADA'
                when c.fecha_vencimiento < timezone('America/Lima', now())::date then 'VENCIDA'
                when c.fecha_vencimiento <= timezone('America/Lima', now())::date + 7 then 'POR_VENCER'
                else 'AL_DIA'
              end situacion,
              case 
                when c.estado_cuenta = 'ANULADA' then 'ANULADA'
                when c.saldo = 0 then 'CANCELADA'
                when c.fecha_vencimiento < timezone('America/Lima', now())::date then 'VENCIDA'
                else 'PENDIENTE'
              end "estadoCuenta",
              coalesce(c.fecmod, c.feccre) version
            from huaman.cuenta_por_cobrar c
            join huaman.venta v on v.id_venta = c.id_venta
            left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta
            where c.id_cliente = ? and c.estado = 'A'
            order by c.saldo > 0 desc, c.fecha_vencimiento asc, c.id_cuenta asc
            """, this::row, clienteId);
    }

    public List<Map<String, Object>> customerPayments(long clienteId) {
        return jdbc.query("""
            select 
              a.id_abono id,
              a.id_cuenta "cuentaId",
              a.fecha_abono fecha,
              a.monto,
              a.medio,
              a.nro_operacion operacion,
              a.marca_tarjeta marca,
              a.ultimos_cuatro "ultimosCuatro",
              a.observacion,
              a.usucre "registradoPor",
              coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), 'V-' || c.id_venta) comprobante
            from huaman.abono_credito a
            join huaman.cuenta_por_cobrar c on c.id_cuenta = a.id_cuenta
            left join huaman.comprobante_venta comp on comp.id_venta = c.id_venta
            where c.id_cliente = ? and a.estado = 'A'
            order by a.fecha_abono desc, a.id_abono desc
            """, this::row, clienteId);
    }

    public Optional<PaymentReceipt> receipt(long abonoId) {
        return jdbc.query("""
            select 
              a.id_abono id,
              a.id_cuenta "cuentaId",
              a.monto,
              a.medio,
              a.nro_operacion operacion,
              a.marca_tarjeta marca,
              a.ultimos_cuatro "ultimosCuatro",
              a.observacion,
              a.fecha_abono fecha,
              a.usucre "registradoPor",
              c.monto_original "montoOriginalCuenta",
              (ev.valor_nuevo->>'saldo_nuevo')::numeric "saldoActualCuenta",
              (ev.valor_nuevo->>'saldo_anterior')::numeric "saldoAnteriorCuenta",
              coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), 'V-' || c.id_venta) comprobante,
              cli.id_cliente "clienteId",
              cli.nombre_razon_social cliente,
              cli.tipo_documento "tipoDocumento",
              cli.nro_documento documento,
              coalesce((select valor from huaman.parametro_sistema where clave='NEGOCIO.NOMBRE_COMERCIAL' and estado='A'), 'Ferretería Huamán') "negocioNombre",
              coalesce((select valor from huaman.parametro_sistema where clave='NEGOCIO.RUC' and estado='A'), '') "negocioRuc",
              coalesce((select valor from huaman.parametro_sistema where clave='NEGOCIO.DIRECCION' and estado='A'), '') "negocioDireccion",
              coalesce((select valor from huaman.parametro_sistema where clave='NEGOCIO.TELEFONO' and estado='A'), '') "negocioTelefono"
            from huaman.abono_credito a
            join huaman.cuenta_por_cobrar c on c.id_cuenta = a.id_cuenta
            join huaman.cliente cli on cli.id_cliente = c.id_cliente
            left join huaman.comprobante_venta comp on comp.id_venta = c.id_venta
            left join lateral (select valor_nuevo from huaman.bitacora_evento where accion='CRE.ABONAR' and entidad='abono_credito' and id_entidad=a.id_abono and referencia=a.clave_idempotencia::text order by id_evento limit 1) ev on true
            where a.id_abono = ? and a.estado = 'A'
            """, (rs, rowNum) -> new PaymentReceipt(
                rs.getLong("id"),
                rs.getLong("cuentaId"),
                rs.getBigDecimal("monto"),
                rs.getString("medio"),
                rs.getString("operacion"),
                rs.getString("marca"),
                rs.getString("ultimosCuatro"),
                rs.getString("observacion"),
                rs.getTimestamp("fecha").toLocalDateTime(),
                rs.getString("registradoPor"),
                rs.getBigDecimal("montoOriginalCuenta"),
                rs.getBigDecimal("saldoActualCuenta"),
                rs.getBigDecimal("saldoAnteriorCuenta"),
                rs.getString("comprobante"),
                rs.getLong("clienteId"),
                rs.getString("cliente"),
                rs.getString("tipoDocumento"),
                rs.getString("documento"),
                rs.getString("negocioNombre"),
                rs.getString("negocioRuc"),
                rs.getString("negocioDireccion"),
                rs.getString("negocioTelefono")
            ), abonoId).stream().findFirst();
    }

    public Optional<Map<String, Object>> getAccount(long id, boolean lock) {
        return jdbc.query("""
            select 
              c.id_cuenta id,
              c.id_venta "ventaId",
              c.id_cliente "clienteId",
              c.monto_original "montoOriginal",
              c.saldo,
              c.fecha_vencimiento "fechaVencimiento",
              c.estado_cuenta "estadoCuenta",
              coalesce(c.fecmod, c.feccre) version
            from huaman.cuenta_por_cobrar c
            where c.id_cuenta = ? and c.estado = 'A'
            """ + (lock ? " for update of c" : ""), this::row, id).stream().findFirst();
    }

    public Optional<Long> replayPayment(long actor, long cuenta, BigDecimal monto, String medio, UUID clave,
                                          String referencia, String marca, String ultimos, String observacion) {
        var rows = jdbc.queryForList("""
            select a.id_abono id, a.id_cuenta=? and a.monto=? and a.medio=?
              and a.nro_operacion is not distinct from ?::text
              and a.marca_tarjeta is not distinct from ?::text
              and a.ultimos_cuatro is not distinct from ?::text
              and a.observacion is not distinct from ?::text
              and exists(select 1 from huaman.bitacora_evento e where e.accion='CRE.ABONAR'
                and e.entidad='abono_credito' and e.id_entidad=a.id_abono and e.id_usuario=?) valid
            from huaman.abono_credito a where a.clave_idempotencia=?
            """, cuenta, monto, medio, referencia, marca, ultimos, observacion, actor, clave);
        if (rows.isEmpty()) return Optional.empty();
        if (!Boolean.TRUE.equals(rows.getFirst().get("valid")))
            throw new com.ferreteriahuaman.security.AuthFailure(409, "Esta clave ya corresponde a otro abono");
        return Optional.of(((Number) rows.getFirst().get("id")).longValue());
    }

    public void lockKey(UUID clave) {
        jdbc.queryForObject("select pg_advisory_xact_lock(hashtextextended(?, 0))", Object.class, "ABONO:" + clave);
    }

    public void lockCash(long id) {
        jdbc.queryForObject("select id_caja from huaman.caja_diaria where id_caja=? for update", Long.class, id);
    }

    public long registerPayment(long cuentaId, long cajaId, BigDecimal monto, String medio, UUID clave,
                                String referencia, String marca, String ultimos, String observacion) {
        return jdbc.queryForObject(
            "select huaman.registrar_abono(?, ?, ?, ?, ?, ?, ?, ?, ?)",
            Long.class,
            cuentaId, cajaId, monto, medio, clave, referencia, marca, ultimos, observacion
        );
    }
}
