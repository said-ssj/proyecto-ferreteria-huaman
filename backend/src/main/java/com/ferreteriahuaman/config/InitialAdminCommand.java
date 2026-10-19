package com.ferreteriahuaman.config;

import java.io.Console;
import java.util.Arrays;
import com.ferreteriahuaman.service.InitialAdminService;
import com.ferreteriahuaman.service.InitialAdminService.Details;
import org.springframework.boot.*;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
@Profile("db & bootstrap-admin")
public class InitialAdminCommand implements ApplicationRunner {
    private final InitialAdminService service;private final Environment env;
    private final ConfigurableApplicationContext context;
    public InitialAdminCommand(InitialAdminService service,Environment env,ConfigurableApplicationContext context){
        this.service=service;this.env=env;this.context=context;
    }
    @Override public void run(ApplicationArguments args){
        int code=1;char[] password=null;char[] confirmation=null;
        try {
            Console console=System.console();
            if(console==null)throw new IllegalArgumentException("Ejecuta crear-administrador.cmd desde una terminal interactiva de tu equipo");
            Details details=new Details(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO"),
                env.getRequiredProperty("BOOTSTRAP_ADMIN_NOMBRES"),env.getRequiredProperty("BOOTSTRAP_ADMIN_APELLIDOS"),
                env.getRequiredProperty("BOOTSTRAP_ADMIN_DNI"));
            console.printf("Alta inicial del administrador: %s%nNo se reemplazará ningún usuario existente.%n",details.usuario());
            password=console.readPassword("Contraseña (no se muestra): ");
            confirmation=console.readPassword("Confirma la contraseña: ");
            if(password==null||confirmation==null||!Arrays.equals(password,confirmation))
                throw new IllegalArgumentException("Las contraseñas no coinciden o se canceló la operación");
            service.create(details,password);console.printf("Administrador creado correctamente. Ya puedes cerrar esta ventana.%n");code=0;
        }catch(IllegalArgumentException|IllegalStateException failure){System.err.println(failure.getMessage());}
         catch(Exception failure){System.err.println("No se pudo completar el alta. No se muestran datos privados. Revisa la conexión y si ya existen usuarios.");}
        finally {
            if(password!=null)Arrays.fill(password,'\0');if(confirmation!=null)Arrays.fill(confirmation,'\0');
            final int exitCode=code;SpringApplication.exit(context,()->exitCode);
        }
        System.exit(code);
    }
}
