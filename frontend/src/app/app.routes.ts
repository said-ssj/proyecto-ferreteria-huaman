import {Routes} from '@angular/router';

// Keep the screen catalog and business routes out of the sign-in bundle.
export const routes:Routes=[
 {path:'iniciar-sesion',title:'Iniciar sesión',loadComponent:()=>import('./pages/login').then(m=>m.Login)},
 {path:'',loadChildren:()=>import('./workspace.routes').then(m=>m.workspaceRoutes)}
];
