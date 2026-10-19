package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.CreditModels.*;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.repository.CashRepository;
import com.ferreteriahuaman.repository.CreditRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class CreditServiceTest {
    CreditRepository repo = mock(CreditRepository.class);
    CashRepository cash = mock(CashRepository.class);
    BusinessTransactions tx = mock(BusinessTransactions.class);
    CreditService service = new CreditService(repo, cash, tx);
    Identity actor = new Identity(1, "usuario", "Nombre", "Apellido", "VEN", false, Set.of("CRE.VER", "CRE.ABONAR"), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30));

    @Test
    void rejectsInvalidFiltersBeforeQuery() {
        assertThatThrownBy(() -> service.list(actor, "", "ESTADO_INEXISTENTE", null, null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "", null, LocalDate.of(2026, 2, 1), LocalDate.of(2026, 1, 1), 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "", null, null, null, -1, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "a".repeat(101), "", null, null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        verifyNoInteractions(repo);
    }

    @Test
    void validatesPaymentInputs() {
        // Amount <= 0
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.ZERO, "EFECTIVO", UUID.randomUUID(), null, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Cash payment with operation number
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.TEN, "EFECTIVO", UUID.randomUUID(), "123456", null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Yape without operation number
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.TEN, "YAPE", UUID.randomUUID(), null, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Yape with invalid operation number (alphanumeric or short)
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.TEN, "YAPE", UUID.randomUUID(), "12345", null, null, null)))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.TEN, "YAPE", UUID.randomUUID(), "ABC12345", null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Debit with invalid card digits
        assertThatThrownBy(() -> service.registerPayment(actor, "127.0.0.1", new RegisterPayment(1L, BigDecimal.TEN, "DEBITO", UUID.randomUUID(), "OP123", "VISA", "123", null)))
            .isInstanceOf(AuthFailure.class);

        verifyNoInteractions(tx);
    }

    @Test
    void statementThrowsNotFoundWhenClientDoesNotExist() {
        when(repo.customerCredit(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.statement(actor, 99L))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("Cliente no encontrado");
    }

    @Test
    void receiptThrowsNotFoundWhenAbonoDoesNotExist() {
        when(repo.receipt(999L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.receipt(actor, 999L))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("Constancia de abono no encontrada");
    }
}
