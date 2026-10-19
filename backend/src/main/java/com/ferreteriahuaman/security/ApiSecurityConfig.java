package com.ferreteriahuaman.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.service.AuthService;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.*;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

@Configuration
@Profile("db")
public class ApiSecurityConfig {
    @Bean @Order(1)
    SecurityFilterChain apiSecurity(HttpSecurity http,AuthService service,ObjectMapper mapper,
        @Qualifier("corsConfigurationSource") CorsConfigurationSource cors)throws Exception{
        return http.securityMatcher("/api/**").cors(c->c.configurationSource(cors))
            .csrf(AbstractHttpConfigurer::disable).httpBasic(AbstractHttpConfigurer::disable)
            .formLogin(AbstractHttpConfigurer::disable).logout(AbstractHttpConfigurer::disable)
            .requestCache(AbstractHttpConfigurer::disable)
            .sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .addFilterBefore(new BearerSessionFilter(service,mapper),UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(e->e.authenticationEntryPoint((q,r,x)->AuthProblems.write(r,mapper,401,"Inicia sesión para continuar"))
                .accessDeniedHandler((q,r,x)->AuthProblems.write(r,mapper,403,"No tienes permiso para realizar esta acción")))
            .authorizeHttpRequests(a->a.requestMatchers(HttpMethod.POST,"/api/auth/login").permitAll()
                .requestMatchers(HttpMethod.GET,"/api/auth/me").authenticated()
                .requestMatchers(HttpMethod.POST,"/api/auth/logout","/api/auth/continuar").authenticated()
                .requestMatchers(HttpMethod.PUT,"/api/auth/clave").hasAuthority("SEG.PERFIL")
                .requestMatchers(HttpMethod.GET,"/api/creditos","/api/creditos/**").hasAuthority("CRE.VER")
                .requestMatchers(HttpMethod.POST,"/api/creditos/abonos").hasAuthority("CRE.ABONAR")
                .requestMatchers(HttpMethod.GET,"/api/despachos","/api/despachos/**").hasAuthority("DES.VER")
                .requestMatchers(HttpMethod.POST,"/api/despachos/*/preparar","/api/despachos/*/entregar").hasAuthority("DES.GESTIONAR")
                .requestMatchers(HttpMethod.GET,"/api/devoluciones","/api/devoluciones/**").hasAuthority("VEN.DEVOLVER")
                .requestMatchers(HttpMethod.POST,"/api/devoluciones/solicitar","/api/devoluciones/*/aprobar","/api/devoluciones/*/rechazar").hasAuthority("VEN.DEVOLVER")
                .requestMatchers(HttpMethod.GET,"/api/cotizaciones","/api/cotizaciones/opciones","/api/cotizaciones/*").hasAuthority("COC.COTIZAR")
                .requestMatchers(HttpMethod.POST,"/api/cotizaciones","/api/cotizaciones/*/acciones/*","/api/cotizaciones/*/convertir").hasAuthority("COC.COTIZAR")
                .requestMatchers(HttpMethod.PUT,"/api/cotizaciones/*").hasAuthority("COC.COTIZAR")
                .requestMatchers(HttpMethod.GET,"/api/ofertas","/api/ofertas/**").hasAuthority("COC.OFERTAS")
                .requestMatchers(HttpMethod.POST,"/api/ofertas","/api/ofertas/**").hasAuthority("COC.OFERTAS")
                .requestMatchers(HttpMethod.PUT,"/api/ofertas/**").hasAuthority("COC.OFERTAS")
                .requestMatchers(HttpMethod.PATCH,"/api/ofertas/**").hasAuthority("COC.OFERTAS")
                .requestMatchers(HttpMethod.GET,"/api/historial-ventas","/api/historial-ventas/*").hasAuthority("VEN.HISTORIAL")
                .requestMatchers(HttpMethod.POST,"/api/historial-ventas/*/reimpresion").hasAuthority("VEN.REIMPRIMIR")
                .requestMatchers(HttpMethod.POST,"/api/historial-ventas/*/copia").hasAuthority("VEN.COPIAR")
                .requestMatchers(HttpMethod.POST,"/api/historial-ventas/*/anulacion").hasAuthority("VEN.ANULAR")
                .requestMatchers(HttpMethod.GET,"/api/ventas/opciones","/api/ventas/borradores","/api/ventas/*","/api/ventas/*/existencias").hasAuthority("VEN.VENDER")
                .requestMatchers(HttpMethod.POST,"/api/ventas/borradores","/api/ventas/*/confirmar","/api/ventas/*/descartar").hasAuthority("VEN.VENDER")
                .requestMatchers(HttpMethod.GET,"/api/caja/actual","/api/caja/actual/movimientos").hasAuthority("CAJ.OPERAR")
                .requestMatchers(HttpMethod.GET,"/api/caja/historial","/api/caja/historial/*","/api/caja/historial/*/movimientos").hasAuthority("CAJ.HISTORIAL")
                .requestMatchers(HttpMethod.POST,"/api/caja/abrir","/api/caja/*/movimientos","/api/caja/*/cerrar").hasAuthority("CAJ.OPERAR")
                .requestMatchers(HttpMethod.GET,"/api/clientes","/api/clientes/*").hasAnyAuthority("CLI.VER","CLI.GESTIONAR","CLI.CREDITO")
                .requestMatchers(HttpMethod.POST,"/api/clientes").hasAuthority("CLI.GESTIONAR")
                .requestMatchers(HttpMethod.PUT,"/api/clientes/*").hasAuthority("CLI.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/clientes/*/estado").hasAuthority("CLI.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/clientes/*/credito").hasAuthority("CLI.CREDITO")
                .requestMatchers(HttpMethod.GET,"/api/proveedores","/api/proveedores/*").hasAnyAuthority("PRV.GESTIONAR","COM.OC","COM.INGRESO")
                .requestMatchers(HttpMethod.POST,"/api/proveedores").hasAuthority("PRV.GESTIONAR")
                .requestMatchers(HttpMethod.PUT,"/api/proveedores/*").hasAuthority("PRV.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/proveedores/*/estado").hasAuthority("PRV.GESTIONAR")
                .requestMatchers(HttpMethod.POST,"/api/compras/ordenes/*/anular").hasAuthority("COM.OC_ANULAR")
                .requestMatchers(HttpMethod.GET,"/api/compras/ordenes","/api/compras/ordenes/**").hasAnyAuthority("COM.OC","COM.INGRESO")
                .requestMatchers(HttpMethod.POST,"/api/compras/ordenes","/api/compras/ordenes/**").hasAuthority("COM.OC")
                .requestMatchers(HttpMethod.PUT,"/api/compras/ordenes/**").hasAuthority("COM.OC")
                .requestMatchers(HttpMethod.PATCH,"/api/compras/ordenes/**").hasAuthority("COM.OC")
                .requestMatchers(HttpMethod.GET,"/api/compras/ingresos","/api/compras/ingresos/**").hasAuthority("COM.INGRESO")
                .requestMatchers(HttpMethod.POST,"/api/compras/ingresos","/api/compras/ingresos/**").hasAuthority("COM.INGRESO")
                .requestMatchers(HttpMethod.PUT,"/api/compras/ingresos/**").hasAuthority("COM.INGRESO")
                .requestMatchers(HttpMethod.PATCH,"/api/compras/ingresos/**").hasAuthority("COM.INGRESO")
                .requestMatchers(HttpMethod.GET,"/api/inventario/alertas").hasAuthority("INV.ALERTAS")
                .requestMatchers(HttpMethod.GET,"/api/inventario/ajustes","/api/inventario/motivos").hasAuthority("INV.AJUSTAR")
                .requestMatchers(HttpMethod.POST,"/api/inventario/ajustes").hasAuthority("INV.AJUSTAR")
                .requestMatchers(HttpMethod.POST,"/api/inventario/transformaciones").hasAuthority("INV.TRANSFORMAR")
                .requestMatchers(HttpMethod.GET,"/api/inventario/tomas","/api/inventario/tomas/*","/api/inventario/tomas/*/lineas").hasAnyAuthority("INV.TOMA_GESTIONAR","INV.TOMA_CONTAR")
                .requestMatchers(HttpMethod.POST,"/api/inventario/tomas","/api/inventario/tomas/*/acciones/*").hasAuthority("INV.TOMA_GESTIONAR")
                .requestMatchers(HttpMethod.POST,"/api/inventario/tomas/*/conteos").hasAuthority("INV.TOMA_CONTAR")
                .requestMatchers(HttpMethod.POST,"/api/inventario/apertura").hasAuthority("INV.APERTURA")
                .requestMatchers(HttpMethod.GET,"/api/inventario/*/movimientos","/api/inventario/*/existencias").hasAnyAuthority("INV.VER","INV.APERTURA","INV.TRANSFORMAR","INV.AJUSTAR","INV.TOMA_GESTIONAR","INV.TOMA_CONTAR")
                .requestMatchers(HttpMethod.GET,"/api/productos","/api/productos/*").hasAnyAuthority("PRO.VER","PRO.GESTIONAR","PRO.PRESENTACIONES","PRO.MAYORISTA","PRO.MEDIDAS","COM.OC","COM.INGRESO","INV.VER","INV.APERTURA","INV.TRANSFORMAR","INV.AJUSTAR","INV.TOMA_GESTIONAR","INV.TOMA_CONTAR")
                .requestMatchers(HttpMethod.POST,"/api/productos").hasAuthority("PRO.GESTIONAR")
                .requestMatchers(HttpMethod.PUT,"/api/productos/*").hasAuthority("PRO.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/productos/*/estado").hasAuthority("PRO.INACTIVAR")
                .requestMatchers(HttpMethod.POST,"/api/productos/*/presentaciones/*/mayoristas").hasAuthority("PRO.MAYORISTA")
                .requestMatchers(HttpMethod.PUT,"/api/productos/*/presentaciones/*/mayoristas/*").hasAuthority("PRO.MAYORISTA")
                .requestMatchers(HttpMethod.PATCH,"/api/productos/*/mayoristas/*/estado").hasAuthority("PRO.MAYORISTA")
                .requestMatchers(HttpMethod.POST,"/api/productos/*/presentaciones","/api/productos/*/presentaciones/*/codigos").hasAuthority("PRO.PRESENTACIONES")
                .requestMatchers(HttpMethod.PUT,"/api/productos/*/presentaciones/*").hasAuthority("PRO.PRESENTACIONES")
                .requestMatchers(HttpMethod.PATCH,"/api/productos/*/presentaciones/*/estado","/api/productos/*/codigos/*/estado").hasAuthority("PRO.PRESENTACIONES")
                .requestMatchers(HttpMethod.GET,"/api/catalogos/categorias","/api/catalogos/categorias/*","/api/catalogos/unidades","/api/catalogos/unidades/*").hasAnyAuthority("PRO.VER","CAT.GESTIONAR","UNI.GESTIONAR","PRO.GESTIONAR","PRO.PRESENTACIONES","PRO.MAYORISTA","PRO.MEDIDAS","COM.OC","COM.INGRESO","INV.VER","INV.APERTURA","INV.TRANSFORMAR","INV.AJUSTAR","INV.TOMA_GESTIONAR","INV.TOMA_CONTAR")
                .requestMatchers(HttpMethod.POST,"/api/catalogos/categorias").hasAuthority("CAT.GESTIONAR")
                .requestMatchers(HttpMethod.PUT,"/api/catalogos/categorias/*").hasAuthority("CAT.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/catalogos/categorias/*/estado").hasAuthority("CAT.GESTIONAR")
                .requestMatchers(HttpMethod.POST,"/api/catalogos/unidades").hasAuthority("UNI.GESTIONAR")
                .requestMatchers(HttpMethod.PUT,"/api/catalogos/unidades/*").hasAuthority("UNI.GESTIONAR")
                .requestMatchers(HttpMethod.PATCH,"/api/catalogos/unidades/*/estado").hasAuthority("UNI.GESTIONAR")
                .anyRequest().denyAll()).build();
    }
}



