package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.PurchaseController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import java.time.*;import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(PurchaseController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class PurchaseApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean PurchaseService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","ALM",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadPurchases()throws Exception{mvc.perform(get("/api/compras/ordenes")).andExpect(status().isUnauthorized());}
 @Test void productReaderCannotSeeSupplierDocuments()throws Exception{login("PRO.VER");mvc.perform(get("/api/compras/ingresos").header("Authorization","Bearer test")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void orderPermissionDoesNotConfirmReceiptOrOpenStock()throws Exception{login("COM.OC");for(String path:new String[]{"/api/compras/ingresos/1/procesar","/api/inventario/apertura"})mvc.perform(post(path).header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void cancellingOrderRequiresSeparatePermission()throws Exception{login("COM.OC");mvc.perform(post("/api/compras/ordenes/1/anular").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void receiptOperatorCanReadOrderReferences()throws Exception{login("COM.INGRESO");when(service.list(any(),anyString(),anyString(),isNull(),anyInt(),anyInt())).thenReturn(new Page<>(List.of(),0,0,20));mvc.perform(get("/api/compras/ordenes").header("Authorization","Bearer test")).andExpect(status().isOk());}
 @Test void malformedSupplierRejected()throws Exception{login("PRV.GESTIONAR");mvc.perform(post("/api/proveedores").header("Authorization","Bearer test").contentType("application/json").content("{\"ruc\":\"123\",\"razonSocial\":\"Proveedor\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void openingCannotAcceptDirectStockAssignment()throws Exception{login("INV.APERTURA");mvc.perform(post("/api/inventario/apertura").header("Authorization","Bearer test").contentType("application/json").content("{\"productoId\":1,\"stockActual\":100}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void detailCostsRejectExcessPrecision()throws Exception{login("COM.INGRESO");mvc.perform(post("/api/compras/ingresos/1/lineas").header("Authorization","Bearer test").contentType("application/json").content("{\"productoId\":1,\"presentacionId\":2,\"cantidad\":\"1\",\"costoUnitario\":\"1.1234567\",\"condicion\":\"GRANEL\",\"version\":\"2026-10-17T12:00:00\"}")).andExpect(status().isBadRequest());}
 @Test void physicalDeleteIsNotAvailable()throws Exception{login("COM.OC","COM.INGRESO","PRV.GESTIONAR");for(String path:new String[]{"/api/compras/ordenes/1","/api/compras/ingresos/1","/api/proveedores/1"})mvc.perform(delete(path).header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}
