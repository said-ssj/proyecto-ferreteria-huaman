package com.ferreteriahuaman.dto;
import java.util.*;import jakarta.validation.constraints.*;import com.ferreteriahuaman.dto.UserAdminModels.Permission;
public final class RoleModels{
 private RoleModels(){}
 public record Editor(long id,String codigo,String nombre,String descripcion,String estado,boolean editable,String version,List<Permission> disponibles,List<String> asignados,List<String> obligatorios,long usuarios){}
 public record Change(@NotBlank @Pattern(regexp="[a-f0-9]{64}") String version,@NotNull @Size(max=100) List<@NotBlank @Size(max=40) String> permisos){}
 public record Result(Editor rol,long sesionesCerradas){}
}
