package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.AuditModels.Filter;import java.time.LocalDate;import org.junit.jupiter.api.Test;import org.springframework.jdbc.core.JdbcTemplate;import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
class AuditRepositoryTest {
 @Test void finalDayUsesExclusiveNextMidnight(){var jdbc=mock(JdbcTemplate.class);when(jdbc.queryForObject(anyString(),eq(Long.class),any(Object[].class))).thenReturn(0L);var day=LocalDate.of(2026,10,24);new AuditRepository(jdbc).list(new Filter(day,day,"","","",0,25));verify(jdbc).queryForObject(contains("b.feccre>=? and b.feccre<?"),eq(Long.class),eq(day.atStartOfDay()),eq(day.plusDays(1).atStartOfDay()));}
 @Test void userWildcardsAreBoundAsLiteralText(){var jdbc=mock(JdbcTemplate.class);when(jdbc.queryForObject(anyString(),eq(Long.class),any(Object[].class))).thenReturn(0L);new AuditRepository(jdbc).list(new Filter(null,null,"%_' OR 1=1","SEG.LOGIN","",0,25));verify(jdbc).queryForObject(contains("position(lower(?)"),eq(Long.class),eq("%_' OR 1=1"),eq("SEG.LOGIN"));}
}
