import {Component,inject} from '@angular/core';
import {RouterOutlet} from '@angular/router';
import {ThemeService} from './core/theme.service';
import {DisplayPreferences} from './core/display-preferences';
import {BrandService} from './core/brand.service';
@Component({selector:'app-root',imports:[RouterOutlet],templateUrl:'./app.html',styleUrl:'./app.scss'})
export class App {private readonly display=inject(DisplayPreferences);private readonly theme=inject(ThemeService);private readonly brand=inject(BrandService);constructor(){this.brand.load();}}
