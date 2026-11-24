package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.UserAdminModels.*;
import com.ferreteriahuaman.repository.UserAdminRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.*;
import java.util.function.Supplier;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service @Profile("db")
public class UserAdminService {
 private final UserAdminRepository repo;private final BusinessTransactions tx;private final TransactionTemplate transaction;private final PasswordEncoder encoder;private final ObjectMapper mapper;
 public UserAdminService(UserAdminRepository repo,BusinessTransactions tx,TransactionTemplate transaction,PasswordEncoder encoder,ObjectMapper mapper){this.repo=repo;this.tx=tx;this.transaction=transaction;this.encoder=encoder;this.mapper=mapper;}
 private void access(Identity actor,String permission){if(actor==null||!"ADM".equals(actor.rol())||actor.cambioClaveObligatorio()||!actor.permisos().contains(permission))throw new AuthFailure(403,"Solo administración puede realizar esta acción");}
 public Page list(Identity actor,String q,String state,int page,int size){access(actor,"SEG.USUARIOS");if(q.length()>100||!state.matches("A|I|^$")||page<0||page>1000000||size<1||size>100)throw new AuthFailure(400,"Revisa los filtros y la página");return repo.list(q.strip(),state,page,size);}
 public User user(Identity actor,long id){access(actor,"SEG.USUARIOS");return find(id,false);}
 public List<Role> roles(Identity actor,boolean options){access(actor,options?"SEG.USUARIOS":"SEG.PERMISOS");return repo.roles();}
 private User find(long id,boolean lock){return repo.user(id,lock).orElseThrow(()->new AuthFailure(404,"Usuario no encontrado"));}
 private void version(LocalDateTime expected,User current){if(expected==null)throw new AuthFailure(400,"Falta la versión del usuario");if(!expected.equals(current.version()))throw new AuthFailure(409,"El usuario cambió. Actualiza la información antes de guardar");}
 private <T>T mutate(Identity actor,String equipo,Supplier<T> action){access(actor,"SEG.USUARIOS");return transaction.execute(status->{repo.serialize();return tx.write(actor,equipo,"SEG.USUARIOS",()->{if(!"ADM".equals(find(actor.id(),true).rol()))throw new AuthFailure(403,"Solo administración puede gestionar usuarios");return action.get();});});}
 private Role activeRole(long id){Role role=repo.role(id).orElseThrow(()->new AuthFailure(400,"Selecciona un rol existente"));if(!role.estado().equals("A"))throw new AuthFailure(400,"Selecciona un rol activo");return role;}
 private String json(Object value){if(value==null)return null;try{return mapper.writeValueAsString(value);}catch(JsonProcessingException e){throw new IllegalStateException("No se pudo registrar la auditoría");}}
 private void event(Identity actor,String action,User before,User after){repo.audit(actor.id(),action,after.id(),json(before),json(after));}
 static void password(String username,String password){if(password==null||password.length()<8||password.getBytes(StandardCharsets.UTF_8).length>72||!password.chars().anyMatch(Character::isLetter)||!password.chars().anyMatch(Character::isDigit)||password.equalsIgnoreCase(username))throw new AuthFailure(400,"La contraseña temporal necesita al menos 8 caracteres, letras y números; debe ser distinta del usuario y ocupar como máximo 72 bytes UTF-8");}
 private void protectAdmin(User before,boolean removesAccess){if(before.rol().equals("ADM")&&before.estado().equals("A")&&removesAccess&&repo.activeAdmins()<=1)throw new AuthFailure(409,"Debe permanecer al menos un administrador operativo con contraseña definitiva");}
 public User create(Identity actor,String equipo,Input input){password(input.usuario(),input.claveTemporal());return mutate(actor,equipo,()->{activeRole(input.rolId());long id=repo.create(input,encoder.encode(input.claveTemporal()));User after=find(id,false);event(actor,"SEG.USUARIO_CREAR",null,after);return after;});}
 public User update(Identity actor,String equipo,long id,Input input){return mutate(actor,equipo,()->{
  User before=find(id,true);version(input.version(),before);Role role=activeRole(input.rolId());
  if(!before.usuario().equals(input.usuario()))throw new AuthFailure(400,"El nombre de acceso no se puede modificar");
  if(input.claveTemporal()!=null&&!input.claveTemporal().isEmpty())throw new AuthFailure(400,"Utiliza la acción de restablecer contraseña");
  boolean changed=before.rolId()!=input.rolId();if(actor.id()==id&&changed)throw new AuthFailure(409,"No puedes cambiar tu propio rol");protectAdmin(before,!role.codigo().equals("ADM"));
  repo.update(id,input);if(changed)repo.revoke(id);User after=find(id,false);event(actor,"SEG.USUARIO_EDITAR",before,after);return after;
 });}
 public User state(Identity actor,String equipo,long id,State input){return mutate(actor,equipo,()->{
  User before=find(id,true);version(input.version(),before);if(before.estado().equals(input.estado()))return before;
  if(actor.id()==id)throw new AuthFailure(409,"No puedes desactivar tu propia cuenta");protectAdmin(before,input.estado().equals("I"));
  activeRole(before.rolId());repo.state(id,input.estado());if(input.estado().equals("I"))repo.revoke(id);User after=find(id,false);event(actor,"SEG.USUARIO_ESTADO",before,after);return after;
 });}
 public User reset(Identity actor,String equipo,long id,Reset input){return mutate(actor,equipo,()->{
  User before=find(id,true);version(input.version(),before);if(actor.id()==id)throw new AuthFailure(409,"Cambia tu contraseña desde Mi perfil");
  if(!before.estado().equals("A"))throw new AuthFailure(409,"Activa la cuenta antes de restablecer su contraseña");protectAdmin(before,true);password(before.usuario(),input.claveTemporal());
  repo.reset(id,encoder.encode(input.claveTemporal()));repo.revoke(id);User after=find(id,false);event(actor,"SEG.USUARIO_CLAVE",before,after);return after;
 });}
}
