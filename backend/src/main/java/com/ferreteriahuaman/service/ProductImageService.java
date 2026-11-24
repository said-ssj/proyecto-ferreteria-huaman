package com.ferreteriahuaman.service;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.repository.ProductImageRepository.Metadata;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.constraints.Size;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.time.LocalDateTime;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.Semaphore;
import javax.imageio.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
@Service @Profile("db")
public class ProductImageService {
 public record Change(@Size(max=2800000) String imagenBase64,boolean quitarImagen,LocalDateTime version){}
 private final ProductImageRepository repo;private final SettingsRepository audit;private final BusinessTransactions tx;private final ObjectMapper mapper;
 private final Semaphore decoders=new Semaphore(2);
 public ProductImageService(ProductImageRepository repo,SettingsRepository audit,BusinessTransactions tx,ObjectMapper mapper){this.repo=repo;this.audit=audit;this.tx=tx;this.mapper=mapper;}
 public Metadata get(long id){return repo.get(id);}
 public byte[] image(long id,String hash){if(!hash.matches("[0-9a-f]{64}"))throw new AuthFailure(404,"Imagen no encontrada");return repo.image(id,hash);}
 byte[] normalize(String encoded){
  if(encoded==null)return null;
  if(!decoders.tryAcquire())throw new AuthFailure(503,"Hay otras imágenes en proceso. Intenta nuevamente");
  try{
   if(encoded.length()>2800000)throw new IllegalArgumentException();byte[] bytes=Base64.getDecoder().decode(encoded);
   if(bytes.length==0||bytes.length>2097152)throw new IllegalArgumentException();
   try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))){
    var readers=ImageIO.getImageReaders(input);if(!readers.hasNext())throw new IllegalArgumentException();var reader=readers.next();
    try{reader.setInput(input,true,true);int w=reader.getWidth(0),h=reader.getHeight(0);
     if(!Set.of("png","jpeg").contains(reader.getFormatName().toLowerCase(Locale.ROOT))||w<1||h<1||w>4096||h>4096)throw new IllegalArgumentException();
     var source=reader.read(0);var square=new BufferedImage(320,320,BufferedImage.TYPE_INT_RGB);var g=square.createGraphics();
     try{g.setColor(Color.WHITE);g.fillRect(0,0,320,320);g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,RenderingHints.VALUE_INTERPOLATION_BICUBIC);double ratio=Math.min(320.0/w,320.0/h);int nw=Math.max(1,(int)Math.round(w*ratio)),nh=Math.max(1,(int)Math.round(h*ratio));g.drawImage(source,(320-nw)/2,(320-nh)/2,nw,nh,null);}finally{g.dispose();source.flush();}
     try{for(float quality:new float[]{.82f,.65f,.5f,.35f}){var out=new ByteArrayOutputStream();var writer=ImageIO.getImageWritersByFormatName("jpeg").next();try(var stream=ImageIO.createImageOutputStream(out)){writer.setOutput(stream);var params=writer.getDefaultWriteParam();params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);params.setCompressionQuality(quality);writer.write(null,new IIOImage(square,null,null),params);}finally{writer.dispose();}if(out.size()<=65536)return out.toByteArray();}throw new IllegalArgumentException();}finally{square.flush();}
    }finally{reader.dispose();}
   }
  }catch(IOException|IllegalArgumentException e){throw new AuthFailure(400,"Selecciona un PNG o JPG de hasta 2 MB y 4096 × 4096 píxeles");}finally{decoders.release();}
 }
 private String json(Object value){try{return mapper.writeValueAsString(value);}catch(Exception e){throw new IllegalStateException(e);}}
 public Metadata save(Identity actor,String pc,long id,Change change){
  if(actor==null||actor.cambioClaveObligatorio()||!actor.permisos().contains("PRO.GESTIONAR"))throw new AuthFailure(403,"No tienes permiso para cambiar imágenes");
  if(change.quitarImagen()&&change.imagenBase64()!=null)throw new AuthFailure(400,"Elige una imagen o quítala, no ambas opciones");
  byte[] image=normalize(change.imagenBase64());
  return tx.write(actor,pc,"PRO.GESTIONAR",()->{
   repo.lock(id);var before=repo.get(id);if(!Objects.equals(before.version(),change.version()))throw new AuthFailure(409,"La imagen cambió. Recarga antes de guardar");
   if(image==null&&!change.quitarImagen())return before;
   String hash=null;try{if(image!=null)hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(image));}catch(Exception e){throw new IllegalStateException(e);}
   repo.save(id,image,hash);var after=repo.get(id);audit.audit(actor.id(),"PRO.IMAGEN","producto_imagen",id,json(before),json(after));return after;
  });
 }
}
