package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.security.AuthModels.*;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

public interface AuthStore {
    Optional<Account> lockUsername(String username);
    Optional<Account> lockUser(long id);
    Optional<Long> sessionOwner(UUID token);
    Optional<Session> lockSession(UUID token);
    Set<String> permissions(long user);
    int parameter(String key,int fallback,int min,int max);
    void context(String actor,String equipo);
    void failed(Account user,int count,LocalDateTime blocked);
    void resetLogin(Account user,LocalDateTime now);
    void createSession(long user,UUID token,LocalDateTime now);
    void touch(long session,LocalDateTime now);
    void close(long session,String reason,LocalDateTime now);
    void password(long user,String hash);
    void revokeOtherSessions(long user,UUID except,LocalDateTime now);
    void event(Long user,String action);
}
