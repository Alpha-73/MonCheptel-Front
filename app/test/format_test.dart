import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/theme/format.dart';

void main() {
  group('Fmt.montant', () {
    test('groupe les milliers avec une espace ordinaire', () {
      expect(Fmt.montant(74000), '74 000');
      expect(Fmt.montant(1248), '1 248');
      expect(Fmt.montant(850), '850');
    });

    test('signe moins typographique et signe plus sur demande', () {
      expect(Fmt.montant(-8500), '− 8 500');
      expect(Fmt.montant(60000, signe: true), '+ 60 000');
      expect(Fmt.montant(0, signe: true), '0');
    });

    test('fcfa ajoute la devise', () {
      expect(Fmt.fcfa(48000), '48 000 FCFA');
    });
  });

  group('Fmt.echeance', () {
    test('formule les echeances proches et en retard', () {
      expect(Fmt.echeance(0), "aujourd'hui");
      expect(Fmt.echeance(1), 'demain');
      expect(Fmt.echeance(14), 'dans 14 jours');
      expect(Fmt.echeance(-1), 'en retard de 1 jour');
      expect(Fmt.echeance(-3), 'en retard de 3 jours');
    });
  });

  group('Fmt.initiales', () {
    test('saute le titre Dr', () {
      expect(Fmt.initiales('Dr Aïssata Traoré'), 'AT');
      expect(Fmt.initiales('Mamadou Traoré'), 'MT');
      expect(Fmt.initiales('Administrateur'), 'A');
    });
  });
}
