package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.OfferModels.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("db")
public class OfferRepository {
    private final JdbcTemplate jdbc;

    public OfferRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final String BASE_SELECT = """
        SELECT o.id_oferta, o.nombre, o.id_producto, p.codigo AS codigo_producto, p.nombre AS nombre_producto,
               p.id_categoria, c.nombre AS categoria_nombre,
               o.id_presentacion, pp.nombre AS presentacion_nombre, u.abreviatura AS unidad_base,
               pp.precio_normal AS precio_regular, o.precio_oferta,
               (coalesce(p.costo_promedio, p.ultimo_costo_compra, 0) * pp.factor_base) AS costo_referencial,
               o.fecha_inicio, o.fecha_fin, o.estado AS estado_logico,
               timezone('America/Lima', now())::date AS hoy,
               coalesce(o.fecmod, o.feccre) AS version
        FROM huaman.oferta o
        JOIN huaman.producto p ON p.id_producto = o.id_producto
        JOIN huaman.categoria c ON c.id_categoria = p.id_categoria
        JOIN huaman.presentacion_producto pp ON pp.id_producto = o.id_producto AND pp.id_presentacion = o.id_presentacion
        JOIN huaman.unidad_medida u ON u.id_unidad = p.id_unidad
        """;

    private String decimal(ResultSet r, String col) throws SQLException {
        var v = r.getBigDecimal(col);
        return v == null ? "0.00" : v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private OfferRow mapOfferRow(ResultSet r, int rowNum) throws SQLException {
        LocalDate hoy = r.getObject("hoy", LocalDate.class);
        LocalDate inicio = r.getObject("fecha_inicio", LocalDate.class);
        LocalDate fin = r.getObject("fecha_fin", LocalDate.class);
        String estadoLogico = r.getString("estado_logico");

        String estadoOperativo;
        if ("I".equals(estadoLogico)) {
            estadoOperativo = "INACTIVA";
        } else if (inicio.isAfter(hoy)) {
            estadoOperativo = "PROGRAMADA";
        } else if (hoy.isAfter(fin)) {
            estadoOperativo = "VENCIDA";
        } else {
            estadoOperativo = "VIGENTE";
        }

        BigDecimal regular = r.getBigDecimal("precio_regular");
        BigDecimal oferta = r.getBigDecimal("precio_oferta");
        String descuentoPorcentaje = "0.00";
        if (regular != null && regular.signum() > 0 && oferta != null) {
            BigDecimal diff = regular.subtract(oferta);
            if (diff.signum() > 0) {
                descuentoPorcentaje = diff.multiply(BigDecimal.valueOf(100))
                    .divide(regular, 2, RoundingMode.HALF_UP)
                    .toPlainString();
            }
        }

        return new OfferRow(
            r.getLong("id_oferta"),
            r.getString("nombre"),
            r.getLong("id_producto"),
            r.getString("codigo_producto"),
            r.getString("nombre_producto"),
            r.getLong("id_categoria"),
            r.getString("categoria_nombre"),
            r.getLong("id_presentacion"),
            r.getString("presentacion_nombre"),
            r.getString("unidad_base"),
            decimal(r, "precio_regular"),
            decimal(r, "precio_oferta"),
            descuentoPorcentaje,
            decimal(r, "costo_referencial"),
            inicio,
            fin,
            estadoLogico,
            estadoOperativo,
            r.getObject("version", LocalDateTime.class)
        );
    }

    public OfferSummary summary() {
        String sql = """
            SELECT
              count(*) FILTER (WHERE o.estado = 'A' AND timezone('America/Lima', now())::date BETWEEN o.fecha_inicio AND o.fecha_fin) AS vigentes,
              count(*) FILTER (WHERE o.estado = 'A' AND o.fecha_inicio > timezone('America/Lima', now())::date) AS programadas,
              count(*) FILTER (WHERE o.estado = 'A' AND o.fecha_fin < timezone('America/Lima', now())::date) AS vencidas,
              count(*) FILTER (WHERE o.estado = 'I') AS inactivas
            FROM huaman.oferta o
            """;
        return jdbc.queryForObject(sql, (r, n) -> new OfferSummary(
            r.getLong("vigentes"),
            r.getLong("programadas"),
            r.getLong("vencidas"),
            r.getLong("inactivas")
        ));
    }

    public OfferListResponse list(String search, String estado, Long categoriaId, int page, int size) {
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();

        if (search != null && !search.isBlank()) {
            String esc = Character.toString(92);
            String q = "%" + search.trim().replace(esc, esc + esc).replace("%", esc + "%").replace("_", esc + "_") + "%";
            where.append(" AND (p.nombre ILIKE ? OR p.codigo ILIKE ? OR o.nombre ILIKE ? OR pp.nombre ILIKE ?) ");
            args.add(q);
            args.add(q);
            args.add(q);
            args.add(q);
        }

        if (categoriaId != null && categoriaId > 0) {
            where.append(" AND p.id_categoria = ? ");
            args.add(categoriaId);
        }

        if (estado != null && !estado.isBlank()) {
            switch (estado.toUpperCase()) {
                case "VIGENTE" -> where.append(" AND o.estado = 'A' AND timezone('America/Lima', now())::date BETWEEN o.fecha_inicio AND o.fecha_fin ");
                case "PROGRAMADA" -> where.append(" AND o.estado = 'A' AND o.fecha_inicio > timezone('America/Lima', now())::date ");
                case "VENCIDA" -> where.append(" AND o.estado = 'A' AND o.fecha_fin < timezone('America/Lima', now())::date ");
                case "INACTIVA" -> where.append(" AND o.estado = 'I' ");
                case "VIGENTES_PROGRAMADAS" -> where.append(" AND o.estado = 'A' AND o.fecha_fin >= timezone('America/Lima', now())::date ");
                default -> { /* TODAS - no extra filter */ }
            }
        }

        long total = Objects.requireNonNull(
            jdbc.queryForObject("SELECT count(*) FROM huaman.oferta o JOIN huaman.producto p ON p.id_producto = o.id_producto JOIN huaman.presentacion_producto pp ON pp.id_producto = o.id_producto AND pp.id_presentacion = o.id_presentacion " + where, Long.class, args.toArray())
        );

        String orderBy = """
            ORDER BY (
              CASE
                WHEN o.estado = 'A' AND timezone('America/Lima', now())::date BETWEEN o.fecha_inicio AND o.fecha_fin THEN 1
                WHEN o.estado = 'A' AND o.fecha_inicio > timezone('America/Lima', now())::date THEN 2
                WHEN o.estado = 'A' THEN 3
                ELSE 4
              END
            ), o.fecha_inicio DESC, o.id_oferta DESC LIMIT ? OFFSET ?
            """;

        List<Object> queryArgs = new ArrayList<>(args);
        queryArgs.add(size);
        queryArgs.add((long) page * size);

        List<OfferRow> items = jdbc.query(BASE_SELECT + where + orderBy, this::mapOfferRow, queryArgs.toArray());
        return new OfferListResponse(items, total, page, size);
    }

    public Optional<OfferRow> get(long id, boolean lock) {
        String sql = BASE_SELECT + " WHERE o.id_oferta = ? " + (lock ? " FOR UPDATE OF o " : "");
        return jdbc.query(sql, this::mapOfferRow, id).stream().findFirst();
    }

    public List<ProductPresentationOption> searchAvailableProducts(String search) {
        String esc = Character.toString(92);
        String q = search == null || search.isBlank() ? "%" : "%" + search.trim().replace(esc, esc + esc).replace("%", esc + "%").replace("_", esc + "_") + "%";
        String sql = """
            SELECT p.id_producto, p.codigo, p.nombre AS producto_nombre,
                   pp.id_presentacion, pp.nombre AS presentacion_nombre,
                   u.abreviatura AS unidad_base,
                   pp.precio_normal,
                   (coalesce(p.costo_promedio, p.ultimo_costo_compra, 0) * pp.factor_base) AS costo_referencial,
                   pp.permite_venta
            FROM huaman.presentacion_producto pp
            JOIN huaman.producto p ON p.id_producto = pp.id_producto
            JOIN huaman.unidad_medida u ON u.id_unidad = p.id_unidad
            WHERE p.estado = 'A' AND pp.estado = 'A' AND pp.permite_venta = true
              AND (? = '%' OR p.nombre ILIKE ? OR p.codigo ILIKE ? OR pp.nombre ILIKE ?)
            ORDER BY lower(p.nombre), lower(pp.nombre)
            LIMIT 50
            """;
        return jdbc.query(sql, (r, n) -> new ProductPresentationOption(
            r.getLong("id_producto"),
            r.getString("codigo"),
            r.getString("producto_nombre"),
            r.getLong("id_presentacion"),
            r.getString("presentacion_nombre"),
            r.getString("unidad_base"),
            decimal(r, "precio_normal"),
            decimal(r, "costo_referencial"),
            r.getBoolean("permite_venta")
        ), q, q, q, q);
    }

    public record PresentationPricing(
        long productoId,
        long presentacionId,
        BigDecimal precioNormal,
        boolean permiteVenta,
        String estadoPresentacion,
        String estadoProducto,
        BigDecimal costo
    ) {}

    public Optional<PresentationPricing> getPresentationPricing(long presentacionId) {
        jdbc.queryForList("select p.id_producto from huaman.producto p join huaman.presentacion_producto pp on pp.id_producto=p.id_producto where pp.id_presentacion=? for update of p", presentacionId);
        jdbc.queryForList("select id_presentacion from huaman.presentacion_producto where id_presentacion=? for update", presentacionId);
        String sql = """
            SELECT pp.id_producto, pp.id_presentacion, pp.precio_normal, pp.permite_venta,
                   pp.estado AS estado_presentacion, p.estado AS estado_producto,
                   (coalesce(p.costo_promedio, p.ultimo_costo_compra, 0) * pp.factor_base) AS costo
            FROM huaman.presentacion_producto pp
            JOIN huaman.producto p ON p.id_producto = pp.id_producto
            WHERE pp.id_presentacion = ?
            """;
        return jdbc.query(sql, (r, n) -> new PresentationPricing(
            r.getLong("id_producto"),
            r.getLong("id_presentacion"),
            r.getBigDecimal("precio_normal"),
            r.getBoolean("permite_venta"),
            r.getString("estado_presentacion"),
            r.getString("estado_producto"),
            r.getBigDecimal("costo")
        ), presentacionId).stream().findFirst();
    }

    public boolean hasOverlap(long presentacionId, Long excludeId, LocalDate inicio, LocalDate fin) {
        String sql = """
            SELECT EXISTS(
              SELECT 1 FROM huaman.oferta
              WHERE id_presentacion = ?
                AND estado = 'A'
                AND (?::bigint IS NULL OR id_oferta <> ?)
                AND daterange(fecha_inicio, fecha_fin, '[]') && daterange(?, ?, '[]')
            )
            """;
        return Boolean.TRUE.equals(jdbc.queryForObject(sql, Boolean.class, presentacionId, excludeId, excludeId, inicio, fin));
    }

    public long create(long productoId, long presentacionId, String nombre, BigDecimal precioOferta, LocalDate fechaInicio, LocalDate fechaFin) {
        String sql = """
            INSERT INTO huaman.oferta(id_producto, id_presentacion, nombre, precio_oferta, fecha_inicio, fecha_fin)
            VALUES (?, ?, ?, ?, ?, ?) RETURNING id_oferta
            """;
        return Objects.requireNonNull(jdbc.queryForObject(sql, Long.class, productoId, presentacionId, nombre.trim(), precioOferta, fechaInicio, fechaFin));
    }

    public void update(long id, String nombre, BigDecimal precioOferta, LocalDate fechaInicio, LocalDate fechaFin) {
        String sql = """
            UPDATE huaman.oferta
            SET nombre = ?, precio_oferta = ?, fecha_inicio = ?, fecha_fin = ?
            WHERE id_oferta = ?
            """;
        jdbc.update(sql, nombre.trim(), precioOferta, fechaInicio, fechaFin, id);
    }

    public void state(long id, String estado) {
        String sql = "UPDATE huaman.oferta SET estado = ? WHERE id_oferta = ?";
        jdbc.update(sql, estado, id);
    }
}
