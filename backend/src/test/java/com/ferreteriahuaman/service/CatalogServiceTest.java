package com.ferreteriahuaman.service;

import com.ferreteriahuaman.repository.CatalogRepository;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.security.AuthFailure;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class CatalogServiceTest {
 CatalogRepository repo;BusinessTransactions tx;CatalogService service;
 LocalDateTime version=LocalDateTime.of(2026,10,17,12,0);
 Identity actor=new Identity(1,"prueba","Nombre","Apellido","ADM",false,Set.of(),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30));
 @BeforeEach void prepare(){repo=mock(CatalogRepository.class);tx=mock(BusinessTransactions.class);
  when(tx.write(any(),anyString(),anyString(),any())).thenAnswer(inv->((Supplier<?>)inv.getArgument(3)).get());
  service=new CatalogService(repo,tx,new ObjectMapper().findAndRegisterModules());
 }
 @Test void invalidPaginationNeverExecutesQueries(){assertThatThrownBy(()->service.categories("","",-1,20)).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.units("","",0,101)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void invalidStateNeverExecutesQueries(){assertThatThrownBy(()->service.categories("","X",0,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void staleCategoryDoesNotOverwriteChanges(){when(repo.category(2,true)).thenReturn(Optional.of(new Category(2,"Nombre",null,"A",version)));
  assertThatThrownBy(()->service.updateCategory(actor,"equipo",2,new CategoryInput("Otro",null,version.minusSeconds(1)))).isInstanceOf(AuthFailure.class);
  verify(repo,never()).updateCategory(anyLong(),any());}
 @Test void requiresVersionForCategoryUpdate(){when(repo.category(2,true)).thenReturn(Optional.of(new Category(2,"Nombre",null,"A",version)));
  assertThatThrownBy(()->service.updateCategory(actor,"equipo",2,new CategoryInput("Otro",null,null))).isInstanceOf(AuthFailure.class);}
 @Test void cannotDeactivateCategoryWithActiveProducts(){when(repo.category(2,true)).thenReturn(Optional.of(new Category(2,"Nombre",null,"A",version)));when(repo.categoryInUse(2)).thenReturn(true);
  assertThatThrownBy(()->service.categoryState(actor,"equipo",2,new StateInput("I",version))).isInstanceOf(AuthFailure.class);verify(repo,never()).categoryState(anyLong(),anyString());}
 @Test void identicalStateDoesNotCreateDuplicateAudit(){Category category=new Category(2,"Nombre",null,"A",version);when(repo.category(2,true)).thenReturn(Optional.of(category));
  assertThat(service.categoryState(actor,"equipo",2,new StateInput("A",version))).isEqualTo(category);verify(repo,never()).event(anyLong(),anyString(),anyString(),anyLong(),any(),any());}
 UnitInput input(boolean decimals,int precision,BigDecimal factor){return new UnitInput("Unidad","u","NIU","Unidades",decimals,"CONTEO",factor,precision,version);}
 @Test void decimalsMustAgreeWithPrecision(){assertThatThrownBy(()->service.createUnit(actor,"equipo",input(false,2,BigDecimal.ONE))).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void usedUnitCannotChangeMeasurement(){when(repo.unit(2,true)).thenReturn(Optional.of(new Unit(2,"Unidad","u","NIU","Unidades",false,"CONTEO",BigDecimal.ONE,0,"A",version)));when(repo.unitInUse(2)).thenReturn(true);
  assertThatThrownBy(()->service.updateUnit(actor,"equipo",2,input(false,0,BigDecimal.TEN))).isInstanceOf(AuthFailure.class);verify(repo,never()).updateUnit(anyLong(),any());}
 @Test void usedUnitCannotBeDeactivated(){when(repo.unit(2,true)).thenReturn(Optional.of(new Unit(2,"Unidad","u","NIU","Unidades",false,"CONTEO",BigDecimal.ONE,0,"A",version)));when(repo.unitInUse(2)).thenReturn(true);
  assertThatThrownBy(()->service.unitState(actor,"equipo",2,new StateInput("I",version))).isInstanceOf(AuthFailure.class);}
 @Test void creationUsesTransactionPermissionAndAudit(){when(repo.createCategory(any())).thenReturn(2L);when(repo.category(2,false)).thenReturn(Optional.of(new Category(2,"Nombre",null,"A",version)));
  service.createCategory(actor,"equipo",new CategoryInput("Nombre",null,null));verify(tx).write(eq(actor),eq("equipo"),eq("CAT.GESTIONAR"),any());verify(repo).event(eq(1L),eq("CAT.CREAR"),eq("categoria"),eq(2L),isNull(),anyString());}
}
