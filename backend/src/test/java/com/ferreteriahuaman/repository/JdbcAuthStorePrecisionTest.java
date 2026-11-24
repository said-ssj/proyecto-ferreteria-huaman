package com.ferreteriahuaman.repository;
import java.time.LocalDateTime;import java.util.UUID;
import org.junit.jupiter.api.Test;import org.springframework.jdbc.core.JdbcTemplate;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
class JdbcAuthStorePrecisionTest {
 @Test void sessionStartCannotBeRoundedIntoTheFutureByPostgres(){
  var jdbc=mock(JdbcTemplate.class);var store=new JdbcAuthStore(jdbc);UUID token=UUID.randomUUID();
  var instant=LocalDateTime.of(2026,10,25,12,30,0,999999999);var micros=instant.withNano(999999000);
  store.createSession(7L,token,instant);verify(jdbc).update(anyString(),eq(7L),eq(token),eq(micros),eq(micros));
 }
 @Test void activityRefreshUsesTheSameMicrosecondPrecision(){
  var jdbc=mock(JdbcTemplate.class);var store=new JdbcAuthStore(jdbc);var instant=LocalDateTime.of(2026,10,25,12,30,0,123456789);
  store.touch(8L,instant);verify(jdbc).update(anyString(),eq(instant.withNano(123456000)),eq(8L));
 }
}
