package com.ferreteriahuaman.dto;

import jakarta.validation.constraints.*;
import java.time.LocalDateTime;
import java.util.List;

public final class UserAdminModels {
 private UserAdminModels(){}
 public record User(long id,String usuario,String nombres,String apellidos,String dni,String telefono,String correo,
   long rolId,String rol,String rolNombre,String estado,boolean cambioClaveObligatorio,LocalDateTime bloqueadoHasta,
   LocalDateTime ultimoIngreso,LocalDateTime version){}
 public record Page(List<User> items,long total,int pagina,int tamano){}
 public record Permission(String codigo,String modulo,String descripcion){}
 public record Role(long id,String codigo,String nombre,String descripcion,String estado,List<Permission> permisos){}
 public record Input(@NotBlank @Pattern(regexp="[A-Za-z0-9._-]{4,30}") String usuario,
   @NotBlank @Size(max=100) String nombres,@NotBlank @Size(max=100) String apellidos,
   @NotBlank @Pattern(regexp="(?!00000000)[0-9]{8}") String dni,
   @Size(max=20) String telefono,@Email @Size(max=100) String correo,@Positive long rolId,
   LocalDateTime version,@Size(max=72) String claveTemporal){
   @Override public String toString(){return "UserInput[datos privados omitidos]";}
 }
 public record State(@NotBlank @Pattern(regexp="A|I") String estado,@NotNull LocalDateTime version){}
 public record Reset(@NotBlank @Size(min=8,max=72) String claveTemporal,@NotNull LocalDateTime version){
   @Override public String toString(){return "PasswordReset[credencial omitida]";}
 }
}
