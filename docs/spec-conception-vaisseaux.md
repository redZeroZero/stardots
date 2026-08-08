# Spécification — Modèle de conception des vaisseaux

## 1. Objet

Cette spécification définit le modèle interne utilisé pour concevoir les classes
de vaisseaux de Stardots et préparer un futur système de dégâts localisés.

Ce système n'est pas destiné à devenir, dans un premier temps, un constructeur de
vaisseaux accessible au joueur. Il sert d'outil de conception pour produire des
classes cohérentes, comparer des architectures et construire les catalogues des
factions avec des règles communes.

Le principe directeur est le suivant :

> Un vaisseau n'est pas un sac de statistiques. C'est une coque de tonnage donné,
> organisée en compartiments fonctionnels, dans lesquels sont installés des
> systèmes physiques.

Le tonnage impose un budget de masse. La coque transforme ce budget en une
architecture. Les modules installés déterminent ensuite les performances réelles.

## 2. Objectifs

- Donner une définition commune et mesurable d'une classe de vaisseau.
- Permettre de construire plusieurs factions avec les mêmes règles physiques sans
  recourir principalement à des bonus arbitraires.
- Faire découler la mobilité, les capteurs, le réseau, la puissance de feu et le
  comportement thermique des systèmes réellement installés.
- Préparer un futur modèle de dégâts localisés où la position interne des systèmes
  compte.
- Autoriser la redondance réelle : plusieurs moteurs, radiateurs, réacteurs,
  magasins ou capteurs peuvent être installés séparément.
- Garder le modèle suffisamment compact pour des batailles pouvant atteindre
  environ 100 bâtiments par camp, en plus des missiles et projectiles.
- Ne pas imposer une simulation interne coûteuse à chaque tick physique.

## 3. Hors périmètre initial

- Constructeur de vaisseau exposé au joueur.
- Simulation détaillée des câbles, conduites, pompes, réseaux électriques ou
  fluides.
- Simulation individuelle de chaque membre d'équipage.
- Compartiments à l'échelle d'une pièce réelle.
- Calcul structurel ou balistique 3D complet.
- Physique orbitale ou budget de delta-v détaillé.
- Carburant et masse réactionnelle tant que leur rôle tactique ou stratégique
  n'est pas défini.
- Valeurs définitives de tonnage, de masse, de volume ou d'équilibrage.

## 4. Tonnage

Le tonnage d'une classe représente sa masse maximale opérationnelle :

- structure ;
- blindage ;
- systèmes ;
- armement ;
- munitions ;
- équipage et soutien-vie ;
- consommables ;
- charge de mission.

La somme de ces masses ne peut pas dépasser le tonnage maximal de la coque.

Le tonnage n'accorde pas directement de vitesse, de portée de capteur ou de
puissance de feu. Une grosse coque n'est donc pas arbitrairement lente : elle est
plus difficile à accélérer parce que sa masse est plus importante. Une faction
peut consacrer une fraction inhabituelle de son tonnage à la propulsion si elle
accepte les sacrifices correspondants.

## 5. Coque

Une `Hull` définit au minimum :

- `max_mass` : tonnage maximal opérationnel ;
- `structural_mass` : masse incompressible de la structure ;
- `internal_capacity` : capacité interne disponible pour les modules ;
- `sections` : découpage fonctionnel avant / centre / arrière, éventuellement
  plus fin sur les grandes coques ;
- `cells` : compartiments fonctionnels et leur topologie ;
- `external_mounts` : emplacements donnant accès à la surface de coque ;
- `axial_mounts` : emplacements réservés aux systèmes nécessitant un axe
  longitudinal ;
- `armor` : protection par face ou section ;
- `geometry` : forme abstraite utile au placement et aux dégâts ;
- `base_signature` : signature minimale éventuelle imposée par la coque.

La structure et le blindage sont des propriétés de la coque ou de ses sections.
Ils ne consomment pas des cellules fonctionnelles séparées.

### 5.1 Formes de coque

La forme peut rester abstraite. Les premières familles envisagées sont :

- `LONG` : coque longue, favorable aux systèmes axiaux et à une forte séparation
  avant/arrière ;
- `WIDE` : coque large, davantage de surface externe et de possibilités de
  redondance ;
- `COMPACT` : coque dense, bonne fraction de masse utile mais concentration plus
  forte des systèmes critiques.

Ces formes ne doivent pas devenir des bonus fixes. Elles doivent surtout modifier
la topologie des cellules et des emplacements compatibles.

## 6. Cellules et sections

Une cellule représente un compartiment fonctionnel abstrait, pas une pièce réelle
ni une quantité fixe de tonnes.

Le nombre de cellules augmente moins vite que le tonnage afin de conserver un
modèle de dégâts lisible et peu coûteux.

Ordres de grandeur provisoires, uniquement destinés à cadrer le niveau de
granularité :

| Tonnage | Cellules internes typiques | Sections typiques |
| ---: | ---: | ---: |
| 300 t | 4 | 2 |
| 600 t | 6 | 2 |
| 1 200 t | 9 | 3 |
| 2 500 t | 14 | 3 |
| 5 000 t | 20 | 4 |
| 10 000 t | 28 | 4 |
| 20 000 t | 38 | 5 |
| 40 000 t | 50 | 5 à 6 |

Ces valeurs sont provisoires et ne constituent pas un équilibrage.

Chaque cellule possède au minimum :

- une section ;
- une position ou un ordre dans la coque ;
- une capacité d'encombrement ;
- une liste de cellules voisines précalculée ;
- des tags de placement éventuels ;
- le ou les modules qu'elle contient ;
- un état utilisé lors de la résolution des dégâts.

La topologie peut être représentée comme un graphe plutôt que comme une vraie
grille. Pour les dégâts, il suffit de connaître l'entrée, les voisins et la
progression possible vers les compartiments suivants.

### 6.1 Tags de placement

Les premiers tags utiles sont :

- `INTERNAL` ;
- `EXTERNAL` ;
- `FORWARD` ;
- `AFT` ;
- `AXIAL`.

Un module peut exiger un ou plusieurs tags. Par exemple :

- radar : accès `EXTERNAL` ;
- moteur principal : accès `AFT` ;
- railgun axial : chaîne d'emplacements `AXIAL` ;
- magasin : `INTERNAL` ;
- radiateur : accès `EXTERNAL`.

## 7. Contraintes de conception

Le constructeur interne doit rester volontairement simple. Une classe de vaisseau
est validée principalement contre cinq ressources :

1. **Masse** : somme de la structure, du blindage, des modules, munitions et
   consommables inférieure ou égale au tonnage maximal.
2. **Encombrement** : somme des modules inférieure ou égale à la capacité interne
   disponible.
3. **Emplacements** : chaque module exigeant une surface, un axe ou l'arrière doit
   être posé sur un emplacement compatible.
4. **Équipage** : la capacité de soutien-vie doit couvrir les besoins des systèmes
   installés.
5. **Puissance** : la production énergétique doit couvrir le fonctionnement prévu
   des systèmes.

Le thermique n'est pas un sixième budget de construction. Les systèmes produisent
de la chaleur ; accumulateurs et radiateurs déterminent la capacité du bâtiment à
l'absorber et l'évacuer.

## 8. Modules

Un élément mérite d'être un module physique lorsqu'il remplit au moins deux
conditions :

- il consomme une part significative de masse ou d'encombrement ;
- sa destruction ou sa dégradation produit un effet tactique intéressant.

Les détails techniques sans conséquence tactique propre restent abstraits dans
le module parent.

### 8.1 Familles fonctionnelles majeures

Le modèle de dégâts et l'interface ne doivent pas multiplier les grandes jauges.
Les modules sont regroupés dans huit familles fonctionnelles :

1. `PROPULSION` ;
2. `POWER` ;
3. `THERMAL` ;
4. `COMMAND` ;
5. `SENSORS` ;
6. `NETWORK` ;
7. `ARMAMENT` ;
8. `CREW`.

Les sous-types conservent leur comportement propre sans créer une famille
supplémentaire. Un magasin missile et un chargeur appartiennent par exemple à
`ARMAMENT` tout en ayant des effets différents lorsqu'ils sont touchés.

### 8.2 Propulsion

La propulsion principale est représentée par un ou plusieurs modules physiques.
Plusieurs moteurs fournissent une redondance réelle : perdre un moteur retire sa
contribution au lieu d'appliquer un malus arbitraire au bâtiment entier.

La propulsion de manœuvre peut rester un seul module abstrait ou un petit nombre
de groupes répartis selon la granularité retenue.

### 8.3 Production d'énergie

Un ou plusieurs réacteurs ou générateurs fournissent la puissance disponible.
Leur perte peut réduire la puissance totale ou provoquer une panne générale si la
classe ne possède aucune redondance.

Le réseau électrique détaillé n'est pas simulé initialement.

### 8.4 Gestion thermique

Deux fonctions physiques sont distinguées :

- **accumulation** : capacité à stocker temporairement la chaleur ;
- **radiation** : capacité à évacuer la chaleur vers l'espace.

Cela permet des architectures différentes : gros radiateurs très efficaces mais
visibles, ou grands accumulateurs capables de soutenir temporairement un régime
silencieux avant une phase de refroidissement.

### 8.5 Commandement

Le CIC et les calculateurs de combat forment le cerveau tactique de la plateforme.
Ils restent distincts du datalink.

La dégradation du commandement pourra affecter l'automatisation, la qualité de la
conduite tactique ou certaines fonctions avancées sans empêcher nécessairement la
plateforme de dériver ou d'utiliser un système local encore intact.

### 8.6 Capteurs

Un radar, une suite IR ou un ensemble de veille passive peut être représenté comme
un module unique. Il n'est pas nécessaire de séparer antenne, amplificateur,
processeur et alimentation tant que ces sous-éléments ne justifient pas un effet
tactique propre.

Un module capteur peut néanmoins être exposé à la surface et donc subir des dégâts
externes avant toute pénétration profonde.

### 8.7 Réseau / datalink

Le datalink reste physiquement distinct du CIC et des capteurs.

Cela autorise notamment :

- capteurs intacts + datalink détruit : plateforme autonome mais isolée ;
- capteurs détruits + datalink intact : plateforme dépendante des pistes reçues ;
- CIC dégradé + réseau intact : données encore reçues mais exploitation limitée.

Les rôles actuels de réception, émission, relais et conduite de tir doivent
pouvoir découler des modules installés.

### 8.8 Équipage et soutien-vie

L'équipage est modélisé par des blocs habités abstraits couvrant quartiers,
atmosphère, eau, nourriture et soutien-vie local.

Chaque module peut annoncer un besoin d'équipage. La somme de ces besoins, plus
un besoin minimal de coque et de commandement, détermine l'effectif nécessaire.

Une faction fortement automatisée peut utiliser des versions de modules demandant
moins de personnel au prix d'autres contraintes de masse, puissance, coût ou
technologie.

Aucun membre d'équipage individuel n'est simulé.

### 8.9 Armement, lanceurs, magasins et chargeurs

Les armes défensives et offensives utilisent la même famille physique.

Un PDC cinétique est une arme avec un magasin. Un laser PDC est une arme dépendant
surtout de la puissance et du thermique. Un missile intercepteur utilise un
lanceur et un magasin comme une munition offensive.

Pour les missiles rechargeables, trois éléments sont physiquement distincts :

- **lanceur** : détermine le nombre de tubes ou cellules prêts et le débit de tir ;
- **chargeur** : assure le transfert depuis la réserve vers le lanceur ;
- **magasin** : contient les munitions de réserve et peut produire des dégâts
  secondaires s'il est atteint.

Cette séparation doit rester compatible avec les notions déjà présentes dans le
prototype : nombre de lanceurs, nombre de chargeurs, capacité de réserve et temps
de chargement.

## 9. Taille des modules

Un module n'occupe pas nécessairement exactement une cellule.

Le système peut utiliser une unité d'encombrement permettant au moins trois ordres
de grandeur :

- petit : environ une demi-cellule ;
- normal : environ une cellule ;
- lourd : deux cellules ou davantage.

Un gros module occupant plusieurs cellules fournit plusieurs points possibles
d'impact et permet une dégradation partielle ou la perte progressive de ses
sous-parties sans exiger une simulation interne détaillée.

La représentation exacte de l'encombrement sera choisie lors de l'implémentation.

## 10. États des modules

Le premier système de dégâts doit privilégier des états discrets plutôt qu'un
pourcentage de points de vie pour chaque composant :

- `INTACT` ;
- `DAMAGED` ;
- `DESTROYED`.

Chaque type de module définit les conséquences de ces états.

Exemples :

- moteur : 100 % / contribution réduite / 0 % ;
- radar : portée normale / portée réduite / aucune détection ;
- chargeur : cadence normale / recharge ralentie / aucune recharge ;
- radiateur : refroidissement normal / réduit / nul pour ce radiateur.

Les capacités globales du bâtiment doivent autant que possible être recalculées à
partir des modules encore opérationnels plutôt qu'être maintenues comme des
pourcentages artificiels indépendants.

## 11. Futur modèle de dégâts localisés

Le pool global de coque actuel pourra être remplacé ou relégué à un rôle
structurel secondaire.

La résolution d'un impact doit suivre une chaîne événementielle :

1. déterminer l'angle d'arrivée et la face touchée ;
2. déterminer le blindage rencontré ;
3. calculer la pénétration restante ;
4. sélectionner la cellule d'entrée ;
5. appliquer les dégâts au module présent ;
6. si l'arme conserve de l'énergie, poursuivre vers la cellule suivante ;
7. appliquer éventuellement fragmentation, incendie ou explosion secondaire aux
   cellules voisines ;
8. recalculer uniquement les capacités affectées.

Les familles d'armes peuvent ainsi obtenir des comportements naturellement
différents :

- railgun : forte pénétration et traversée de plusieurs cellules ;
- missile à fragmentation : dégâts de zone et voisinage ;
- missile pénétrant : faible profondeur puis explosion interne ;
- laser : dégâts localisés surtout sur les systèmes exposés.

Le détail exact des effets secondaires est hors périmètre de cette première
spécification.

## 12. Blindage et orientation

Le blindage appartient à la coque et peut être distribué par face ou par section.

Une classe peut donc consacrer davantage de masse à une protection frontale,
latérale ou arrière. L'orientation tactique devient alors une propriété défensive
réelle, en complément des arcs d'armes et de la cinématique déjà existants.

Une classe orientée railgun peut par exemple investir fortement dans la proue,
tandis qu'un arsenal missile peut préférer une protection homogène plus légère.

## 13. Performance et modèle d'exécution

La richesse du modèle de conception ne doit pas devenir une simulation interne
complète à 20 Hz.

Le principe d'architecture est :

> complexité structurelle élevée, complexité temporelle faible.

### 13.1 Design-time

La définition d'une classe peut contenir :

- tonnage ;
- topologie des cellules ;
- emplacement des modules ;
- masse ;
- puissance ;
- équipage ;
- production et dissipation thermique ;
- armement et munitions.

Ces données sont essentiellement statiques et peuvent être validées lors du
chargement des ressources.

### 13.2 Runtime normal

À chaque tick, le bâtiment ne doit traiter que les systèmes nécessaires aux
mécaniques actives :

- cinématique ;
- chaleur ;
- capteurs ;
- réseau ;
- armes actives ;
- munitions ;
- capacités opérationnelles agrégées.

Les cellules ne doivent pas être parcourues à chaque tick uniquement pour
maintenir leur existence.

### 13.3 Runtime lors d'un impact

La topologie interne est consultée uniquement lorsqu'un événement le justifie :

- impact ;
- pénétration ;
- explosion secondaire ;
- destruction ou réparation future d'un module.

Les listes de voisins et chemins utiles sont précalculés dans la définition de la
coque. La résolution des dégâts doit donc rester locale et événementielle.

Même plusieurs milliers de cellules réparties sur quelques centaines de
bâtiments restent acceptables si elles sont principalement des données dormantes.
Les budgets de performance doivent rester concentrés sur les capteurs, le réseau,
l'IA, le guidage, les collisions et les projectiles.

## 14. Factions

Une faction ne reçoit pas en priorité des bonus globaux du type `+20 % capteurs`
ou `+30 % accélération`.

Elle possède plutôt :

- un catalogue de coques ;
- un catalogue de modules ;
- des technologies plus ou moins compactes, automatisées, puissantes, chaudes ou
  robustes ;
- des doctrines de conception ;
- des préférences de redondance et de blindage.

Deux factions utilisant les mêmes règles peuvent donc produire des bâtiments de
même tonnage aux comportements très différents.

Exemples de philosophies possibles :

- architecture dense, armement important, faible redondance ;
- architecture volumineuse, systèmes séparés et redondants ;
- forte automatisation, petit équipage, électronique coûteuse ;
- forte capacité thermique, petits radiateurs et phases de silence prolongées ;
- gros radiateurs et refroidissement agressif au prix d'une signature élevée.

Les appellations `frégate`, `destroyer`, `croiseur`, etc. restent doctrinales et
ne doivent pas constituer des classes de tonnage universelles.

## 15. Invariants

- Le tonnage est un budget de masse, pas une classe de statistiques.
- Le nombre de cellules ne doit pas croître linéairement avec le tonnage.
- Une cellule est un compartiment fonctionnel abstrait.
- Un module n'existe physiquement que si sa perte mérite une conséquence tactique.
- Structure et blindage appartiennent à la coque, pas à des cellules génériques.
- Les performances doivent découler autant que possible des modules installés.
- La redondance découle de la présence de plusieurs modules physiques.
- Le placement interne doit pouvoir influencer les dégâts futurs.
- Les cellules restent passives hors événements nécessitant leur consultation.
- Aucun changement de ce modèle ne doit imposer un parcours complet des cellules
  de tous les bâtiments à chaque tick physique.

## 16. Ordre de livraison recommandé

### Lot A — Modèle de données de conception

- `HullProfile` ;
- définition des cellules, sections et tags ;
- `ShipModuleProfile` générique ou hiérarchie équivalente ;
- masse, encombrement, équipage, puissance et contraintes de placement ;
- validation d'une classe au chargement ;
- aucune modification du système de dégâts actuel.

### Lot B — Construction de classes existantes

- représenter les bâtiments actuels avec le nouveau modèle ;
- dériver progressivement propulsion, capteurs, datalink, thermique, armes,
  lanceurs, chargeurs et magasins depuis les modules ;
- conserver le comportement joueur actuel ;
- comparer les valeurs dérivées avec les `UnitProfile` existants.

### Lot C — États et dégradation des modules

- états `INTACT`, `DAMAGED`, `DESTROYED` ;
- agrégation des capacités restantes ;
- tests de redondance ;
- aucun modèle de pénétration complexe requis à ce stade.

### Lot D — Dégâts localisés

- sélection de la face et de la cellule touchée ;
- blindage et pénétration ;
- propagation locale ;
- profils d'armes différenciés ;
- suppression progressive du pool de points de vie comme unique modèle de
  survie.

## 17. Critères d'acceptation de la future implémentation

Le modèle sera considéré comme correctement intégré lorsque :

1. une classe de vaisseau peut être décrite par une coque et une liste de modules ;
2. la validation refuse une classe dépassant masse, encombrement, équipage,
   puissance ou contraintes de placement ;
3. les performances principales peuvent être dérivées des modules installés ;
4. plusieurs moteurs, radiateurs ou autres systèmes redondants contribuent
   séparément ;
5. la destruction d'un module retire ou dégrade uniquement les capacités qu'il
   fournit ;
6. les cellules ne sont pas parcourues inutilement à chaque tick ;
7. la topologie interne peut être interrogée localement lors d'un impact ;
8. les anciens scénarios restent jouables pendant la migration ;
9. les tests de charge existants ne montrent pas de régression significative liée
   au simple stockage des cellules et modules ;
10. toutes les valeurs de tonnage et de dimension présentes dans cette
    spécification restent modifiables sans changer l'architecture du système.

## 18. Décisions encore ouvertes

- tonnages de référence réellement utilisés par le premier catalogue ;
- formule ou table finale reliant tonnage, structure et nombre de cellules ;
- granularité exacte de l'encombrement des modules ;
- existence d'une consommation énergétique continue ou seulement de budgets de
  puissance par régime ;
- rôle futur du carburant et de la masse réactionnelle ;
- comportement précis d'un CIC endommagé ;
- règles de pertes d'équipage et de contrôle des avaries ;
- pénétration, fragmentation, incendies et explosions secondaires ;
- réparation éventuelle pendant ou entre les batailles ;
- représentation visuelle ou non de la topologie interne dans l'interface joueur.
