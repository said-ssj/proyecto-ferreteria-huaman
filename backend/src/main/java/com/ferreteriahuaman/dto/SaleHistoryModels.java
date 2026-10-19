package com.ferreteriahuaman.dto;
import java.math.BigDecimal;import java.time.LocalDateTime;import java.util.*;import jakarta.validation.Valid;import jakarta.validation.constraints.*;
public final class SaleHistoryModels {
 private SaleHistoryModels(){}
 public record Key(@NotNull UUID clave){}
 public record Copy(@NotNull UUID clave,@NotNull LocalDateTime version){}
 public record Piece(@NotBlank @Pattern(regexp="ENVASE|SUELTO|TRAMO") String condicion,@Positive Long presentacionId,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad){}
 public record Return(@Positive long lineaId,@NotEmpty @Size(max=1000) List<@Valid Piece> unidades){}
 public record Cancel(@NotNull UUID clave,@NotNull LocalDateTime version,@NotBlank @Size(min=10,max=200) @Pattern(regexp="[^<>]*") String motivo,@NotNull Boolean retornoConfirmado,@NotNull @Size(max=100) List<@Valid Return> retornos,@Pattern(regexp="[0-9]{6,20}") String referenciaYape,@Size(min=1,max=40) String referenciaDebito){}
}
