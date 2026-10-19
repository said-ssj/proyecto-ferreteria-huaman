import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { provideRouter } from '@angular/router';
import { MAT_RIPPLE_GLOBAL_OPTIONS, MAT_DATE_LOCALE } from '@angular/material/core';
import { MAT_FORM_FIELD_DEFAULT_OPTIONS } from '@angular/material/form-field';
import {provideHttpClient,withInterceptors} from '@angular/common/http';
import {authInterceptor} from './core/auth.service';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    {provide:MAT_DATE_LOCALE,useValue:'es-PE'},
    {provide:MAT_RIPPLE_GLOBAL_OPTIONS,useValue:{disabled:true}},
    {provide:MAT_FORM_FIELD_DEFAULT_OPTIONS,useValue:{appearance:'outline',subscriptSizing:'dynamic'}},
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimationsAsync(),
  ],
};
