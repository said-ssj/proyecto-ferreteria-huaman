import { Component, input } from '@angular/core';
@Component({selector:'app-icon',template:`<span class="material-symbols-outlined" aria-hidden="true">{{name()}}</span>`,styles:`:host{display:inline-flex;vertical-align:middle;flex-shrink:0}.material-symbols-outlined{font-size:24px;line-height:1}`})
export class Icon { readonly name=input.required<string>(); }
