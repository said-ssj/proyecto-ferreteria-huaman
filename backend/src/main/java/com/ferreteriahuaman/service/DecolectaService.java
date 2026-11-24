package com.ferreteriahuaman.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.security.AuthFailure;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.Semaphore;

@Service @Profile("db")
public class DecolectaService {
 public record Dni(String documento,String nombre) {}
 private record CachedDni(Dni data,Instant expires) {}
 private final Map<String,CachedDni> dniCache=new LinkedHashMap<>();
 public record Ruc(String ruc,String razonSocial,String estadoTributario,String condicion,String direccion,String ubigeo,String departamento,String provincia,String distrito) {}
 private record Cached(Ruc data,Instant expires) {}
 private final String key; private final ObjectMapper mapper;
 private final HttpClient client;
 private final Map<String,Cached> cache=new LinkedHashMap<>();
 private final Semaphore gate=new Semaphore(1); private Instant next=Instant.MIN;
 @org.springframework.beans.factory.annotation.Autowired
 public DecolectaService(@Value("${DECOLECTA_API_KEY:}") String key,ObjectMapper mapper){this(key,mapper,HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).followRedirects(HttpClient.Redirect.NEVER).build());}
 DecolectaService(String key,ObjectMapper mapper,HttpClient client){this.key=key.strip();this.mapper=mapper;this.client=client;}
 public Ruc lookup(String number){
  if(number==null||!number.matches("(?:10|15|16|17|20)[0-9]{9}"))throw new AuthFailure(400,"Ingresa un RUC de 11 dígitos válido.");
  if(key.isBlank())throw new AuthFailure(503,"La consulta de RUC no está configurada. Puedes completar los datos manualmente.");
  if(!gate.tryAcquire())throw new AuthFailure(429,"Hay una consulta en curso. Intenta nuevamente en unos segundos.");
  try{
   Instant now=Instant.now();cache.entrySet().removeIf(e->e.getValue().expires().isBefore(now));
   Cached saved=cache.get(number);if(saved!=null)return saved.data();
   if(now.isBefore(next))throw new AuthFailure(429,"Espera unos segundos antes de volver a consultar.");
   next=now.plusSeconds(2);
   HttpRequest request=HttpRequest.newBuilder(URI.create("https://api.decolecta.com/v1/sunat/ruc?numero="+number)).timeout(Duration.ofSeconds(10)).header("Authorization","Bearer "+key).header("Accept","application/json").GET().build();
   HttpResponse<String> response=client.send(request,HttpResponse.BodyHandlers.ofString());
   int status=response.statusCode();
   if(status==401||status==403)throw new AuthFailure(503,"El proveedor rechazó las credenciales o el acceso. Revisa la configuración de Decolecta.");
   if(status==429)throw new AuthFailure(429,"Se alcanzó el límite de consultas de Decolecta. Puedes ingresar los datos manualmente.");
   if(status==404)throw new AuthFailure(404,"No se encontraron datos para este RUC. Puedes ingresarlos manualmente.");
   if(status==400||status==422)throw new AuthFailure(400,"Decolecta no reconoce este RUC. Revisa el número ingresado.");
   if(status!=200||response.body().length()>65536)throw new AuthFailure(503,"La consulta de RUC no está disponible. Puedes completar los datos manualmente.");
   JsonNode body=mapper.readTree(response.body());
   if(!number.equals(text(body,"numero_documento"))||text(body,"razon_social")==null)throw new AuthFailure(503,"La respuesta del proveedor está incompleta. Puedes ingresar los datos manualmente.");
   Ruc result=new Ruc(number,text(body,"razon_social"),text(body,"estado"),text(body,"condicion"),text(body,"direccion"),text(body,"ubigeo"),text(body,"departamento"),text(body,"provincia"),text(body,"distrito"));
   if(cache.size()>=64)cache.remove(cache.keySet().iterator().next());cache.put(number,new Cached(result,now.plusSeconds(600)));return result;
  }catch(AuthFailure e){throw e;}catch(InterruptedException e){Thread.currentThread().interrupt();throw new AuthFailure(503,"Consulta interrumpida. Intenta nuevamente.");}catch(Exception e){throw new AuthFailure(503,"No se pudo consultar Decolecta. Puedes completar los datos manualmente.");}finally{gate.release();}
 }
 public Dni lookupDni(String number){
  if(number==null||!number.matches("(?!0{8})[0-9]{8}"))throw new AuthFailure(400,"Ingresa un DNI de 8 dígitos válido.");
  if(key.isBlank())throw new AuthFailure(503,"La consulta de DNI no está configurada. Puedes completar los datos manualmente.");
  if(!gate.tryAcquire())throw new AuthFailure(429,"Hay una consulta en curso. Intenta nuevamente en unos segundos.");
  try{
   Instant now=Instant.now();dniCache.entrySet().removeIf(e->!e.getValue().expires().isAfter(now));var cached=dniCache.get(number);if(cached!=null)return cached.data();
   if(now.isBefore(next))throw new AuthFailure(429,"Espera unos segundos antes de volver a consultar.");next=now.plusSeconds(2);
   var request=HttpRequest.newBuilder(URI.create("https://api.decolecta.com/v1/reniec/dni?numero="+number)).timeout(Duration.ofSeconds(10)).header("Authorization","Bearer "+key).header("Accept","application/json").GET().build();
   var response=client.send(request,HttpResponse.BodyHandlers.ofString());int status=response.statusCode();
   if(status==401||status==403)throw new AuthFailure(503,"Decolecta no permite la consulta de DNI con la configuración actual. Puedes completar los datos manualmente.");
   if(status==429)throw new AuthFailure(429,"Se alcanzó el límite de consultas. Puedes completar los datos manualmente.");
   if(status==404)throw new AuthFailure(404,"No se encontraron datos para ese DNI. Puedes completarlos manualmente.");
   if(status==400||status==422)throw new AuthFailure(400,"El proveedor no reconoce ese DNI. Revisa el documento.");
   if(status!=200||response.body().length()>65536)throw new AuthFailure(503,"La consulta de DNI no está disponible. Puedes completar los datos manualmente.");
   var body=mapper.readTree(response.body());String name=text(body,"full_name");
   if(name==null)name=String.join(" ",java.util.stream.Stream.of(text(body,"first_last_name"),text(body,"second_last_name"),text(body,"first_name")).filter(Objects::nonNull).toList());
   if(!number.equals(text(body,"document_number"))||name.isBlank())throw new AuthFailure(503,"La respuesta de DNI está incompleta. Puedes completar los datos manualmente.");
   var result=new Dni(number,name);if(dniCache.size()>=64)dniCache.remove(dniCache.keySet().iterator().next());dniCache.put(number,new CachedDni(result,now.plusSeconds(600)));return result;
  }catch(AuthFailure e){throw e;}catch(InterruptedException e){Thread.currentThread().interrupt();throw new AuthFailure(503,"Consulta interrumpida. Intenta nuevamente.");}catch(Exception e){throw new AuthFailure(503,"No se pudo consultar el DNI. Puedes completar los datos manualmente.");}finally{gate.release();}
 }
 private String text(JsonNode node,String field){JsonNode value=node.get(field);if(value==null||!value.isTextual())return null;String s=value.asText().strip();return s.isEmpty()||s.equals("-")?null:s;}
}
