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

## Escarmouche libre

Le lancement normal ouvre une carte vide et le panneau de préparation. Choisissez
le camp, un groupe tactique et l'un des sept bâtiments disponibles, puis cliquez
sur la carte pour le poser. Un bâtiment sélectionné peut être glissé vers une
autre position, tourné par pas de `15°` avec `Q`/`E` ou supprimé avec `Suppr`. Le clic droit
glissé déplace la caméra et la molette conserve le zoom tactique habituel.

Le lancement devient disponible dès que le camp bleu possède au moins un
bâtiment. Sans Rouge, la simulation reste en `TEST LIBRE`, sans IA adverse ni
victoire automatique. Avec les deux camps, Bleu reste sous contrôle manuel,
Rouge est piloté par l'IA et l'annihilation conclut la partie. `REJOUER` relance
exactement la même composition ; `DÉPLOIEMENT` revient à cette composition pour
la modifier.

Les bâtiments d'un même groupe partagent un tableau de pistes commun. Deux
groupes restent disjoints : leurs relèvements passifs ne se triangulent pas et
une piste globale de commandement ne fournit pas à elle seule une solution de
tir ou un guidage missile. Un AWACS peut relier les groupes et leur transmettre
des rapports de piste synthétiques, légèrement moins précis que la piste source.
L'affectation au groupe est conservée par `REJOUER` et `DÉPLOIEMENT`.

La détection commence par comparer les enveloppes spatiales des groupes. La
portée passive nominale garantit la détection d'une coque ordinaire ; sa chaleur
peut l'étendre, tandis qu'une furtivité future devra être un mécanisme explicite.
Les bâtiments de deux régions trop éloignées ne sont jamais comparés individuellement.
Dans une région active, les observations sont condensées directement par groupe
et par cible avant la fusion. Le benchmark dédié se lance avec :

```bash
./scripts/godot --headless --path . --script tests/benchmark_tactical_groups.gd
```

Catalogue disponible : AWACS, escorte laser, escorte cinétique, frégate à
missiles moyens, croiseur railgun, porte-missiles longue portée et frégate
antirayonnement. Les scénarios spécialisés ci-dessous restent accessibles par
leurs options de ligne de commande.

Le clic droit donne un ordre aux unités sélectionnées. `Ctrl` + clic droit
glissé déplace toujours la caméra, même avec une sélection ; l'ancien ordre de
traversée sans arrêt utilise désormais `Alt` + clic droit.

Pour essayer les premières Task Forces élastiques :

```bash
./scripts/godot --path . -- --task-force-demo
```

La démo présente trois TF homogènes de `4`, `6` et `10` frégates. `G` leur donne
simultanément trois routes parallèles identiques afin de comparer leurs
géométries en mouvement. Un clic gauche ou un cadre contenant au moins un membre sélectionne sa TF ;
maintenir `Ctrl` sélectionne seulement les bâtiments visés pour la micro. Le clic
droit déplace la TF sélectionnée ; maintenir le glisser impose aussi son cap
final. `Shift` ajoute un waypoint, `Alt` crée un point traversant, `1–4` changent
la formation sélectionnée et `R` rattache toutes les unités détachées.
Donner un ordre à une seule unité membre la détache automatiquement avant
d'exécuter sa micro. La route et son vecteur final sont dessinés une seule fois
pour la TF ; les petites corrections internes des membres restent masquées. Les
cercles indiquent les emplacements poursuivis et les traits montrent l'erreur de
cohésion, sans déplacer directement les vaisseaux.

La composition mélange maintenant trois frégates `TF-FLIP`, trois
`TF-VECTOR`, un éclaireur hybride et l'AWACS. En mouvement, les membres suivent
la position **et la vitesse** de leur emplacement : les flip-and-burn peuvent
présenter leur moteur principal pour accélérer ou freiner sans transformer
chaque correction en waypoint d'arrêt. Les orientations peuvent donc diverger
pendant la manœuvre ; une fois la TF immobilisée, tous les bâtiments rejoignent
physiquement le cap collectif final.

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
un clic pose une mission de feu de rayon `180`. Elle attend indéfiniment un
contact, une piste, une liaison, une portée et un arc valides, tire une fois,
puis se termine sans déplacer les bâtiments. Une sélection multiple affiche la
veille passive partagée en cyan, l'extension des radars actuellement actifs en
magenta et l'enveloppe orange des armes offensives autorisées par `W`. Une
sélection unique restaure automatiquement les capteurs,
la liaison, les portées minimales et les arcs précis du bâtiment. `V` force ces
détails pour tout un groupe en mode debug.

`W` sélectionne l'armement offensif (`AUTO`, `MISSILES`, `RAILGUN`, `ANTIRAD`).
`D` change la doctrine : `ÉCONOMIE` limite l'ordre à un seul tireur, `SALVE`
autorise un tir par bâtiment et `SATURATION` vide tous les tubes et cellules
prêts. Les tourelles doivent atteindre leur cap de pointage avant de tirer.
Quatre crochets verts autour d'un contact indiquent qu'au moins un bâtiment
sélectionné possède une véritable solution de tir sur sa piste.

La mission mémorise `W`, `D` et les unités affectées lors du clic. Un nouvel
ordre remplace leur mission précédente ; d'autres groupes peuvent conserver
leurs propres zones. `Échap`, hors placement, annule uniquement les missions
des unités actuellement sélectionnées.

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

Pour regarder une bataille entièrement automatique entre deux flottes :

```bash
./scripts/godot --path . -- --fleet-battle-demo
```

La force bleue aligne douze bâtiments en réseau : AWACS, quatre escorteurs,
trois frégates, deux arsenaux et deux chasseurs d'émetteurs. Elle maintient la
distance et priorise les railguns. Les dix raiders rouges combinent un relais
passif, trois railguns, deux frégates, deux escorteurs et deux chasseurs
antirayonnement. Deux groupes d'assaut protégés approchent sur des axes séparés
et cherchent d'abord l'AWACS ; le troisième railgun attend leur première
diversion missile avant d'avancer. Les unités très endommagées se replient.

Le déploiement varie à chaque lancement. Sa graine est affichée en haut et peut
être rejouée exactement, par exemple :

```bash
./scripts/godot --path . -- --fleet-battle-demo --fleet-seed=424242
```

Le bandeau suit les pertes, tirs, impacts et interceptions jusqu'à
l'annihilation. Les autres scénarios gardent le camp bleu sous contrôle manuel.

Le pilote ne vide plus automatiquement les cellules fixes. Avant chaque salve,
il estime les dégâts encore nécessaires, la probabilité de traverser les PDC et
les missiles alliés déjà en vol vers la cible. Les Bleus gardent 25 % de réserve
et les Rouges 15 %. La saturation totale demeure disponible comme ordre humain
explicite avec `D`, mais n'est pas la doctrine automatique de ces flottes.
Le relais rouge reste muet quatre secondes, puis n'ouvre sa liaison que pendant
`1,2 s` toutes les huit secondes. Hors de cette fenêtre, ses pistes ne sont pas
partagées et son indicateur affiche réellement `SILENCE`. Les groupes continuent
néanmoins une approche préplanifiée : perdre la liaison retire l'actualisation
tactique, pas le plan de mission déjà distribué.

Pour tester les blips incertains puis l'apparition d'une solution de tir :

```bash
./scripts/godot --path . -- --sensor-demo
```

`SENSOR-01` et `TIREUR-01` sont sélectionnés face à quatre plastrons fixes et
indestructibles placés dans la couronne de détection imprécise. Ils apparaissent
d'abord comme des blips. Donnez un ordre de rapprochement au groupe avec le clic
droit : les contacts deviennent des losanges, puis reçoivent des crochets verts
quand la frégate possède une solution de tir. `A`, puis un clic sur la formation,
permet alors de lancer ses missiles moyens.

Chaque piste hostile reçoit une désignation stable telle que `BANDIT-01`.
La qualité de localisation et la connaissance du type sont indépendantes :
`BANDIT-01` reste non classifié, `BANDIT-01 — FRÉGATE ?` indique une estimation
et `BANDIT-01 — FRÉGATE` une classification confirmée. Le blip, le losange et
les crochets verts continuent d'indiquer séparément la qualité cinématique et
la possibilité réelle de tirer.

Pour visualiser directement l'effet de la chaleur sur la veille passive :

```bash
./scripts/godot --path . -- --thermal-demo
```

Le radar actif montre d'abord deux coques identiques placées au-delà du cercle
passif cyan. Pressez `S` : la cible froide vieillit puis disparaît, tandis que la
cible chaude reste identifiée par l'infrarouge. Le bandeau affiche en continu
leur signature IR et la portée passive effective correspondante. La cible chaude
refroidit normalement ; elle finit donc elle aussi par sortir de la veille.

Dans `--ai-demo`, sélectionnez `EYE-BLEU` pour suivre son émission automatique :
silence radio, partage de pistes, puis conduite de tir selon les contacts et les
alliés reliés. Le bandeau renseignement compte aussi les pistes obtenues par
triangulation (`TRI`) et par détection d'une émission (`EM`).

Pour comparer une plateforme reliée et une plateforme isolée :

```bash
./scripts/godot --path . -- --network-demo
```

Sélectionnez successivement `RX-01` et `ISOLÉ-01`. Leur fiche indique le rôle
réseau et le nombre de pistes accessibles : le récepteur obtient le contact via
`RELAIS-01`, tandis que la plateforme sans liaison conserve uniquement ses
observations locales.

Pour tester la chasse aux émetteurs :

```bash
./scripts/godot --path . -- --radiation-demo
```

`ARM-01` détecte passivement le radar fixe et indestructible `EYE-CIBLE`.
L'unité est sélectionnée au départ : en `AUTO` ou `ANTIRAD`, pressez `A` puis
cliquez sur la cible. Le missile magenta poursuit l'émission ; si elle disparaît,
il continue vers son dernier relèvement sans recevoir la position réelle.

Pour exécuter les tests de charge principaux :

```bash
./scripts/godot --headless --path . --script tests/test_navigation_load.gd
./scripts/godot --headless --path . --script tests/test_battle_load.gd
```

Les décisions de périmètre sont consignées dans `docs/mvp.md`.
Le point de reprise complet de la session du 1er août 2026 est consigné dans
`docs/session-2026-08-01.md`.
