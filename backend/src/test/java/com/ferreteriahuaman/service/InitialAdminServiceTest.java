package com.ferreteriahuaman.service;

import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.*;
import org.springframework.transaction.support.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class InitialAdminServiceTest {
    final InitialAdminService.Details details=new InitialAdminService.Details("administrador","Nombre","Apellido","12345678");
    JdbcTemplate jdbc;InitialAdminService service;
    @BeforeEach void prepare(){
        jdbc=mock(JdbcTemplate.class);
        var manager=new AbstractPlatformTransactionManager(){
            protected Object doGetTransaction(){return new Object();}
            protected void doBegin(Object t,TransactionDefinition d){}
            protected void doCommit(DefaultTransactionStatus s){}
            protected void doRollback(DefaultTransactionStatus s){}
        };
        service=new InitialAdminService(jdbc,new BCryptPasswordEncoder(4),new TransactionTemplate(manager));
    }
    @Test void acceptsValidPrivateDetails(){assertThatCode(()->InitialAdminService.validate(details,"Privada1234".toCharArray())).doesNotThrowAnyException();}
    @Test void refusesWeakPasswords(){for(String password:new String[]{"abcdefgh","12345678","Ab12","administrador"})
        assertThatIllegalArgumentException().isThrownBy(()->InitialAdminService.validate(details,password.toCharArray()));}
    @Test void refusesGenericIdentityDocument(){var invalid=new InitialAdminService.Details("administrador","Nombre","Apellido","00000000");
        assertThatIllegalArgumentException().isThrownBy(()->InitialAdminService.validate(invalid,"Privada1234".toCharArray()));}
    @Test void refusesSpacesInUsername(){var invalid=new InitialAdminService.Details("nombre apellido","Nombre","Apellido","12345678");
        assertThatIllegalArgumentException().isThrownBy(()->InitialAdminService.validate(invalid,"Privada1234".toCharArray()));}
    @Test void willNotCreateOrOverwriteWhenAnyUserExists(){
        when(jdbc.queryForObject("select exists(select 1 from huaman.usuario)",Boolean.class)).thenReturn(true);
        assertThatIllegalStateException().isThrownBy(()->service.create(details,"Privada1234".toCharArray()));
        verify(jdbc).execute("lock table huaman.usuario in share row exclusive mode");
        verify(jdbc,never()).queryForObject(contains("insert into"),eq(Long.class),any(),any(),any(),any(),any(),any());
    }
    @Test void createsHashAndAuditsWithoutStoringClearPassword(){
        when(jdbc.queryForObject("select exists(select 1 from huaman.usuario)",Boolean.class)).thenReturn(false);
        when(jdbc.queryForObject("select id_rol from huaman.rol where codigo='ADM' and estado='A' for share",Long.class)).thenReturn(1L);
        when(jdbc.queryForObject(contains("insert into"),eq(Long.class),any(),any(),any(),any(),any(),any())).thenReturn(2L);
        service.create(details,"Privada1234".toCharArray());
        var hash=org.mockito.ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(contains("insert into"),eq(Long.class),eq(details.usuario()),hash.capture(),eq(details.nombres()),eq(details.apellidos()),eq(details.dni()),eq(1L));
        assertThat(hash.getValue()).startsWith("$2");assertThat(new BCryptPasswordEncoder().matches("Privada1234",hash.getValue())).isTrue();
        verify(jdbc).update(contains("SEG.USUARIO_CREAR"),eq(2L),eq(2L));
    }
}
