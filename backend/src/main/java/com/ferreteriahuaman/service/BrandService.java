package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.constraints.Size;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.util.*;
import javax.imageio.ImageIO;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
@Service @Profile("db")
public class BrandService {
 public record Metadata(String nombre,String logoRuta,boolean usarLogoComoFavicon,LocalDateTime version){}
 public record Change(@Size(max=700000) String imagenBase64,boolean quitarLogo,boolean usarLogoComoFavicon,LocalDateTime version){}
 private final BrandRepository repo;private final SettingsRepository settings;private final BusinessTransactions tx;private final ObjectMapper mapper;
 public BrandService(BrandRepository repo,SettingsRepository settings,BusinessTransactions tx,ObjectMapper mapper){this.repo=repo;this.settings=settings;this.tx=tx;this.mapper=mapper;}
 private Metadata metadata(BrandRepository.Data d){return new Metadata(d.name(),d.hash()==null?null:"/api/identidad-visual/logo/"+d.hash(),d.favicon(),d.version());}
 public Metadata get(){return metadata(repo.get());}
 public byte[] image(String hash){if(!hash.matches("[0-9a-f]{64}"))throw new AuthFailure(404,"Logo no encontrado");var d=repo.get();if(!hash.equals(d.hash())||d.png()==null)throw new AuthFailure(404,"Logo no encontrado");return d.png();}
 byte[] normalize(String encoded){
  if(encoded==null)return null;
  try {
   if(encoded.length()>700000)throw new IllegalArgumentException();
   byte[] bytes=Base64.getDecoder().decode(encoded);
   if(bytes.length==0||bytes.length>524288)throw new IllegalArgumentException();
   try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))){
    var readers=ImageIO.getImageReaders(input);if(!readers.hasNext())throw new IllegalArgumentException();
    var reader=readers.next();
    try{reader.setInput(input,true,true);String format=reader.getFormatName();int w=reader.getWidth(0),h=reader.getHeight(0);
     if(!Set.of("png","jpeg").contains(format.toLowerCase(Locale.ROOT))||w<1||h<1||w>2048||h>2048)throw new IllegalArgumentException();
     var image=reader.read(0);var square=new BufferedImage(256,256,BufferedImage.TYPE_INT_ARGB);var g=square.createGraphics();
     try{g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,RenderingHints.VALUE_INTERPOLATION_BICUBIC);double ratio=Math.min(256.0/w,256.0/h);int nw=Math.max(1,(int)Math.round(w*ratio)),nh=Math.max(1,(int)Math.round(h*ratio));g.drawImage(image,(256-nw)/2,(256-nh)/2,nw,nh,null);}finally{g.dispose();image.flush();}
     var out=new ByteArrayOutputStream();ImageIO.write(square,"png",out);square.flush();return out.toByteArray();
    }finally{reader.dispose();}
   }
  }catch(IOException|IllegalArgumentException e){throw new AuthFailure(400,"Selecciona una imagen PNG o JPG de hasta 512 KB y 2048 × 2048 píxeles");}
 }
 private String json(Object value){try{return mapper.writeValueAsString(value);}catch(Exception e){throw new IllegalStateException("No se pudo preparar la auditoría de identidad visual");}}
 public Metadata save(Identity a,String pc,Change change){
  if(a==null||!"ADM".equals(a.rol())||a.cambioClaveObligatorio()||!a.permisos().contains("CFG.PARAMETROS"))throw new AuthFailure(403,"Solo administración puede cambiar el logo");
  if(change.quitarLogo()&&change.imagenBase64()!=null)throw new AuthFailure(400,"Elige una imagen o quita el logo, no ambas opciones");
  byte[] uploaded=normalize(change.imagenBase64());
  return tx.write(a,pc,"CFG.PARAMETROS",()->{
   repo.lock();if(!settings.admin(a.id()))throw new AuthFailure(403,"Solo administración puede cambiar el logo");
   var before=repo.get();if(!Objects.equals(before.version(),change.version()))throw new AuthFailure(409,"La identidad visual cambió. Recarga antes de guardar");
   byte[] png=change.quitarLogo()?null:uploaded!=null?uploaded:before.png();
   if(change.usarLogoComoFavicon()&&png==null)throw new AuthFailure(400,"Selecciona un logo antes de usarlo como favicon");
   String hash=null;try{if(png!=null)hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(png));}catch(Exception e){throw new IllegalStateException(e);}
   repo.save(png,hash,change.usarLogoComoFavicon());var after=metadata(repo.get());
   settings.audit(a.id(),"CFG.PARAMETROS","identidad_visual",1L,json(metadata(before)),json(after));return after;
  });
 }
}
