package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.DispatchModels.*;
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
public class DispatchRepository {
    private final JdbcTemplate jdbc;

    public DispatchRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final String SELECT_ROW = """
        select 
          d.id_despacho id,
          d.numero,
          d.id_venta "ventaId",
          case when comp.serie is not null then comp.serie || '-' || lpad(comp.numero::text, 8, '0') else null end comprobante,
          v.tipo_comprobante "tipoComprobante",
          coalesce(cli.nombre_razon_social, comp.cliente_nombre, 'CLIENTE VARIOS') "clienteNombre",
          coalesce(cli.nro_documento, comp.cliente_nro_doc, '') "clienteDocumento",
          to_char(v.feccre, 'YYYY-MM-DD HH24:MI:SS') "fechaVenta",
          d.estado_despacho estado,
          (select count(*) from huaman.detalle_venta dv where dv.id_venta = v.id_venta and dv.estado = 'A') "totalItems",
          case when u_prep.id_usuario is not null then concat_ws(' ', u_prep.nombres, u_prep.apellidos) else null end "preparadoPor",
          to_char(d.fecha_preparacion, 'YYYY-MM-DD HH24:MI:SS') "fechaPreparacion",
          d.observacion_preparacion "observacionPreparacion",
          case when u_ent.id_usuario is not null then concat_ws(' ', u_ent.nombres, u_ent.apellidos) else null end "entregadoPor",
          to_char(d.fecha_entrega, 'YYYY-MM-DD HH24:MI:SS') "fechaEntrega",
          d.recibe_nombre "recibeNombre",
          d.observacion_entrega "observacionEntrega",
          to_char(coalesce(d.fecmod, d.feccre), 'YYYY-MM-DD"T"HH24:MI:SS') version
        from huaman.despacho d
        join huaman.venta v on v.id_venta = d.id_venta
        left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A'
        left join huaman.cliente cli on cli.id_cliente = v.id_cliente
        left join huaman.usuario u_prep on u_prep.id_usuario = d.id_prepara
        left join huaman.usuario u_ent on u_ent.id_usuario = d.id_entrega
        where d.estado = 'A'
        """;

    private DispatchRow mapRow(ResultSet rs, int rowNum) throws SQLException {
        long numero = rs.getLong("numero");
        return new DispatchRow(
            rs.getLong("id"),
            numero,
            String.format("DP-%06d", numero),
            rs.getLong("ventaId"),
            rs.getString("comprobante"),
            rs.getString("tipoComprobante"),
            rs.getString("clienteNombre"),
            rs.getString("clienteDocumento"),
            rs.getString("fechaVenta"),
            rs.getString("estado"),
            rs.getInt("totalItems"),
            rs.getString("preparadoPor"),
            rs.getString("fechaPreparacion"),
            rs.getString("observacionPreparacion"),
            rs.getString("entregadoPor"),
            rs.getString("fechaEntrega"),
            rs.getString("recibeNombre"),
            rs.getString("observacionEntrega"),
            rs.getString("version")
        );
    }

    public Summary summary() {
        return jdbc.queryForObject("""
            select 
              coalesce(count(case when d.estado_despacho = 'PENDIENTE' then 1 end), 0) pendientes,
              coalesce(count(case when d.estado_despacho = 'PREPARADO' then 1 end), 0) preparados,
              coalesce(count(case when d.estado_despacho = 'ENTREGADO' and d.fecha_entrega >= (timezone('America/Lima', now())::date - 7) then 1 end), 0) entregados,
              coalesce(count(case when d.estado_despacho = 'ANULADO' then 1 end), 0) anulados
            from huaman.despacho d
            where d.estado = 'A'
            """, (rs, rowNum) -> new Summary(
                rs.getLong("pendientes"),
                rs.getLong("preparados"),
                rs.getLong("entregados"),
                rs.getLong("anulados")
            ));
    }

    public Page<DispatchRow> list(String estado, String q, LocalDate desde, LocalDate hasta, int page, int size) {
        String e = Character.toString(92);
        String pattern = "%" + q.replace(e, e + e).replace("%", e + "%").replace("_", e + "_") + "%";

        StringBuilder where = new StringBuilder("and 1=1 ");
        var args = new ArrayList<Object>();

        if (!q.isBlank()) {
            where.append("and (coalesce(comp.serie || '-' || lpad(comp.numero::text, 8, '0'), '') ilike ? ")
                 .append("or coalesce(cli.nombre_razon_social, comp.cliente_nombre, '') ilike ? ")
                 .append("or coalesce(cli.nro_documento, comp.cliente_nro_doc, '') ilike ? ")
                 .append("or d.numero::text ilike ? ")
                 .append("or coalesce(d.recibe_nombre, '') ilike ?) ");
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
            args.add(pattern);
        }

        if (desde != null) {
            where.append("and d.feccre::date >= ? ");
            args.add(desde);
        }
        if (hasta != null) {
            where.append("and d.feccre::date <= ? ");
            args.add(hasta);
        }

        if (!estado.isBlank() && !estado.equalsIgnoreCase("TODOS")) {
            where.append("and d.estado_despacho = ? ");
            args.add(estado.toUpperCase(Locale.ROOT));
        }

        String countSql = "select count(*) from huaman.despacho d " +
            "join huaman.venta v on v.id_venta = d.id_venta " +
            "left join huaman.comprobante_venta comp on comp.id_venta = v.id_venta and comp.estado = 'A' " +
            "left join huaman.cliente cli on cli.id_cliente = v.id_cliente " +
            "where d.estado = 'A' " + where;

        Long totalLong = jdbc.queryForObject(countSql, Long.class, args.toArray());
        long total = totalLong == null ? 0 : totalLong;

        String order;
        if ("PENDIENTE".equalsIgnoreCase(estado)) {
            order = " order by d.id_despacho asc ";
        } else if ("PREPARADO".equalsIgnoreCase(estado)) {
            order = " order by d.fecha_preparacion asc ";
        } else if ("ENTREGADO".equalsIgnoreCase(estado)) {
            order = " order by d.fecha_entrega desc ";
        } else {
            order = " order by d.id_despacho desc ";
        }

        String dataSql = SELECT_ROW + where + order + " limit ? offset ?";
        var dataArgs = new ArrayList<>(args);
        dataArgs.add(size);
        dataArgs.add(page * size);

        List<DispatchRow> rows = jdbc.query(dataSql, this::mapRow, dataArgs.toArray());
        return new Page<>(rows, total, page, size);
    }

    public Optional<DispatchRow> findById(long idDespacho) {
        return jdbc.query(SELECT_ROW + " and d.id_despacho = ?", this::mapRow, idDespacho).stream().findFirst();
    }

    public Optional<DispatchDetail> getDetail(long idDespacho) {
        var rowOpt = findById(idDespacho);
        if (rowOpt.isEmpty()) return Optional.empty();
        var row = rowOpt.get();

        var saleInfo = jdbc.queryForMap("""
            select 
              concat_ws(' ', u.nombres, u.apellidos) vendedor,
              v.total "totalVenta",
              null::text "observacionVenta"
            from huaman.venta v
            left join huaman.usuario u on u.id_usuario = v.id_vendedor
            where v.id_venta = ?
            """, row.ventaId());

        List<DispatchItem> items = jdbc.query("""
            select 
              dv.id_detalle_venta id,
              dv.id_producto "productoId",
              p.codigo "codigoProducto",
              dv.producto_nombre "productoNombre",
              dv.presentacion_nombre "presentacionNombre",
              dv.unidad_base_simbolo "unidadBase",
              dv.cantidad,
              dv.factor_base "factorBase",
              dv.cantidad_base "cantidadBase",
              p.ubicacion,
              p.modo_control "modoControl"
            from huaman.detalle_venta dv
            join huaman.producto p on p.id_producto = dv.id_producto
            where dv.id_venta = ? and dv.estado = 'A'
            order by dv.id_detalle_venta asc
            """, (rs, i) -> new DispatchItem(
                rs.getLong("id"),
                rs.getLong("productoId"),
                rs.getString("codigoProducto"),
                rs.getString("productoNombre"),
                rs.getString("presentacionNombre"),
                rs.getString("unidadBase"),
                rs.getBigDecimal("cantidad"),
                rs.getBigDecimal("factorBase"),
                rs.getBigDecimal("cantidadBase"),
                rs.getString("ubicacion"),
                rs.getString("modoControl")
            ), row.ventaId());

        return Optional.of(new DispatchDetail(
            row,
            items,
            (String) saleInfo.get("vendedor"),
            (BigDecimal) saleInfo.get("totalVenta"),
            (String) saleInfo.get("observacionVenta")
        ));
    }

    public long prepararDespacho(long idDespacho, UUID clave, String observacion) {
        return jdbc.queryForObject(
            "select huaman.preparar_despacho(?, ?, ?)",
            Long.class,
            idDespacho, clave, observacion
        );
    }

    public long entregarDespacho(long idDespacho, UUID clave, String recibe, String observacion) {
        return jdbc.queryForObject(
            "select huaman.entregar_despacho(?, ?, ?, ?)",
            Long.class,
            idDespacho, clave, recibe, observacion
        );
    }
}
