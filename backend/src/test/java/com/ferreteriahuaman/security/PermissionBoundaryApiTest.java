package com.ferreteriahuaman.security;

import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.nio.file.*;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Route-level authorization only. Actual controllers are registered; the probe runs
 * AFTER the real security filters and handler mapping, BEFORE any business method.
 * Existing service/database tests cover ownership, roles, costs and business rules.
 */
@WebMvcTest
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class, SecurityConfig.class, PermissionBoundaryApiTest.ProbeConfig.class})
class PermissionBoundaryApiTest {
    @Autowired MockMvc mvc;
    @Autowired RequestMappingHandlerMapping mappings;
    @MockBean AuthService auth;
    @MockBean BrandService brand;
    @MockBean DecolectaService decolecta;
    @MockBean ProductImageService productImages;
    @MockBean AuditService audit;
    @MockBean CashService cash;
    @MockBean CatalogService catalog;
    @MockBean CreditService credit;
    @MockBean CustomerService customer;
    @MockBean DispatchService dispatch;
    @MockBean InventoryService inventory;
    @MockBean OfferService offer;
    @MockBean ProductService product;
    @MockBean PurchaseService purchase;
    @MockBean QuoteService quote;
    @MockBean ReportService report;
    @MockBean ReturnService returns;
    @MockBean RolePermissionService roles;
    @MockBean SaleHistoryService history;
    @MockBean SaleService sales;
    @MockBean PosCustomerService posCustomers;
    @MockBean SettingsService settings;
    @MockBean UserAdminService users;
    @MockBean XmlTrialService xml;

    @TestConfiguration(proxyBeanMethods=false)
    static class ProbeConfig implements WebMvcConfigurer {
        @Override public void addInterceptors(InterceptorRegistry registry) {
            registry.addInterceptor(new HandlerInterceptor() {
                @Override public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
                    if (!(handler instanceof HandlerMethod)) throw new AssertionError("La prueba no encontró un controlador real");
                    response.setHeader("X-Authorization-Probe", "reached-controller");
                    response.setStatus(204);
                    return false;
                }
            }).addPathPatterns("/api/**");
        }
    }

    private record Endpoint(HttpMethod method, String path) { @Override public String toString() { return method + " " + path; } }
    private List<Endpoint> endpoints() {
        var result = new ArrayList<Endpoint>();
        mappings.getHandlerMethods().forEach((mapping, handler) -> {
            for (String pattern : mapping.getPatternValues()) {
                if (!pattern.startsWith("/api/") || pattern.startsWith("/api/auth/")) continue;
                var paths = List.of(pattern);
                if (pattern.contains("/compras/{tipo}")) paths = List.of(pattern.replace("{tipo}", "ordenes"), pattern.replace("{tipo}", "ingresos"));
                if (pattern.contains("/reportes/{tipo}")) paths = Stream.of("ventas", "productos", "inventario", "caja", "dashboard").map(type -> pattern.replace("{tipo}", type)).toList();
                for (var method : mapping.getMethodsCondition().getMethods()) for (String path : paths) {
                    if(method.name().equals("GET")&&path.startsWith("/api/identidad-visual"))continue;
                    // Dashboard has no CSV endpoint by design, despite sharing the generic mapping.
                    if (path.endsWith("/dashboard/csv")) continue;
                    result.add(new Endpoint(HttpMethod.valueOf(method.name()), path.replaceAll("\\{[^}]+}", "1")));
                }
            }
        });
        return result.stream().distinct().sorted(Comparator.comparing(Endpoint::toString)).toList();
    }
    private Set<String> seedPermissions() throws Exception {
        var directory = Path.of(System.getProperty("basedir", "."), "..", "supabase", "migrations");
        // Read only declared permission rows, including later migrations. SQL
        // string literals can contain semicolons, so a simple split is unsafe.
        var inserts = Pattern.compile("(?is)INSERT\\s+INTO\\s+(?:huaman\\.)?permiso\\s*\\([^)]*\\)\\s*VALUES\\s+");
        var code = Pattern.compile("\\(\\s*'([A-Z]+\\.[A-Z_]+)'\\s*,");
        var result = new HashSet<String>();
        try (var files = Files.list(directory)) {
            for (var file : files.filter(p -> p.toString().endsWith(".sql")).toList()) {
                String sql = Files.readString(file);
                var statements = inserts.matcher(sql);
                while (statements.find()) {
                    int end = statements.end(); boolean quoted = false;
                    for (; end < sql.length(); end++) {
                        char character = sql.charAt(end);
                        if (character == '\'') {
                            if (quoted && end + 1 < sql.length() && sql.charAt(end + 1) == '\'') end++;
                            else quoted = !quoted;
                        } else if (character == ';' && !quoted) break;
                    }
                    var values = code.matcher(sql.substring(statements.end(), end));
                    while (values.find()) result.add(values.group(1));
                }
            }
        }
        assertThat(result).hasSizeGreaterThanOrEqualTo(58).contains("INV.APERTURA", "PRO.COSTOS");
        return result;
    }
    private void identity(String role, boolean temporary, Set<String> permissions) {
        when(auth.authenticate(anyString(), anyString())).thenReturn(new Identity(1, "route.test", "Prueba", "Local", role,
            temporary, permissions, UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30)));
    }
    private void check(Endpoint endpoint, boolean authenticated, boolean allowed) throws Exception {
        var request = request(endpoint.method(), endpoint.path());
        if (authenticated) request.header("Authorization", "Bearer local-route-test");
        var assertion = mvc.perform(request);
        if (allowed) assertion.andExpect(result -> assertThat(result.getResponse().getStatus()).as(endpoint.toString()).isEqualTo(204)).andExpect(header().string("X-Authorization-Probe", "reached-controller"));
        else assertion.andExpect(status().is(authenticated ? 403 : 401)).andExpect(header().doesNotExist("X-Authorization-Probe"));
        verifyNoInteractions(brand,audit, cash, catalog, credit, customer, dispatch, inventory, offer, product,
            purchase, quote, report, returns, roles, history, sales, settings, users, xml);
    }

    @TestFactory Stream<DynamicTest> everyRegisteredBusinessRouteEnforcesAuthenticationAndPermission() throws Exception {
        var all = seedPermissions(); var endpoints = endpoints();
        assertThat(endpoints.size()).isGreaterThan(100);
        return endpoints.stream().flatMap(endpoint -> Stream.of(
            DynamicTest.dynamicTest("Sin sesión: " + endpoint, () -> check(endpoint, false, false)),
            DynamicTest.dynamicTest("ADM sin permisos: " + endpoint, () -> { identity("ADM", false, Set.of()); check(endpoint, true, false); }),
            DynamicTest.dynamicTest("Contraseña temporal: " + endpoint, () -> { identity("ADM", true, Set.of("SEG.PERFIL")); check(endpoint, true, false); }),
            DynamicTest.dynamicTest("Permisos completos: " + endpoint, () -> { identity("ADM", false, all); check(endpoint, true, true); })
        ));
    }

    // Representative permission bundles: role names alone never grant authority.
    @TestFactory Stream<DynamicTest> operationalProfilesCannotCrossModuleBoundaries() {
        record Case(String role, Set<String> permissions, HttpMethod method, String path, boolean allowed) {}
        var ven = Set.of("SEG.PERFIL", "PRO.VER", "VEN.VENDER", "CAJ.OPERAR", "DES.VER", "CRE.VER", "CRE.ABONAR", "CLI.VER");
        var alm = Set.of("SEG.PERFIL", "PRO.VER", "INV.VER", "COM.INGRESO", "DES.VER", "DES.GESTIONAR", "REP.INVENTARIO", "REP.EXPORTAR");
        var ayu = Set.of("SEG.PERFIL", "PRO.VER", "INV.VER", "INV.TOMA_CONTAR", "DES.VER", "DES.GESTIONAR");
        return Stream.of(
            new Case("VEN", ven, HttpMethod.GET, "/api/ventas/opciones", true),
            new Case("VEN", ven, HttpMethod.GET, "/api/caja/actual", true),
            new Case("VEN", ven, HttpMethod.POST, "/api/creditos/abonos", true),
            new Case("VEN", ven, HttpMethod.POST, "/api/despachos/1/entregar", false),
            new Case("VEN", ven, HttpMethod.GET, "/api/reportes/dashboard", false),
            new Case("VEN", ven, HttpMethod.GET, "/api/usuarios", false),
            new Case("VEN", ven, HttpMethod.PUT, "/api/roles/2/permisos", false),
            new Case("VEN", ven, HttpMethod.POST, "/api/inventario/ajustes", false),
            new Case("ALM", alm, HttpMethod.GET, "/api/compras/ingresos", true),
            new Case("ALM", alm, HttpMethod.POST, "/api/despachos/1/preparar", true),
            new Case("ALM", alm, HttpMethod.GET, "/api/reportes/inventario", true),
            new Case("ALM", alm, HttpMethod.POST, "/api/ventas/borradores", false),
            new Case("ALM", alm, HttpMethod.POST, "/api/caja/abrir", false),
            new Case("ALM", alm, HttpMethod.POST, "/api/creditos/abonos", false),
            new Case("ALM", alm, HttpMethod.GET, "/api/bitacora", false),
            new Case("AYU", ayu, HttpMethod.POST, "/api/inventario/tomas/1/conteos", true),
            new Case("AYU", ayu, HttpMethod.POST, "/api/despachos/1/entregar", true),
            new Case("AYU", ayu, HttpMethod.POST, "/api/inventario/tomas/1/acciones/aprobar", false),
            new Case("AYU", ayu, HttpMethod.POST, "/api/productos", false),
            new Case("AYU", ayu, HttpMethod.GET, "/api/proveedores", false),
            new Case("AYU", ayu, HttpMethod.GET, "/api/clientes", false)
        ).map(c -> DynamicTest.dynamicTest(c.role() + " " + c.method() + " " + c.path(), () -> {
            identity(c.role(), false, c.permissions()); check(new Endpoint(c.method(), c.path()), true, c.allowed());
        }));
    }

    @Test void unregisteredRoutesAndPhysicalDeletionAreDeniedEvenWithAllPermissions() throws Exception {
        identity("ADM", false, seedPermissions());
        check(new Endpoint(HttpMethod.GET, "/api/control-no-registrado"), true, false);
        check(new Endpoint(HttpMethod.DELETE, "/api/productos/1"), true, false);
        check(new Endpoint(HttpMethod.DELETE, "/api/ventas/1"), true, false);
    }
    @Test void expiredSessionCannotReachBusinessControllers() throws Exception {
        when(auth.authenticate(anyString(), anyString())).thenThrow(AuthFailure.expired());
        var endpoint = new Endpoint(HttpMethod.GET, "/api/productos");
        mvc.perform(get(endpoint.path()).header("Authorization", "Bearer expired"))
            .andExpect(status().isUnauthorized()).andExpect(header().doesNotExist("X-Authorization-Probe"));
        verifyNoInteractions(product);
    }
    @Test void onlyBrandReadRoutesArePublic() throws Exception {
        check(new Endpoint(HttpMethod.GET,"/api/identidad-visual"),false,true);
        check(new Endpoint(HttpMethod.GET,"/api/identidad-visual/logo/"+"a".repeat(64)),false,true);
        check(new Endpoint(HttpMethod.PUT,"/api/identidad-visual"),false,false);
    }
}
