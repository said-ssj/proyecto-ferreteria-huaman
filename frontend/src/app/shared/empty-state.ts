import { Component, input } from '@angular/core';
import { Icon } from './icon';
@Component({selector:'app-empty-state',imports:[Icon],template:`<div class="empty-state" role="status"><div class="empty-icon"><app-icon [name]="icon()"/></div><h3>{{title()}}</h3><p>{{description()}}</p><ng-content/></div>`})
export class EmptyState {readonly icon=input('inbox');readonly title=input('No hay registros');readonly description=input('Los registros aparecerán en esta sección.');}
