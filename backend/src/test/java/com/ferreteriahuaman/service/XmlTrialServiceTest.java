package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.security.AuthFailure;import java.time.*;import java.util.*;import org.junit.jupiter.api.Test;import static org.mockito.Mockito.*;import static org.assertj.core.api.Assertions.*;
class XmlTrialServiceTest{
 XmlTrialRepository repo=mock(XmlTrialRepository.class);XmlTrialService service=new XmlTrialService(repo,new XmlTrialRenderer(),mock(BusinessTransactions.class),mock(AuthStore.class));Identity actor(String role,String...p){return new Identity(1,"test","N","A",role,false,Set.of(p),UUID.randomUUID(),OffsetDateTime.now().plusHours(1));}
 @Test void salesRoleCannotUseLabEvenWithXmlPermission(){assertThatThrownBy(()->service.status(actor("VEN","VEN.XML"))).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void adminStillNeedsXmlPermission(){assertThatThrownBy(()->service.example(actor("ADM","VEN.HISTORIAL"),"B")).isInstanceOf(AuthFailure.class);}
 @Test void realReceiptRequiresHistoryPermission(){assertThatThrownBy(()->service.preview(actor("ADM","VEN.XML"),1)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void statusNeverEnablesFiscalEmission(){var status=service.status(actor("ADM","VEN.XML"));assertThat(status.modo()).isEqualTo("LOCAL_SIN_FIRMA");assertThat(status.enviosHabilitados()).isFalse();assertThat(status.firmaDigital()).isFalse();assertThat(status.validezTributaria()).isFalse();}
 @Test void missingReceiptReturnsNotFound(){when(repo.get(99,false)).thenReturn(Optional.empty());assertThatThrownBy(()->service.preview(actor("ADM","VEN.XML","VEN.HISTORIAL"),99)).isInstanceOf(AuthFailure.class).hasMessage("Comprobante no encontrado");}
 @Test void invalidExampleDoesNotReachDatabase(){assertThatThrownBy(()->service.example(actor("ADM","VEN.XML"),"N")).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
}
