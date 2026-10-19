package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.CashModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.repository.CashRepository;import com.ferreteriahuaman.security.AuthFailure;import com.ferreteriahuaman.security.AuthModels.Identity;import java.time.LocalDate;import java.util.List;import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Service;import org.springframework.transaction.annotation.Transactional;
@Service @Profile("db") public class CashService {
 private final CashRepository repo;private final BusinessTransactions tx;public CashService(CashRepository repo,BusinessTransactions tx){this.repo=repo;this.tx=tx;}
 private void page(int page,int size){if(page<0||page>1000000||size<1||size>100)throw new AuthFailure(400,"Revisa la paginación");}
 @Transactional(readOnly=true) public Current current(){return repo.current();}
 public Register get(long id){return repo.get(id).orElseThrow(()->new AuthFailure(404,"Caja no encontrada"));}
 public Page<Register> history(LocalDate start,LocalDate end,String state,int page,int size){page(page,size);if(!state.matches("ABIERTA|CERRADA|^$")||start!=null&&end!=null&&start.isAfter(end))throw new AuthFailure(400,"Revisa el período y estado de caja");return repo.history(start,end,state,page,size);}
 public Page<Movement> movements(long id,int page,int size){page(page,size);get(id);return repo.movements(id,page,size);}
 @Transactional(readOnly=true) public Page<Movement> currentMovements(int page,int size){page(page,size);var c=repo.current().caja();return c==null?new Page<>(List.of(),0,page,size):repo.movements(c.id(),page,size);}
 public Result open(Identity actor,String pc,Open i){return tx.write(actor,pc,"CAJ.OPERAR",()->new Result(repo.open(i)));}
 public Result manual(Identity actor,String pc,long id,Manual i){return tx.write(actor,pc,"CAJ.OPERAR",()->new Result(repo.manual(id,i)));}
 public Result close(Identity actor,String pc,long id,Close i){return tx.write(actor,pc,"CAJ.OPERAR",()->new Result(repo.close(id,i)));}
}
