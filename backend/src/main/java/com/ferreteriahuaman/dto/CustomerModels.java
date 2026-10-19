package com.ferreteriahuaman.dto;
import java.math.BigDecimal;import java.time.LocalDateTime;import jakarta.validation.constraints.*;
public final class CustomerModels {
 private CustomerModels(){}
 public record Customer(long id,String tipoDocumento,String documento,String nombre,String telefono,String correo,String direccion,String limiteCredito,String saldoPendiente,String estado,LocalDateTime version){}
 public record Input(@NotBlank @Pattern(regexp="DNI|RUC") String tipoDocumento,@NotBlank @Pattern(regexp="[0-9]{8}|[0-9]{11}") String documento,@NotBlank @Size(max=150) String nombre,@Size(max=20) String telefono,@Email @Size(max=100) String correo,@Size(max=200) String direccion,LocalDateTime version){}
 public record Credit(@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal limite,@NotNull LocalDateTime version){}
}
