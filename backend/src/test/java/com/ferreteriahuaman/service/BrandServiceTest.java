package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.awt.image.BufferedImage;
import java.io.*;
import java.time.*;
import java.util.*;
import java.util.function.Supplier;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
class BrandServiceTest {
 BrandRepository repo;SettingsRepository settings;BusinessTransactions tx;BrandService service;Identity admin;
 @BeforeEach void setup(){repo=mock(BrandRepository.class);settings=mock(SettingsRepository.class);tx=mock(BusinessTransactions.class);service=new BrandService(repo,settings,tx,new ObjectMapper().findAndRegisterModules());admin=new Identity(1,"admin","N","A","ADM",false,Set.of("CFG.PARAMETROS"),UUID.randomUUID(),OffsetDateTime.now().plusHours(1));when(settings.admin(1)).thenReturn(true);when(tx.write(any(),anyString(),anyString(),any())).thenAnswer(i->((Supplier<?>)i.getArgument(3)).get());when(repo.get()).thenReturn(new BrandRepository.Data("Negocio",null,null,false,null));}
 String image(String format,int width,int height)throws Exception{var png=new BufferedImage(width,height,format.equals("jpeg")?BufferedImage.TYPE_INT_RGB:BufferedImage.TYPE_INT_ARGB);var bytes=new ByteArrayOutputStream();ImageIO.write(png,format,bytes);return Base64.getEncoder().encodeToString(bytes.toByteArray());}
 @Test void normalizesPngAndJpegToBoundedSquarePng()throws Exception{for(String format:List.of("png","jpeg")){byte[] png=service.normalize(image(format,40,20));var decoded=ImageIO.read(new ByteArrayInputStream(png));assertThat(decoded.getWidth()).isEqualTo(256);assertThat(decoded.getHeight()).isEqualTo(256);assertThat(decoded.getRGB(0,0)>>>24).isZero();assertThat(png.length).isLessThan(524288);}}
 @Test void rejectsUnsupportedCorruptOversizedAndDecompressionDimensions()throws Exception{for(String value:List.of("not-base64!",Base64.getEncoder().encodeToString("<svg onload='alert(1)'/>".getBytes()),image("gif",2,2),image("png",2049,1),Base64.getEncoder().encodeToString(new byte[524289]))){assertThatThrownBy(()->service.normalize(value)).isInstanceOfSatisfying(AuthFailure.class,e->assertThat(e.status()).isEqualTo(400));}}
 @Test void nonAdminCannotChangeBrandEvenWithConfigurationPermission(){var vendor=new Identity(2,"vendor","N","A","VEN",false,Set.of("CFG.PARAMETROS"),UUID.randomUUID(),OffsetDateTime.now().plusHours(1));assertThatThrownBy(()->service.save(vendor,"test",new BrandService.Change(null,false,false,null))).isInstanceOfSatisfying(AuthFailure.class,e->assertThat(e.status()).isEqualTo(403));verifyNoInteractions(repo,tx);}
 @Test void temporaryAdministratorCannotSave(){var temporary=new Identity(1,"admin","N","A","ADM",true,admin.permisos(),admin.sessionToken(),admin.expiraEn());assertThatThrownBy(()->service.save(temporary,"test",new BrandService.Change(null,false,false,null))).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo,tx);}
 @Test void freshDatabaseRoleIsRequired(){when(settings.admin(1)).thenReturn(false);assertThatThrownBy(()->service.save(admin,"test",new BrandService.Change(null,false,false,null))).isInstanceOf(AuthFailure.class);verify(repo,never()).save(any(),any(),anyBoolean());}
 @Test void staleVersionRejectsWrite(){when(repo.get()).thenReturn(new BrandRepository.Data("Negocio",null,null,false,LocalDateTime.now()));assertThatThrownBy(()->service.save(admin,"test",new BrandService.Change(null,false,false,null))).isInstanceOfSatisfying(AuthFailure.class,e->assertThat(e.status()).isEqualTo(409));verify(repo,never()).save(any(),any(),anyBoolean());}
 @Test void faviconRequiresLogoAndRemovalCannotBeCombinedWithUpload()throws Exception{assertThatThrownBy(()->service.save(admin,"test",new BrandService.Change(null,false,true,null))).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.save(admin,"test",new BrandService.Change(image("png",2,2),true,false,null))).isInstanceOf(AuthFailure.class);verify(repo,never()).save(any(),any(),anyBoolean());}
 @Test void savesNormalizedBytesWithoutPuttingImageInAudit()throws Exception{String encoded=image("png",30,40);service.save(admin,"test",new BrandService.Change(encoded,false,true,null));verify(repo).save(argThat(b->b!=null&&b.length>0),matches("[a-f0-9]{64}"),eq(true));verify(settings).audit(eq(1L),eq("CFG.PARAMETROS"),eq("identidad_visual"),eq(1L),argThat(j->!j.contains(encoded)),argThat(j->!j.contains(encoded)));}
 @Test void publicMetadataDoesNotExposeBytesAndOldHashCannotReadLogo()throws Exception{String hash="a".repeat(64);when(repo.get()).thenReturn(new BrandRepository.Data("Negocio",new byte[]{1,2},hash,true,null));assertThat(new ObjectMapper().writeValueAsString(service.get())).doesNotContain("png","imagenBase64").contains(hash);assertThat(service.image(hash)).containsExactly((byte)1,(byte)2);assertThatThrownBy(()->service.image("b".repeat(64))).isInstanceOf(AuthFailure.class);}
}
