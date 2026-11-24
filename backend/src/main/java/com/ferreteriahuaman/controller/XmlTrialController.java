package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.XmlTrialModels.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.XmlTrialService;import jakarta.servlet.http.HttpServletRequest;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;import org.springframework.http.*;
@RestController @Profile("db") @RequestMapping("/api/xml-pruebas") public class XmlTrialController{
 private final XmlTrialService service;public XmlTrialController(XmlTrialService service){this.service=service;}
 @GetMapping("/estado") public Status status(@AuthenticationPrincipal Identity a){return service.status(a);}
 @GetMapping("/ejemplo") public Preview example(@AuthenticationPrincipal Identity a,@RequestParam(defaultValue="B") String tipo){return service.example(a,tipo);}
 @GetMapping("/ventas/{id}") public Preview preview(@AuthenticationPrincipal Identity a,@PathVariable long id){return service.preview(a,id);}
 @PostMapping("/ventas/{id}/descarga") public ResponseEntity<byte[]> download(@AuthenticationPrincipal Identity a,@PathVariable long id,HttpServletRequest r){return file(service.download(a,r.getRemoteAddr(),id));}
 @PostMapping("/ejemplo/descarga") public ResponseEntity<byte[]> exampleDownload(@AuthenticationPrincipal Identity a,@RequestParam(defaultValue="B") String tipo,HttpServletRequest r){return file(service.downloadExample(a,r.getRemoteAddr(),tipo));}
 private ResponseEntity<byte[]> file(Download d){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).contentType(new MediaType("application","xml",java.nio.charset.StandardCharsets.UTF_8)).header(HttpHeaders.CONTENT_DISPOSITION,"attachment; filename="+d.nombre()).header("X-Document-Mode","LOCAL_SIN_FIRMA").header("X-Document-SHA256",d.sha256()).body(d.contenido());}
}
