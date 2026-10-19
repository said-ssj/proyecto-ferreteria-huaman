import {Component,signal,inject} from '@angular/core';
import {RouterOutlet} from '@angular/router';
import {ThemeService} from './core/theme.service';
@Component({selector:'app-root',imports:[RouterOutlet],templateUrl:'./app.html',styleUrl:'./app.scss'})
export class App {protected readonly title=signal('ferreteria-huaman');private readonly theme=inject(ThemeService);}
