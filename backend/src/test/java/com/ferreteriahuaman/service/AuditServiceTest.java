package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.AuditRepository;import com.ferreteriahuaman.dto.AuditModels.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.security.AuthFailure;import com.fasterxml.jackson.databind.ObjectMapper;import java.time.*;import java.util.*;import org.junit.jupiter.api.*;import static org.mockito.Mockito.*;import static org.assertj.core.api.Assertions.*;
class AuditServiceTest {
 AuditRepository repo=mock(AuditRepository.class);AuditService service=new AuditService(repo,new ObjectMapper());
 Identity actor(String role,Set<String> permissions,boolean temporary){return new Identity(1,"admin.test","N","A",role,temporary,permissions,UUID.randomUUID(),OffsetDateTime.now().plusHours(1));}
 Identity admin(){return actor("ADM",Set.of("SEG.BITACORA"),false);}
 Filter valid(){return new Filter(null,null,"","","",0,25);}
 @Test void onlyAdminWithPermissionCanRead(){for(var a:List.of(actor("VEN",Set.of("SEG.BITACORA"),false),actor("ADM",Set.of(),false),actor("ADM",Set.of("SEG.BITACORA"),true)))assertThatThrownBy(()->service.list(a,valid())).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void reverseDatesRejected(){assertThatThrownBy(()->service.list(admin(),new Filter(LocalDate.of(2026,10,25),LocalDate.of(2026,10,24),"","","",0,25))).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void rejectsUnboundedAndInvalidFilters(){for(var f:List.of(new Filter(null,null,"","","",-1,25),new Filter(null,null,"","","",0,101),new Filter(null,null,"","' OR 1=1","",0,25),new Filter(null,null,"","","OTRO",0,25),new Filter(null,LocalDate.of(9999,1,1),"","","",0,25)))assertThatThrownBy(()->service.list(admin(),f)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void trimsUserSearch(){service.list(admin(),new Filter(null,null," cuenta ","SEG.LOGIN","SEGURIDAD",0,25));verify(repo).list(new Filter(null,null,"cuenta","SEG.LOGIN","SEGURIDAD",0,25));}
 @Test void unavailableDetailReturnsNotFound(){when(repo.detail(99)).thenReturn(Optional.empty());assertThatThrownBy(()->service.detail(admin(),99)).isInstanceOf(AuthFailure.class).hasMessage("Evento no encontrado");}
 @Test void dropsCredentialsUnknownFieldsAndNestedSecrets(){var value=service.sanitize("{\"estado\":\"A\",\"password\":\"secreto\",\"hash\":\"hash-secreto\",\"token\":\"token-secreto\",\"desconocido\":1,\"solicitud\":{\"cantidad\":2,\"clave\":\"clave-secreta\"}}");assertThat(value.toString()).doesNotContain("secreto","token","password","desconocido");assertThat(value.path("solicitud").path("cantidad").asInt()).isEqualTo(2);}
 @Test void malformedAndMissingPayloadAreSafe(){assertThat(service.sanitize(null).isNull()).isTrue();assertThat(service.sanitize("\"private-token\"").isNull()).isTrue();assertThat(service.sanitize("invalid").asText()).isEqualTo("Detalle no disponible");}
 @Test void limitsLongTextAndPayload(){assertThat(service.sanitize("{\"motivo\":\""+"a".repeat(600)+"\"}").path("motivo").asText()).hasSize(501);assertThat(service.sanitize(" ".repeat(200001)).asText()).contains("extenso");}
}
