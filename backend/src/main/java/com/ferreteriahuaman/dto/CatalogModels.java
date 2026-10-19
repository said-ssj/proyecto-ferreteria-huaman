package com.ferreteriahuaman.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;

public final class CatalogModels {
    private CatalogModels(){}
    public record Page<T>(List<T> items,long total,int pagina,int tamano){}
    public record Category(long id,String nombre,String descripcion,String estado,LocalDateTime version){}
    public record CategoryInput(@NotBlank @Size(max=60) String nombre,@Size(max=200) String descripcion,LocalDateTime version){}
    public record Unit(long id,String nombre,String abreviatura,String codigoSunat,String descripcionComercial,
        boolean admiteDecimales,String magnitud,@JsonSerialize(using=ToStringSerializer.class) BigDecimal factorReferencia,int precisionCantidad,String estado,LocalDateTime version){}
    public record UnitInput(@NotBlank @Size(max=40) String nombre,@NotBlank @Size(max=8) String abreviatura,
        @NotBlank @Pattern(regexp="[A-Z0-9]{2,3}") String codigoSunat,@NotBlank @Size(max=80) String descripcionComercial,
        boolean admiteDecimales,@NotBlank @Pattern(regexp="CONTEO|PESO|LONGITUD|VOLUMEN") String magnitud,
        @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal factorReferencia,
        @Min(0) @Max(6) int precisionCantidad,LocalDateTime version){}
    public record StateInput(@NotBlank @Pattern(regexp="A|I") String estado,@NotNull LocalDateTime version){}
}
