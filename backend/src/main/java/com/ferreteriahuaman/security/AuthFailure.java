package com.ferreteriahuaman.security;

public class AuthFailure extends RuntimeException {
    private final int status;
    public AuthFailure(int status,String message){super(message);this.status=status;}
    public int status(){return status;}
    public static AuthFailure credentials(){return new AuthFailure(401,"Usuario o contraseña incorrectos");}
    public static AuthFailure expired(){return new AuthFailure(401,"Tu sesión expiró o ya no está disponible");}
}
