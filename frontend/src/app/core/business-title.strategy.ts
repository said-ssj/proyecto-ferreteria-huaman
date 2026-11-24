import { Injectable, effect, inject, signal } from '@angular/core';
import { Title } from '@angular/platform-browser';
import { RouterStateSnapshot, TitleStrategy } from '@angular/router';
import { BrandService } from './brand.service';

@Injectable()
export class BusinessTitleStrategy extends TitleStrategy {
  private readonly brand = inject(BrandService);
  private readonly title = inject(Title);
  private readonly pageTitle = signal<string | undefined>(undefined);

  constructor() {
    super();
    effect(() => {
      const page = this.pageTitle();
      const business = this.brand.state().nombre;
      this.title.setTitle(page ? page + ' | ' + business : business);
    });
  }

  override updateTitle(snapshot: RouterStateSnapshot): void {
    this.pageTitle.set(this.buildTitle(snapshot));
  }
}
