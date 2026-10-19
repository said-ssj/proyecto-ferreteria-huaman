package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.ProductModels.BarcodeInput;
import com.ferreteriahuaman.security.AuthFailure;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;
class ProductBarcodeTest {
 @Test void validatesOfficialCheckDigit(){assertThatCode(()->ProductService.validateBarcode(new BarcodeInput("4006381333931","EAN13"))).doesNotThrowAnyException();assertThatThrownBy(()->ProductService.validateBarcode(new BarcodeInput("4006381333932","EAN13"))).isInstanceOf(AuthFailure.class);}
 @Test void rejectsMalformedAndNonPrintableCodes(){for(String value:new String[]{"123","abcdefghijklm","40063813339310"})assertThatThrownBy(()->ProductService.validateBarcode(new BarcodeInput(value,"EAN13"))).isInstanceOf(AuthFailure.class);for(String value:new String[]{" X","X ","X\nY",""})assertThatThrownBy(()->ProductService.validateBarcode(new BarcodeInput(value,"CODE128"))).isInstanceOf(AuthFailure.class);}
 @Test void acceptsInternalPrintableCode(){assertThatCode(()->ProductService.validateBarcode(new BarcodeInput("CLAVO-100G","CODE128"))).doesNotThrowAnyException();}
}
