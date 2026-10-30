import { Pipe, PipeTransform } from '@angular/core';
import {
  FamilleLibelle,
  formaterDateCourte,
  formaterDateLongue,
  formaterNombre,
  initiales,
  libelle,
  libellesFilieres,
} from '../core/format';
import { Filiere } from '../core/modeles';

/** `{{ 1248 | nombre }}` → « 1 248 ». */
@Pipe({ name: 'nombre' })
export class NombrePipe implements PipeTransform {
  transform(valeur: number | null | undefined, decimales = 0): string {
    return formaterNombre(valeur, decimales);
  }
}

/** `{{ date | dateCourte }}` → « 18 sept. ». */
@Pipe({ name: 'dateCourte' })
export class DateCourtePipe implements PipeTransform {
  transform(valeur: string | Date | null | undefined): string {
    return formaterDateCourte(valeur);
  }
}

/** `{{ date | dateLongue }}` → « 3 août 2026 » ; `dateLongue:false` → « 18 septembre ». */
@Pipe({ name: 'dateLongue' })
export class DateLonguePipe implements PipeTransform {
  transform(valeur: string | Date | null | undefined, avecAnnee = true): string {
    return formaterDateLongue(valeur, avecAnnee);
  }
}

/** `{{ 'ELEVE' | libelle: 'gravite' }}` → « Élevé ». */
@Pipe({ name: 'libelle' })
export class LibellePipe implements PipeTransform {
  transform(code: string | null | undefined, famille: FamilleLibelle): string {
    return libelle(famille, code);
  }
}

/** `{{ ['VOLAILLE','BOVINS'] | filieres }}` → « Volaille, Bovins ». */
@Pipe({ name: 'filieres' })
export class FilieresPipe implements PipeTransform {
  transform(filieres: Filiere[] | null | undefined): string {
    return libellesFilieres(filieres);
  }
}

export const PIPES = [NombrePipe, DateCourtePipe, DateLonguePipe, LibellePipe, FilieresPipe] as const;

/** `{{ 'Balla Kone' | initiales }}` → « BK » (pastille de nom dans les listes). */
@Pipe({ name: 'initiales' })
export class InitialesPipe implements PipeTransform {
  transform(nom: string | null | undefined): string {
    return initiales(nom);
  }
}
