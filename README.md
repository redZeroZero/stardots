# Wardots

Prototype de RTS spatial 2D inspiré par la lisibilité de *War of Dots* et par
le combat naval moderne : détection, pistes capteurs, missiles, interception
et contrôle de stations.

## Socle technique

- Godot 4.7.1 stable
- GDScript typé
- simulation à pas fixe de 20 Hz, découplée du rendu
- cible initiale : Windows et Linux

## Lancer le projet

Une copie locale de Godot 4.7.1 stable est installée dans `.tools/godot/`.
Ce dossier est volontairement ignoré par Git.

Pour ouvrir l'éditeur depuis la racine du projet :

```bash
./scripts/godot --editor --path .
```

Pour vérifier le projet sans interface graphique :

```bash
./scripts/godot --headless --path . --editor --quit
```

Pour comparer les trois doctrines de propulsion sans adversaire :

```bash
./scripts/godot --path . -- --propulsion-demo
```

Le scénario sélectionne et cadre automatiquement un bâtiment *flip-and-burn*,
un bâtiment à cap maintenu et un hybride. Leurs routes affichent la fin de
l'accélération (vert), le début du rétrofreinage hybride (cyan), le retournement
(magenta) et le freinage principal (orange). `F` recadre la flotte et `C`
recentre la sélection.

Pour tester le catalogue d'armes et les arcs de tir :

```bash
./scripts/godot --path . -- --weapons-demo
```

Le scénario aligne une escorte PDC, une frégate à missiles moyens, un railgun
axial, un porte-missiles à cellules fixes et un AWACS face à quatre plastrons
fixes et indestructibles. Les unités sont sélectionnées au départ ; `A`, puis
un clic sur une cible, ordonne une salve. Les secteurs colorés tournent avec la
coque.

`W` sélectionne l'armement offensif (`AUTO`, `MISSILES`, `RAILGUN`). `D` change
la doctrine : `ÉCONOMIE` limite l'ordre à un seul tireur, `SALVE` autorise un
tir par bâtiment et `SATURATION` vide tous les tubes et cellules prêts. Les
tourelles doivent atteindre leur cap de pointage avant de tirer.

Pour observer le pilote tactique adverse face à une force bleue contrôlable et
indestructible :

```bash
./scripts/godot --path . -- --ai-demo
```

`RAIL-AI` cherche la bande de portée de son canon axial et présente sa proue ;
`ARSENAL-AI` aligne ses cellules longue portée avant sa salve. `EYE-AI` leur
partage sa conduite de tir. Cette automatisation est activée uniquement pour le
camp IA : les unités bleues continuent de dépendre exclusivement des ordres du
joueur. `FRIG-BLEU` dispose de missiles moyens, `RAIL-BLEU` d'un canon axial et
`EYE-BLEU` leur fournit les pistes nécessaires.

Pour observer la dégradation d'une piste après sa sortie de détection :

```bash
./scripts/godot --path . -- --sensor-demo
```

`CONTACT-01` quitte automatiquement la portée de `SENSOR-01`. Sa dernière
position est propagée selon son vecteur connu, les quatre crochets orange
montrent l'incertitude croissante, puis la piste devient signal avant de
disparaître.

Dans `--ai-demo`, sélectionnez `EYE-BLEU` pour suivre son émission automatique :
silence radio, partage de pistes, puis conduite de tir selon les contacts et les
alliés reliés. Le bandeau renseignement compte aussi les pistes obtenues par
triangulation (`TRI`) et par détection d'une émission (`EM`).

Pour exécuter les tests de charge principaux :

```bash
./scripts/godot --headless --path . --script tests/test_navigation_load.gd
./scripts/godot --headless --path . --script tests/test_battle_load.gd
```

Les décisions de périmètre sont consignées dans `docs/mvp.md`.
Le point de reprise complet de la session du 1er août 2026 est consigné dans
`docs/session-2026-08-01.md`.
