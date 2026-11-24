package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.SaleModels.*;
import com.ferreteriahuaman.dto.CustomerModels.*;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.security.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
@Service @Profile("db") public class PosCustomerService {
 private final CustomerRepository repo;private final CustomerService customers;private final DecolectaService external;private final ObjectMapper mapper;private final PurchaseRepository audit;
 public PosCustomerService(CustomerRepository repo,CustomerService customers,DecolectaService external,ObjectMapper mapper,PurchaseRepository audit){this.repo=repo;this.customers=customers;this.external=external;this.mapper=mapper;this.audit=audit;}
 private String json(Object value){try{return mapper.writeValueAsString(value);}catch(Exception e){throw new IllegalStateException("No se pudo preparar la identificación del cliente");}}
 private FiscalData data(long id){String value=repo.identification(id);if(value==null)return null;try{return mapper.readValue(value,FiscalData.class);}catch(Exception e){throw new IllegalStateException("No se pudo recuperar la identificación del cliente");}}
 public ClientLookup lookup(String document){
  if(document==null||!document.matches("(?!0+$)([0-9]{8}|[0-9]{11})"))throw new AuthFailure(400,"Escribe un DNI de 8 dígitos o un RUC de 11 dígitos");
  var local=repo.documentCustomer(document);
  if(local.isPresent()){var c=local.get();if(!c.estado().equals("A"))throw new AuthFailure(409,"El cliente está inactivo. Solicita su revisión antes de vender.");return new ClientLookup(c.id(),c.tipoDocumento(),c.documento(),c.nombre(),c.telefono(),c.correo(),c.direccion(),"REGISTRO",data(c.id()));}
  if(document.length()==8){var d=external.lookupDni(document);return new ClientLookup(null,"DNI",document,d.nombre(),null,null,null,"RENIEC",null);}
  var r=external.lookup(document);return new ClientLookup(null,"RUC",document,r.razonSocial(),null,null,r.direccion(),"SUNAT",new FiscalData(r.estadoTributario(),r.condicion(),r.ubigeo(),r.departamento(),r.provincia(),r.distrito()));
 }
 public Input input(ClientCandidate c){return new Input(c.tipoDocumento(),c.documento(),c.nombre(),c.telefono(),c.correo(),c.direccion(),null);}
 public void validate(ClientCandidate c){customers.validate(input(c));}
 public long confirm(Identity actor,ClientCandidate c){
  validate(c);repo.lockDocument(c.documento());var existing=repo.documentCustomer(c.documento());
  if(existing.isPresent()){if(!existing.get().estado().equals("A"))throw new AuthFailure(409,"El cliente está inactivo. Solicita su revisión.");return existing.get().id();}
  long id=repo.create(input(c));if(c.datosIdentificacion()!=null)repo.identification(id,json(c.datosIdentificacion()));
  audit.event(actor.id(),"CLI.CREAR_EN_VENTA","cliente",id,null,json(repo.get(id,false).orElseThrow()),null);return id;
 }
}
