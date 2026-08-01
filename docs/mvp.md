# MVP — cadrage initial

## Promesse

Commander des unités spatiales individuelles dans un espace tactique où la
qualité de l'information détermine la capacité à engager l'adversaire.

Boucle principale :

1. explorer ;
2. détecter un signal ;
3. construire et maintenir une piste ;
4. lancer une arme ;
5. guider ou perdre le missile ;
6. intercepter ou subir l'impact ;
7. contrôler les stations et l'espace utile.

## Périmètre validé

- vue tactique 2D ;
- temps réel, avec pause et accélération en solo ;
- un marqueur représente une unité individuelle ;
- ordres individuels et sélection multiple ;
- une flotte est un groupe de contrôle, jamais une unité fusionnée ;
- deux camps, une carte et une IA simple ;
- deux classes de vaisseaux, un drone et une station au maximum ;
- information partielle par capteurs ;
- missiles et interceptions visibles.

## Hors MVP

- multijoueur Internet et classement ;
- campagne et éditeur de cartes ;
- construction détaillée des vaisseaux ;
- économie complexe ;
- physique orbitale réaliste ;
- guerre électronique avancée ;
- contenu multi-factions.

## Décisions encore ouvertes

- condition de victoire exacte ;
- rôle précis des deux premières classes de vaisseaux ;
- fonctionnement du ravitaillement et des munitions ;
- méthode de maintien et de dégradation des pistes capteurs ;
- échelle temporelle et distances de référence.

Aucune valeur d'équilibrage ne doit être considérée comme définitive pendant
le scaffold.

## Prototype capteur

Le premier modèle technique utilise quatre états de renseignement : invisible,
signal imprécis, piste suivie et unité identifiée. Les seuils de distance et
les portées actuellement présents dans le code sont provisoires et servent
uniquement à valider la lisibilité de cette progression.

## Direction du combat missile

- les missiles utilisent une mise à feu de proximité ;
- dans le vide, la zone dangereuse représente surtout les fragments et
  l'énergie de la détonation, pas une onde de souffle atmosphérique ;
- les dégâts diminuent avec la distance au point de détonation ;
- plusieurs unités proches peuvent être touchées par la même détonation ;
- la défense terminale est automatique, de très courte portée et inspirée des
  systèmes CIWS/PDC ;
- chaque système défensif ne peut traiter qu'un nombre limité de menaces à la
  fois, ce qui permet la saturation ;
- une interception trop tardive peut encore produire des fragments dangereux.

Le premier prototype doit rendre chaque étape visible et éviter les jets de
probabilité cachés : temps passé sous le feu défensif, destruction du missile,
point de détonation et dégâts résultants.

## Objectif du premier scénario

Un relais neutre peut être capturé par la présence incontestée d'au moins une
unité dans sa zone de contrôle. Le relais contrôlé rejoint le réseau de
capteurs de son camp. Une victoire provisoire est accordée après trente
secondes de contrôle continu. Les durées, la portée du relais et la condition
de victoire seront réévaluées après le test de la boucle complète.

## Équilibrage

Les caractéristiques des bâtiments, des missiles et les règles de partie sont
maintenant des ressources éditables dans `data/balance/`. Le fichier
`docs/equilibrage.md` décrit les paramètres et la télémétrie affichée en jeu.

## Déplacement inertiel

La trajectoire et l'orientation de la coque sont séparées. Les bâtiments
accélèrent progressivement, conservent leur vélocité lors d'une rotation et
doivent produire une poussée opposée pour freiner. Une vitesse tactique maximale
reste utilisée comme abstraction afin de conserver une carte jouable.
