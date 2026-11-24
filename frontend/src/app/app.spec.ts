import { Component, signal } from '@angular/core';
import { TitleStrategy, provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { BusinessTitleStrategy } from './core/business-title.strategy';
import { TestBed } from '@angular/core/testing';
import { App } from './app';
import {BrandService} from './core/brand.service';

@Component({ template: '' })
class TestPage {}

describe('App', () => {
  const state = signal({ nombre: 'Mi negocio' });
  beforeEach(async () => {
    state.set({ nombre: 'Mi negocio' });
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [
        { provide: BrandService, useValue: { state, load: () => {} } },
        provideRouter([{ path: 'productos', title: 'Productos', component: TestPage }]),
        { provide: TitleStrategy, useClass: BusinessTitleStrategy },
      ],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(App);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('actualiza el título cuando llega la identidad después de navegar', async () => {
    const originalTitle = document.title;
    try {
      await RouterTestingHarness.create('/productos');
      TestBed.tick();
      expect(document.title).toBe('Productos | Mi negocio');

      state.set({ nombre: 'COOLCAR' });
      TestBed.tick();
      expect(document.title).toBe('Productos | COOLCAR');
    } finally {
      document.title = originalTitle;
    }
  });
});
