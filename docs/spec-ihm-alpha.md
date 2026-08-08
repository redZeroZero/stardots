# Spécification — IHM tactique pour l'alpha

## 1. Objet

Cette spécification définit la refonte de l'interface tactique nécessaire avant
une alpha autonome de Stardots.

L'objectif n'est pas de produire une interface visuellement définitive. Il s'agit
de construire un socle de commandement clair, compact et stable permettant à un
joueur qui ne connaît pas le projet de comprendre l'état de la bataille, de
sélectionner rapidement une Task Force ou un bâtiment, de donner ses ordres et de
identifier les causes principales d'un blocage.

Dans Stardots, l'information tactique fait partie du gameplay. Une interface
confuse empêche donc de tester correctement les systèmes de capteurs, de réseau,
de conduite de tir, de thermique, de mouvement et de formation.

Le principe directeur est :

> La carte doit rester l'élément principal de l'écran. L'interface ne montre en
> permanence que les informations nécessaires à la décision immédiate ; le détail
> technique apparaît à la demande ou en fonction de la sélection.

## 2. Objectifs

- Maximiser la surface disponible pour la carte tactique.
- Donner une lecture immédiate de la sélection, des Task Forces, des menaces et
  des capacités d'action.
- Conserver une minimap cliquable réellement utile.
- Permettre de sélectionner une Task Force sans la rechercher sur la carte.
- Permettre de sélectionner directement un bâtiment appartenant à une Task Force
  depuis l'interface.
- Présenter les états importants d'un bâtiment sans mur de texte.
- Séparer clairement information de commandement, commandes fréquentes et détail
  d'inspection.
- Réduire la taille de police et la densité visuelle des panneaux actuels sans
  sacrifier la lisibilité.
- Ne pas exposer en permanence les informations de debug ou de télémétrie fine.
- Fonctionner correctement en mode fenêtré, plein écran et plein écran fenêtré.
- Être utilisable au minimum en 1280 × 720 et confortable en 1920 × 1080.
- Rester compatible avec les mécaniques existantes avant toute refonte graphique
  définitive.

## 3. Hors périmètre

- Direction artistique finale.
- Icônes finales de faction ou illustrations détaillées.
- Animations sophistiquées de panneaux.
- Personnalisation complète et déplacement libre des panneaux par le joueur.
- Refonte des règles de combat, capteurs, réseau, formation ou thermique.
- Tutoriel scénarisé complet.
- Interface de campagne, économie ou construction de vaisseaux.
- Menu principal final.
- Support tactile.

## 4. Principes d'interface

### 4.1 La carte reste prioritaire

L'interface tactique ne doit pas former un cadre lourd occupant les quatre côtés
de l'écran. La carte doit rester visible derrière ou entre des panneaux compacts,
avec une grande zone centrale totalement libre.

À la définition de référence `1920 × 1080`, la majorité de la surface doit rester
consacrée au théâtre. À `1280 × 720`, les panneaux doivent rester utilisables sans
recouvrir une part excessive de la carte.

### 4.2 Trois niveaux d'information

L'information est répartie en trois couches.

#### Commandement — visible en permanence

- objectif et état général de la partie ;
- Task Forces disponibles ;
- minimap ;
- sélection actuelle ;
- alertes importantes ;
- états critiques synthétiques.

#### Contrôle — visible lorsque pertinent

- doctrine de feu ;
- filtre d'armement ;
- posture capteur ;
- formation et espacement de Task Force ;
- commandes liées à la sélection ;
- roster des bâtiments de la Task Force sélectionnée.

#### Inspection — à la demande

- valeurs exactes de portée ;
- signature thermique ;
- détails de tubes, chargeurs et magasins ;
- rôle réseau détaillé ;
- propulsion ;
- états techniques secondaires ;
- télémétrie et informations de debug.

Aucune donnée d'inspection ne doit être affichée en permanence si elle n'est pas
nécessaire à une décision tactique immédiate.

### 4.3 Priorité aux formes et indicateurs courts

Une information tactique importante doit être exprimée en priorité par :

- forme ;
- icône ;
- couleur ;
- barre courte ;
- symbole d'alerte ;
- libellé bref.

Les paragraphes et longues chaînes de texte sont réservés à l'aide ou à
l'inspection détaillée.

### 4.4 Couleur non exclusive

La compréhension principale ne doit pas dépendre uniquement de la couleur. Les
états critiques doivent utiliser une combinaison de couleur, forme et/ou
pictogramme.

### 4.5 Stabilité spatiale

Les principaux panneaux conservent une position stable. Une même information ne
doit pas changer de coin d'écran selon le type de sélection.

Le contenu d'un panneau peut changer, mais son rôle et son emplacement restent
prévisibles.

## 5. Répartition générale de l'écran

Le premier layout de référence utilise cinq zones :

1. bandeau supérieur global ;
2. minimap en haut à droite ;
3. barre ou colonne de Task Forces proche de la minimap ;
4. panneau inférieur de sélection / roster ;
5. inspecteur compact dans la zone inférieure gauche ou à gauche du roster.

Schéma indicatif :

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ objectif / vitesse / alertes                         TF 1 2 3 4   MINIMAP │
│                                                                            │
│                                                                            │
│                                                                            │
│                           CARTE TACTIQUE                                   │
│                                                                            │
│                                                                            │
│                                                                            │
│                                                                            │
├───────────────┬──────────────────────────────────────────────┬─────────────┤
│ INSPECTEUR    │ ROSTER / SÉLECTION                         │ COMMANDES   │
│ compact       │ unités de TF ou sélection multiple         │ contexte   │
└───────────────┴──────────────────────────────────────────────┴─────────────┘
```

Ce schéma fixe les responsabilités, pas les dimensions pixel exactes.

## 6. Bandeau supérieur

Le bandeau supérieur doit rester très fin.

Il peut contenir :

- état de partie ;
- objectif courant ;
- pause / vitesse de simulation ;
- pertes alliées et ennemies synthétiques ;
- quelques alertes critiques ;
- seed ou nom de scénario en petit lorsque utile au test.

Les compteurs détaillés de tirs, impacts, interceptions et autres statistiques ne
sont pas tous nécessaires en permanence. Ils peuvent vivre dans un panneau
repliable ou dans le rapport de bataille.

### 6.1 Alertes

Les alertes permanentes ou temporaires doivent se limiter aux événements exigeant
potentiellement une action :

- missile entrant ;
- Task Force hors liaison ;
- bâtiment critique ;
- munitions principales épuisées ;
- surchauffe bloquant les armes ;
- objectif contesté, capturé ou perdu.

Elles doivent être courtes et ne pas produire un journal textuel continu dans le
bandeau.

## 7. Minimap

La minimap existante est conservée et devient un élément principal du socle IHM.

Elle doit afficher au minimum :

- bâtiments alliés ;
- contacts ennemis connus uniquement ;
- distinction du niveau de renseignement déjà utilisée par la carte ;
- cadre de caméra ;
- limites du théâtre ;
- objectif principal lorsqu'il existe.

### 7.1 Interactions

- clic gauche : recentrer la caméra ;
- glisser gauche : déplacer continuellement la caméra ;
- le comportement droit existant peut être conservé s'il ne crée pas d'ambiguïté ;
- les interactions minimap ne doivent jamais créer un ordre tactique par erreur.

### 7.2 Lisibilité

La minimap doit rester assez grande pour distinguer les formations et contacts.
Elle ne doit pas être réduite au point de devenir décorative.

Ses overlays techniques détaillés ne sont pas permanents. Les portées ou
couvertures ne sont affichées que lorsque la sélection ou un mode dédié le
justifie.

## 8. Barre de Task Forces

Une barre de raccourcis dédiée permet d'accéder directement aux Task Forces du
joueur.

Elle est placée près de la minimap, horizontalement au-dessus ou verticalement à
sa gauche selon le meilleur compromis d'espace lors de l'implémentation.

Chaque Task Force possède une tuile compacte contenant au minimum :

- numéro ou raccourci ;
- nombre de bâtiments vivants ;
- état global synthétique ;
- marqueur d'alerte éventuel.

Exemple :

```text
[1 • 6] [2 • 4 !] [3 • 8]
```

### 8.1 Sélection

- clic sur une tuile : sélectionner la Task Force ;
- double-clic : sélectionner et cadrer la Task Force ;
- les raccourcis clavier associés doivent sélectionner les mêmes objets que la
  tuile ;
- une Task Force détruite ou vide reste soit masquée, soit affichée comme inactive
  sans capturer le raccourci d'une autre TF pendant la partie.

### 8.2 Alertes synthétiques de TF

Une tuile peut signaler au maximum quelques catégories importantes :

- menace missile ;
- rupture de réseau ;
- bâtiment en état critique ;
- munitions offensives épuisées ;
- Task Force hors secteur.

La tuile n'affiche pas toutes les valeurs de chaque membre.

## 9. Panneau inférieur de sélection / roster

Le panneau inférieur central est le cœur de la sélection.

Son contenu dépend du contexte.

### 9.1 Task Force sélectionnée

Le panneau présente tous les bâtiments de la TF sous forme de tuiles ou icônes
compactes.

Chaque tuile doit permettre d'identifier :

- bâtiment / classe ou rôle ;
- état structurel global ;
- chaleur importante ;
- état réseau ;
- capacité offensive générale ;
- menace immédiate éventuelle.

Le but est qu'un joueur puisse repérer le membre problématique sans lire un
texte détaillé.

### 9.2 Sélection d'un bâtiment depuis le roster

- clic sur une tuile : micro-sélectionner ce bâtiment ;
- double-clic : micro-sélectionner et recentrer la caméra ;
- `Ctrl` et/ou `Shift` suivent autant que possible les conventions déjà retenues
  pour la micro et la sélection multiple ;
- l'état réel de sélection du monde et l'état sur le roster doivent toujours être
  identiques.

Une micro-sélection depuis le roster doit déclencher les mêmes règles de Task
Force qu'une micro-sélection sur la carte, notamment le détachement lorsqu'un
ordre individuel l'exige.

### 9.3 Sélection multiple hors Task Force

Le même panneau peut présenter les unités actuellement sélectionnées sans
inventer artificiellement une Task Force.

### 9.4 Sélection individuelle

Lorsqu'une seule unité est sélectionnée, sa tuile reste visible et l'inspecteur
adjacent affiche son résumé détaillé.

## 10. États visuels dans le roster

Les indicateurs exacts pourront évoluer, mais le langage doit rester court et
cohérent.

Première proposition :

- intégrité : petite barre ou contour vert / ambre / rouge ;
- chaleur critique : pictogramme thermique orange ;
- réseau perdu : pictogramme de liaison barré ;
- propulsion gravement dégradée : pictogramme moteur ;
- munitions principales épuisées : pictogramme munition barré ;
- missile entrant : marqueur d'alerte rouge ;
- solution de tir disponible : petit marqueur vert dérivé des crochets déjà
  utilisés sur la carte.

Ces indicateurs doivent rester secondaires par rapport à l'identité du bâtiment.

## 11. Inspecteur contextuel

Les deux grands panneaux actuels doivent être remplacés ou restructurés autour
d'un inspecteur compact unique.

Il ne doit pas présenter toutes les valeurs du `UnitProfile` en permanence.

### 11.1 Vue Task Force

Lorsqu'une TF est sélectionnée, afficher en priorité :

- indicatif / numéro ;
- nombre d'unités ;
- formation ;
- espacement ;
- posture ou état réseau global ;
- posture capteur pertinente ;
- filtre d'armement ;
- doctrine de feu ;
- état synthétique des munitions ;
- éventuel blocage collectif important.

### 11.2 Vue unité

Pour une unité, le résumé visible sans déplier de détail doit rester proche de :

```text
A-01 — FRÉGATE
COQUE       78 %
CHALEUR     41 %
CAPTEUR     PASSIF
RÉSEAU      RELIÉ
PROPULSION  OK
MISSILES    2 / 6
PDC         54
```

Les données exactes peuvent changer selon les systèmes réels, mais cette densité
est la cible : quelques lignes compactes, pas un paragraphe.

### 11.3 Inspection détaillée

Un bouton ou raccourci `DÉTAILS` / `INFOS` ouvre les informations secondaires :

- vitesse et vecteur ;
- portée passive et active ;
- signature IR ;
- rôle réseau ;
- pistes accessibles ;
- tubes, chargeurs et magasins ;
- état thermique détaillé ;
- portée et arcs des armes ;
- données de debug explicitement marquées comme telles.

Ce panneau détaillé doit être repliable.

## 12. Commandes contextuelles

Les commandes fréquentes de la sélection doivent être regroupées dans une zone
stable du bas de l'écran.

Pour une unité ou une TF, les commandes pouvant apparaître comprennent :

- capteurs passif / actif ;
- armement `AUTO / MISSILES / RAILGUN / ANTIRAD` selon disponibilité ;
- doctrine `ÉCONOMIE / SALVE / SATURATION` ;
- formation et espacement d'une TF ;
- rattachement des unités détachées ;
- coupe moteurs lorsque pertinente.

Les raccourcis clavier restent fonctionnels et sont affichés discrètement sur ou
près des commandes correspondantes.

Une commande indisponible doit indiquer pourquoi par tooltip ou court libellé,
pas seulement devenir grisâtre sans explication.

## 13. Aide et onboarding alpha

L'alpha ne nécessite pas encore de tutoriel scénarisé, mais un nouveau joueur doit
pouvoir provoquer volontairement son premier engagement sans lire le README.

Un panneau d'aide compact et repliable doit au minimum expliquer :

1. sélectionner par clic ou cadre ;
2. déplacer avec clic droit ;
3. activer le radar avec `S` si nécessaire ;
4. reconnaître les crochets de solution de tir ;
5. utiliser `A` puis clic pour une mission de feu ;
6. utiliser `W` et `D` pour arme et doctrine ;
7. utiliser la barre de TF et le roster pour naviguer entre formations et
   bâtiments.

Les commandes avancées (`Alt`, micro particulière, debug des portées, etc.)
restent dans une aide secondaire.

## 14. Feedback des blocages

Stardots possède plusieurs raisons valides empêchant un tir ou une action. Le
joueur doit pouvoir comprendre les causes principales sans ouvrir la télémétrie.

Une mission de feu bloquée doit continuer à exposer un motif court, par exemple :

- `PAS DE CONTACT` ;
- `PISTE INSUFFISANTE` ;
- `HORS LIAISON` ;
- `HORS PORTÉE` ;
- `HORS ARC` ;
- `POINTAGE` ;
- `RECHARGEMENT` ;
- `SURCHAUFFE` ;
- `AUCUNE MUNITION`.

Un même vocabulaire doit être utilisé sur la carte, dans l'inspecteur et dans les
commandes.

## 15. Journal d'événements compact

Un journal léger est recommandé pour l'alpha afin de rendre les tests
interprétables.

Il peut être masqué par défaut et afficher les événements tactiques importants :

```text
14:32 BANDIT-03 — piste acquise
14:35 RAIL-02 — solution de tir
14:36 RAIL-02 — tir railgun
14:37 BANDIT-03 — impact
14:38 TF-2 — liaison perdue
```

Le journal n'est pas un log développeur. Il doit rester limité aux événements que
le joueur peut raisonnablement vouloir comprendre après coup.

## 16. Fenêtrage et plein écran

L'alpha doit proposer au minimum :

- mode fenêtré ;
- plein écran ;
- plein écran fenêtré / borderless fullscreen.

Le plein écran fenêtré est le mode recommandé par défaut pour les tests sur
bureau.

Le changement de mode ne doit pas modifier la logique de simulation ni perdre la
sélection.

### 16.1 Résolutions

Les dispositions doivent être validées au minimum en :

- `1280 × 720` ;
- `1920 × 1080` ;
- `2560 × 1440` si disponible lors du test.

Les panneaux ne doivent pas simplement conserver une taille relative gigantesque
sur les grandes définitions. Les textes et icônes doivent rester lisibles sans
occuper inutilement davantage de carte.

Le layout peut utiliser des largeurs maximales et minimales plutôt qu'un
pourcentage fixe de l'écran.

## 17. Typographie et densité

Les textes actuels sont jugés trop gros pour la quantité d'information affichée.
La refonte doit adopter une hiérarchie typographique claire :

- titre / indicatif : légèrement renforcé ;
- valeur tactique : taille normale compacte ;
- libellé secondaire : plus petit ;
- debug : encore plus discret ou masqué.

L'objectif n'est pas de rendre le texte minuscule. Il faut surtout réduire les
marges, répétitions et libellés longs.

Les unités doivent privilégier les abréviations stables lorsque le contexte est
clair : `PASSIF`, `ACTIF`, `RELIÉ`, `ISOLE`, `2/6`, etc.

## 18. Tooltips

Les icônes compactes doivent pouvoir expliquer leur sens au joueur sans forcer un
manuel externe.

Un survol peut préciser :

- nom complet ;
- raccourci ;
- valeur exacte ;
- motif d'indisponibilité ;
- rôle d'un statut inhabituel.

Les tooltips ne doivent pas masquer la carte tant que le pointeur ne reste pas
suffisamment longtemps sur l'élément.

## 19. Architecture recommandée

La refonte ne doit pas renforcer le couplage entre UI et simulation.

Les panneaux lisent des états de présentation ou snapshots et émettent des
intentions de commande. Ils ne doivent pas réimplémenter les règles de capteur,
réseau, armement ou formation.

Les composants recommandés peuvent être séparés en :

- `TopStatusBar` ;
- `MinimapPanel` ;
- `TaskForceBar` ;
- `SelectionRoster` ;
- `SelectionInspector` ;
- `ContextCommandBar` ;
- `EventLogPanel` ;
- ressource ou thème centralisé pour tailles, marges, icônes et typographie.

Les noms exacts sont libres, mais il faut éviter d'ajouter toute la nouvelle IHM
à `src/main.gd`.

### 19.1 Modèle de présentation

Lorsque cela simplifie le code, chaque unité ou TF peut exposer une structure
compacte de présentation calculée à partir de l'état réel :

- état structurel synthétique ;
- chaleur synthétique ;
- réseau ;
- capacité offensive ;
- alerte ;
- munitions ;
- sélection.

Cette structure ne devient pas une nouvelle source de vérité.

## 20. Performance

L'IHM ne doit pas ajouter de traitement coûteux à la simulation à 20 Hz.

- les textes et tuiles ne sont mis à jour que lorsque leur état visible change ou
  à une fréquence d'interface raisonnable ;
- les listes de Task Forces et de roster ne sont pas reconstruites chaque frame
  sans nécessité ;
- les tooltips et détails masqués ne calculent pas leur contenu en continu ;
- les overlays tactiques existants ne sont pas dupliqués uniquement pour alimenter
  les panneaux ;
- l'interface ne parcourt pas toutes les unités ennemies réelles pour afficher une
  information que le joueur ne connaît pas.

Le coût de la refonte doit être mesuré dans le scénario de charge visuelle et une
bataille représentative.

## 21. Livraison incrémentale

### Lot 0 — Contrats IHM

- registre explicite des Task Forces jouables, distinct des groupes de capteurs ;
- état de sélection partagé entre carte, futurs raccourcis TF et roster ;
- snapshots typés d'unité et de Task Force, sans nouvelle source de vérité ;
- causes de blocage typées et vocabulaire commun ;
- politique de présentation exigeant une connaissance joueur explicite ;
- chiffres `1–4` réservés à la sélection des TF et `Maj+1–4` aux formations.

Point de contrôle : ces contrats sont testables sans panneau visible, une
escarmouche dérive ses TF des groupes choisis au déploiement et aucune règle de
capteur ou de réseau n'est déplacée dans l'IHM.

### Lot A — Cadre et densité

- plein écran fenêtré ;
- nouveau layout global ;
- réduction de la typographie et des marges ;
- minimap conservée et correctement repositionnée ;
- remplacement des grands panneaux actuels par un inspecteur compact ;
- aucune nouvelle fonctionnalité de TF requise dans ce premier lot.

Point de contrôle : une bataille reste jouable en `1280 × 720` et `1920 × 1080`
avec nettement plus de carte visible qu'avant.

### Lot B — Barre TF et roster

- tuiles numérotées de Task Forces ;
- clic et double-clic ;
- raccourcis correspondants ;
- roster de la TF sélectionnée ;
- micro-sélection d'un bâtiment depuis le roster ;
- synchronisation stricte entre roster et sélection monde ;
- indicateurs d'état synthétiques.

Point de contrôle : le joueur peut commander plusieurs TF et sélectionner un
membre précis sans le rechercher visuellement sur la carte.

### Lot C — Commandes et compréhension

- commandes contextuelles compactes ;
- affichage cohérent des raccourcis ;
- motifs de blocage ;
- aide alpha repliable ;
- tooltips principaux ;
- vue détaillée `INFOS` séparée de la vue tactique.

Point de contrôle : un joueur connaissant les RTS mais pas Stardots doit pouvoir
sélectionner, déplacer, acquérir une solution de tir et engager une cible sans
consulter le README.

### Lot D — Feedback alpha

- alertes critiques ;
- journal d'événements compact ;
- filtrage des contacts hostiles et de la télémétrie selon les connaissances du joueur ;
- amélioration de la lisibilité des états ;
- validation en bataille chargée ;
- corrections de chevauchements et de redimensionnement.

## 22. Critères d'acceptation

La refonte IHM alpha est acceptée lorsque :

1. la carte reste l'élément visuel dominant à `1280 × 720` et `1920 × 1080` ;
2. la minimap est visible, cliquable et utilisable pour naviguer ;
3. chaque Task Force du joueur est accessible depuis une tuile numérotée ;
4. un clic sur une TF synchronise correctement sélection, roster et inspecteur ;
5. un bâtiment membre d'une TF peut être micro-sélectionné depuis le roster ;
6. la micro-sélection depuis le roster produit le même état que la micro sur la
   carte ;
7. les états critiques d'un bâtiment sont identifiables sans ouvrir le panneau
   détaillé ;
8. l'inspecteur compact n'affiche pas un mur de texte et réserve les valeurs fines
   au mode `INFOS` ;
9. les commandes fréquentes sont visibles et leurs raccourcis identifiables ;
10. un blocage de tir majeur expose une raison compréhensible ;
11. les données de debug ne sont pas visibles par défaut ;
12. le mode plein écran fenêtré fonctionne sans altérer les entrées ni la caméra ;
13. le changement de résolution ne provoque ni superposition majeure ni panneau
    inaccessible ;
14. les contacts cachés ou informations non accessibles ne sont jamais révélés par
    l'IHM ;
15. les tests de sélection, Task Force, caméra et minimap existants restent
    valides ou sont adaptés explicitement au nouveau contrat ;
16. des tests ciblés couvrent au minimum sélection TF par tuile, micro-sélection
    roster, synchronisation de sélection et changement de mode fenêtre ;
17. les scénarios de charge ne montrent pas de régression significative imputable
    à l'actualisation permanente des panneaux.

## 23. Matrice de vérification manuelle

| Situation | Résultat attendu |
| --- | --- |
| aucune sélection | carte dominante, minimap et TF accessibles, inspecteur discret |
| TF sélectionnée | roster complet, résumé TF, commandes collectives |
| unité de TF micro-sélectionnée | unité clairement active, inspecteur unité, TF toujours identifiable |
| unité endommagée | état visible dans le roster sans ouvrir `INFOS` |
| liaison perdue | état réseau immédiatement identifiable |
| missile entrant | alerte visible mais non envahissante |
| mission de feu bloquée | raison courte et cohérente affichée |
| `1280 × 720` | aucun panneau essentiel inaccessible |
| `1920 × 1080` | espace carte accru, panneaux non inutilement agrandis |
| plein écran fenêtré | comportement identique au fenêtré, sans perte d'input |

## 24. Décisions encore ouvertes

- barre TF horizontale ou verticale autour de la minimap ;
- dimensions exactes de la minimap ;
- emplacement exact entre inspecteur et commandes dans la zone inférieure ;
- langage graphique final des pictogrammes ;
- nombre maximal de TF visibles simultanément avant scroll ou pagination ;
- conventions définitives de `Ctrl` / `Shift` pour les sous-sélections depuis le
  roster ;
- contenu exact du journal d'événements ;
- thème visuel final et palette de faction ;
- comportement de l'IHM lorsque le futur modèle de dégâts localisés remplacera le
  pool de coque actuel.

Ces choix ne doivent pas bloquer l'implémentation des responsabilités et
interactions définies dans cette spécification.
