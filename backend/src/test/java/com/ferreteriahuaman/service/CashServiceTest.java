package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.CashRepository;import com.ferreteriahuaman.security.AuthFailure;import java.time.LocalDate;import org.junit.jupiter.api.Test;import static org.mockito.Mockito.*;import static org.assertj.core.api.Assertions.*;
class CashServiceTest {CashRepository repo=mock(CashRepository.class);CashService service=new CashService(repo,mock(BusinessTransactions.class));
 @Test void invalidHistoryFiltersDoNotReachDatabase(){assertThatThrownBy(()->service.history(null,null,"OTRO",0,20)).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.history(LocalDate.of(2026,2,2),LocalDate.of(2026,1,1),"",0,20)).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.history(null,null,"",-1,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
}
