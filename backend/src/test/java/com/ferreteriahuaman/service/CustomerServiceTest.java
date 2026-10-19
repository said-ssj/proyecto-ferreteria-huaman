package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.CustomerModels.*;import com.ferreteriahuaman.repository.*;import com.ferreteriahuaman.security.AuthFailure;import com.fasterxml.jackson.databind.ObjectMapper;import org.junit.jupiter.api.Test;import static org.mockito.Mockito.*;import static org.assertj.core.api.Assertions.*;
class CustomerServiceTest {
 CustomerRepository repo=mock(CustomerRepository.class);CustomerService service=new CustomerService(repo,mock(BusinessTransactions.class),mock(PurchaseRepository.class),new ObjectMapper());
 Input input(String type,String doc,String name,String address){return new Input(type,doc,name,null,null,address,null);}
 @Test void rejectsGenericCustomerAndDocument(){assertThatThrownBy(()->service.validate(input("DNI","00000000","Persona",null))).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.validate(input("DNI","87654321"," CLIENTE VARIOS ",null))).isInstanceOf(AuthFailure.class);}
 @Test void checksTypeLengthAndInvoiceAddress(){assertThatThrownBy(()->service.validate(input("RUC","87654321","Empresa","Dirección válida"))).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.validate(input("RUC","20123456789","Empresa"," "))).isInstanceOf(AuthFailure.class);service.validate(input("RUC","20123456789","Empresa","Dirección válida"));}
 @Test void rejectsInvalidLookupAndPaginationBeforeQuery(){assertThatThrownBy(()->service.lookup("00000000")).isInstanceOf(AuthFailure.class);assertThatThrownBy(()->service.list("","A",-1,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
}
