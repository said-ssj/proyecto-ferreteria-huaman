import {Component,computed,effect,inject,signal,viewChildren} from '@angular/core';
import {ActivatedRoute,RouterLink} from '@angular/router';
import {toSignal} from '@angular/core/rxjs-interop';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatSelectModule} from '@angular/material/select';
import {MatCheckboxModule,MatCheckbox} from '@angular/material/checkbox';
import {SCREEN_CONTROLS,DOCUMENT_ACTIONS} from '../core/screen-controls';
import {AuthService} from '../core/auth.service';
import {PAGES} from '../core/screens';
import {MatTabsModule} from '@angular/material/tabs';
import {Icon} from '../shared/icon';
import {EmptyState} from '../shared/empty-state';
import {Field} from '../shared/field';
import {Page as PageDefinition} from '../core/screens';
import {ThemeService,THEMES} from '../core/theme.service';
@Component({selector:'app-page',imports:[RouterLink,MatButtonModule,MatFormFieldModule,MatInputModule,MatSelectModule,MatTabsModule,MatCheckboxModule,Icon,EmptyState,Field],templateUrl:'./page.html'})
export class Page {
 readonly auth=inject(AuthService);
 private readonly data=toSignal(inject(ActivatedRoute).data);
 readonly page=computed(()=>this.data()?.['page'] as PageDefinition);
 readonly themes=THEMES;readonly appearance=inject(ThemeService);readonly layout=signal('grid');
 readonly dashboardMetrics=['Ventas del día','Ingresos por ventas','Costo de ventas','Margen bruto'];
 readonly metrics=computed(()=>this.page().path==='reportes/inventario'?['Existencias','Valor del inventario','Entradas','Salidas']:this.page().path==='reportes/caja'?['Ingresos','Egresos','Saldo esperado','Diferencia de caja']:['Total de ventas','Ingresos por ventas','Costo de ventas','Margen bruto']);
 readonly icons=['search','barcode_scanner','add','edit','delete','save','close','check','warning','error','info','print','download','receipt_long','shopping_cart','inventory_2','payments','person_search','calendar_month','filter_alt','view_list','grid_view','lock','visibility','local_shipping','assessment'];
 readonly paletteNames:Record<string,string>={primary:'Acción principal','primary-soft':'Interacción',page:'Página',surface:'Tarjetas',ink:'Texto principal',muted:'Texto secundario',control:'Contorno',focus:'Foco'};
 readonly palette=['primary','primary-soft','page','surface','ink','muted','control','focus'];
 readonly selectedTab=signal(0);
 readonly controls=computed(()=>{const c=SCREEN_CONTROLS[this.page().path]||{};return {...c,actions:c.actions?.filter(a=>this.auth.canAction(this.page().path,a.label))};});
 readonly documentActions=computed(()=>DOCUMENT_ACTIONS[this.page().path] || [{label:'Guardar cambios',icon:'save'}]);
 readonly reportPages=PAGES.filter(p=>p.kind==='reports');
 readonly unitTab=computed(()=>this.page().path==='categorias' && this.selectedTab()===1);
 readonly createTarget=computed(()=>this.unitTab()?(this.auth.can('categorias/unidades/nueva')?'categorias/unidades/nueva':undefined):(this.page().target&&this.auth.can(this.page().target!)?this.page().target:undefined));
 readonly createLabel=computed(()=>this.unitTab()?'Nueva unidad':this.page().action);
 readonly columns=computed(()=>this.unitTab()?['Código SUNAT','Unidad de medida','Magnitud','Equivalencia','Estado','Acciones']:this.page().path==='inventario'&&this.selectedTab()===1?['Fecha','Producto','Tipo de movimiento','Entrada','Salida','Saldo','Responsable']:this.page().columns || ['Registro','Descripción','Estado','Acciones']);
 constructor(){effect(()=>{this.page();this.selectedTab.set(0);});}
 readonly parent=computed(()=>this.page().path==='categorias/unidades/nueva'?'/categorias':'/'+this.page().path.split('/').slice(0,-1).join('/'));
 readonly fields=viewChildren(Field);readonly checks=viewChildren(MatCheckbox);
 resetFilters(form:HTMLFormElement){form.reset();this.fields().forEach(field=>field.reset());this.checks().forEach(check=>check.checked=false);}
}
