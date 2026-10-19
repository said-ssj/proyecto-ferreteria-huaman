package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.security.AuthFailure;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.*;import java.util.*;import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
import static org.assertj.core.api.Assertions.*;
class ProductServiceTest {
 ProductRepository repo;CatalogRepository catalog;BusinessTransactions tx;AuthStore auth;ProductService service;
 Identity actor(Set<String> permissions){return new Identity(1,"usuario","Nombre","Apellido","ADM",false,permissions,UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30));}
 @BeforeEach void prepare(){repo=mock(ProductRepository.class);catalog=mock(CatalogRepository.class);tx=mock(BusinessTransactions.class);auth=mock(AuthStore.class);service=new ProductService(repo,catalog,tx,new ObjectMapper(),auth);when(tx.write(any(),anyString(),anyString(),any())).thenAnswer(call->((Supplier<?>)call.getArgument(3)).get());}
 @Test void roleNameDoesNotRevealCostsWithoutSpecificPermission(){service.list(actor(Set.of("PRO.VER")),"clavo","A",null,0,20);verify(repo).list("clavo","A",null,0,20,false);}
 @Test void costPermissionEnablesCostProjection(){service.list(actor(Set.of("PRO.VER","PRO.COSTOS")),"","",null,0,20);verify(repo).list("","",null,0,20,true);}
 @Test void rejectsInvalidPagingBeforeQuery(){for(int page:new int[]{-1,1000001})assertThatThrownBy(()->service.list(actor(Set.of()),"","",null,page,20)).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.list(actor(Set.of()),"","X",null,0,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void creationRequiresCurrentPricePermissionEvenIfTokenListedIt(){when(auth.permissions(1)).thenReturn(Set.of("PRO.GESTIONAR"));assertThatThrownBy(()->service.create(actor(Set.of("PRO.GESTIONAR","PRO.PRECIOS")),"equipo",null)).isInstanceOf(AuthFailure.class).hasMessage("No tienes permiso para modificar precios");verifyNoInteractions(repo,catalog);verify(tx).write(any(),eq("equipo"),eq("PRO.GESTIONAR"),any());}
}
