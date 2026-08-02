# Spécification — Lisibilité tactique selon le niveau de zoom

## 1. Objet

Cette spécification définit l'amélioration de la lisibilité du théâtre tactique
lorsque la caméra est éloignée. Elle concerne la représentation visuelle des
unités, contacts, missiles, ordres et informations spatiales. Elle ne modifie
pas les règles de détection, de guidage, de déplacement, de dégâts ou de combat.

Le zoom minimal actuel reste fixé à `0,15`. La vue stratégique doit permettre
d'observer une grande partie du théâtre sans rendre les éléments tactiques
invisibles ou ambigus.

## 2. Constat actuel

Les éléments tactiques sont dessinés dans l'espace du monde. Leur taille et
l'épaisseur de leurs traits diminuent donc avec le zoom de la caméra.

À `0,15`, le corps standard d'une unité, dessiné avec un rayon de 9 unités, ne
mesure plus qu'environ 1,35 pixel à l'écran. Les projectiles, missiles, contours
de sélection et marqueurs de contact deviennent eux aussi difficiles à lire.

La grille conserve par ailleurs un espacement fixe de 64 unités. À grande
échelle, elle forme un bruit visuel dense qui concurrence les informations
importantes.

## 3. Objectifs

- Maintenir chaque contact connu visible sur toute la plage de zoom.
- Permettre de distinguer allié, ennemi et niveau de renseignement sans dépendre
  uniquement de la couleur.
- Conserver une sélection visible et utilisable à `0,15`.
- Rendre les missiles menaçants perceptibles dans les vues tactique et
  stratégique.
- Maintenir les trajectoires, waypoints et cercles de détection nets et
  compréhensibles à tous les niveaux de zoom.
- Préserver la position, les distances, les portées et les trajectoires réelles.
- Réduire progressivement les détails secondaires lorsque la caméra s'éloigne.
- Garder l'interface lisible à la définition de référence `1280 × 720`.
- Ne produire aucun changement dans le résultat de la simulation.

## 4. Hors périmètre

- Modification des portées de détection ou de tir.
- Modification de l'incertitude des contacts.
- Rééquilibrage des unités, missiles ou défenses ponctuelles.
- Nouvelle mécanique de regroupement ou de formation.
- Refonte complète de l'interface de sélection.
- Création d'illustrations détaillées ou d'assets définitifs de faction.

## 5. Principes de représentation

### 5.1 Géométrie du monde

Les positions, routes, zones d'attaque, rayons de capteur, portées de tir et
limites du théâtre restent exprimés dans l'espace du monde. Leur rayon apparent
continue donc de varier normalement avec le zoom.

### 5.2 Symboles tactiques

Les symboles représentant une unité, un contact ou un missile possèdent une
taille minimale à l'écran. Leur taille visuelle peut être compensée en fonction
du zoom, sans changer la transformation, la position ou la collision de l'objet.

La compensation doit être appliquée uniquement au dessin du symbole. Elle ne
doit pas être obtenue en modifiant directement `Node2D.scale`, car cela
affecterait aussi les coordonnées locales des routes et autres tracés.

### 5.3 Épaisseur des traits

Les contours importants doivent conserver une épaisseur visible d'au moins un
pixel écran : sélection, symboles de contact, missiles, direction et bord du
théâtre.

Les cercles de portée restent géométriquement à l'échelle du monde, mais leur
trait bénéficie de cette épaisseur minimale.

### 5.4 Tracés vectoriels adaptatifs

Les trajectoires, segments de route, flèches de cap, cercles de détection et
cercles de portée conservent leurs coordonnées et dimensions dans l'espace du
monde. Seule leur présentation s'adapte au zoom.

Pour chaque tracé, le rendu doit pouvoir ajuster :

- l'épaisseur du trait afin de garantir une largeur minimale à l'écran ;
- l'opacité afin que le tracé reste perceptible sans dominer les unités ;
- la taille écran des waypoints, pointes de flèche et autres marqueurs ;
- le nombre de segments d'un arc selon sa circonférence apparente ;
- le niveau de détail affiché selon la sélection et le niveau de zoom.

Le nombre de segments des cercles est calculé à partir de leur rayon apparent,
avec des bornes minimales et maximales. Un petit cercle éloigné ne doit pas
consommer inutilement autant de segments qu'un grand cercle rapproché, tandis
qu'un grand cercle ne doit pas devenir visiblement polygonal.

L'épaisseur compensée doit rester bornée. Elle ne doit devenir ni invisible à
fort dézoom, ni excessivement large au zoom rapproché.

### 5.5 Information redondante

Les équipes et niveaux de renseignement sont communiqués par la couleur et par
la forme. La compréhension principale ne doit pas dépendre uniquement de la
distinction bleu/rouge/orange.

## 6. Niveaux de détail

Les seuils initiaux sont des paramètres de présentation centralisés. Ils
pourront être ajustés après essai sans modifier les scripts de simulation.

### 6.1 Vue rapprochée — zoom supérieur à `0,65`

La représentation actuelle est conservée :

- silhouette complète du bâtiment ;
- état des tubes lance-missiles ;
- barres de coque et de chaleur ;
- flashs d'impact et tirs de défense ponctuelle ;
- route détaillée de l'unité sélectionnée ;
- cercles de portée demandés par la sélection.

### 6.2 Vue tactique — zoom de `0,28` à `0,65` inclus

La représentation est simplifiée :

- symbole d'équipe avec orientation ;
- contour de sélection renforcé ;
- indication compacte de coque si elle est dégradée ;
- état du contact représenté par sa forme ;
- missiles représentés par un trait orienté très contrasté ;
- tubes, chaleur détaillée et marqueurs secondaires masqués ;
- routes visibles uniquement pour les unités sélectionnées ;
- trajectoires et cercles affichés avec une épaisseur écran stable ;
- waypoints conservés sous forme de marqueurs simplifiés mais lisibles.

### 6.3 Vue stratégique — zoom inférieur à `0,28`

La représentation privilégie la situation générale :

- symbole stable d'au moins 8 pixels de diamètre ;
- sélection d'au moins 14 pixels de diamètre apparent ;
- indicatif court pour les unités sélectionnées et les contacts prioritaires ;
- direction de déplacement simplifiée ;
- missiles hostiles visibles avec une taille minimale de 5 pixels ;
- détails de coque, tubes, chaleur et défense ponctuelle masqués ;
- cercles de portée affichés uniquement sur demande ou sélection ;
- trajectoires réduites à leurs segments essentiels, avec waypoints et flèches
  de cap conservant une taille écran minimale ;
- cercles de détection dessinés avec une opacité renforcée et une épaisseur
  minimale, sans modifier leur rayon réel ;
- contacts superposés différenciés autant que possible sans inventer de
  mécanisme de regroupement.

## 7. Symboles attendus

Les formes exactes pourront être raffinées, mais les distinctions suivantes
sont requises :

| Élément | Forme minimale | Couleur actuelle |
| --- | --- | --- |
| Unité alliée identifiée | chevron ou triangle orienté | cyan |
| Signal ennemi | cercle incomplet ou réticule | jaune |
| Piste ennemie | losange vide | orange |
| Ennemi identifié | triangle ou losange plein orienté | rouge |
| Unité détruite | croix ou symbole barré | gris et orange sombre |
| Missile allié | trait ou pointe orientée | cyan/vert |
| Missile hostile | trait ou pointe orientée | rouge/orange |

Les unités invisibles selon les règles de renseignement restent invisibles. Le
système de niveau de détail ne doit jamais révéler un contact caché.

## 8. Sélection et interaction

- La sélection visuelle reste identifiable sur toute la plage de zoom.
- La zone de clic possède un rayon écran minimal, distinct de la taille physique
  de l'unité.
- Une sélection par rectangle continue de s'appuyer sur les positions réelles.
- Les ordres sont donnés dans l'espace du monde, sans correction liée au niveau
  de détail.
- Le symbole agrandi ne doit pas donner l'impression que l'unité occupe une zone
  physique plus grande.
- Les commandes existantes conservent leur comportement.

## 9. Grille et théâtre

La grille adopte un espacement visuel progressif :

| Niveau | Espacement cible |
| --- | --- |
| Rapproché | 64 unités |
| Tactique | 256 unités |
| Stratégique | 1024 unités |

Les changements de niveau ne doivent pas provoquer un flash brutal. Une grille
secondaire peut diminuer progressivement en opacité pendant que la grille
principale devient visible.

Le bord du théâtre conserve un trait d'au moins un pixel écran et reste visible
à `0,15`.

## 10. Trajectoires et cercles tactiques

### 10.1 Trajectoires et waypoints

- Les lignes de route gardent une épaisseur cible comprise entre 1 et 2 pixels
  écran selon le niveau de zoom.
- Les waypoints gardent un diamètre apparent minimal de 6 pixels.
- La destination active doit être plus contrastée que les points intermédiaires.
- Les flèches de cap final conservent une longueur et une pointe lisibles à
  `0,15`.
- Les routes des unités non sélectionnées restent masquées afin de limiter le
  bruit visuel.
- La simplification visuelle d'une route ne doit jamais déplacer ou supprimer
  un waypoint de simulation.

### 10.2 Cercles de détection et de portée

- Le rayon apparent reste strictement dérivé de la portée réelle et du zoom.
- Le trait garde une épaisseur minimale d'un pixel écran.
- Les couleurs et opacités continuent de distinguer capteur passif, capteur
  actif, liaison de tir, portée missile et défense ponctuelle.
- Au zoom stratégique, l'opacité peut être légèrement renforcée pour compenser
  la diminution apparente, tout en évitant de masquer les contacts.
- Les cercles ne sont affichés que pour la sélection ou lorsqu'une commande
  dédiée le demande.
- Leur tessellation est adaptée au rayon écran afin de conserver une courbe
  régulière avec un coût raisonnable.

### 10.3 Ordre de priorité visuelle

Lorsque plusieurs tracés se superposent, l'ordre de priorité est :

1. menace missile et zone d'attaque active ;
2. symbole et contour de sélection ;
3. trajectoire et destination active ;
4. capteurs et liaison de tir ;
5. portées d'armement et défense ponctuelle ;
6. grille et décor du théâtre.

## 11. Caméra et navigation

Les améliorations suivantes sont prévues après la lisibilité des symboles :

- conserver le point situé sous le curseur pendant le zoom ;
- adoucir légèrement la transition de zoom sans introduire de retard gênant ;
- ajouter une commande pour cadrer toutes les unités alliées vivantes ;
- ajouter une commande pour recentrer la caméra sur la sélection ;
- conserver le déplacement de caméra indépendant de la simulation.

La minimap reste un outil complémentaire. Elle pourra être agrandie après
validation de la vue stratégique, mais ne doit pas compenser une carte principale
illisible.

## 12. Architecture proposée

Les paramètres visuels sont regroupés dans un composant ou une ressource de
présentation, séparé des profils d'équilibrage. Ils comprennent au minimum :

- seuils des trois niveaux de détail ;
- tailles écran minimales des unités, contacts, missiles et sélections ;
- épaisseurs minimales des traits ;
- tailles minimales des waypoints et flèches de cap ;
- règles de tessellation des arcs selon leur rayon écran ;
- espacements de grille ;
- règles de visibilité des détails.

La caméra communique le niveau de zoom courant aux éléments visuels ou déclenche
leur redessin lorsqu'un seuil est franchi. Les nœuds de simulation ne doivent pas
modifier leur état métier en réaction au niveau de zoom.

Une fonction pure détermine le niveau de détail à partir du zoom. Elle doit être
testable sans lancer une partie complète.

## 13. Livraison incrémentale

### Lot A — Taille minimale et contraste

- compensation visuelle des unités et contacts ;
- épaisseur minimale des traits importants ;
- sélection visible et zone de clic adaptée ;
- missiles lisibles à grande distance ;
- trajectoires, waypoints et cercles tactiques lisibles à `0,15`.

Point de contrôle : comparaison en jeu aux zooms `0,15`, `0,28`, `0,42`, `1,0`
et `2,2` avant de poursuivre.

### Lot B — Niveaux de détail

- fonction centralisée de détermination du niveau ;
- trois représentations des unités ;
- formes distinctes pour signal, piste et identification ;
- masquage progressif des informations secondaires ;
- simplification des trajectoires et adaptation de la tessellation des cercles.

Point de contrôle : une capture de chaque niveau avec unités alliées, signal,
piste, ennemi identifié et missile.

### Lot C — Grille et commandes de caméra

- grille adaptative ;
- bord du théâtre à épaisseur stable ;
- zoom centré sur le curseur ;
- cadrage de la flotte et retour à la sélection.

Point de contrôle : navigation complète du théâtre sans recours obligatoire à
la minimap.

### Lot D — Finition et accessibilité

- réduction des superpositions ;
- réglage des couleurs et contrastes ;
- indicatifs contextuels ;
- ajustement éventuel de la minimap ;
- mesure des performances avec davantage d'unités.

## 14. Critères d'acceptation

La fonctionnalité est acceptée lorsque :

1. À `0,15`, chaque unité alliée vivante et chaque contact ennemi non caché est
   visible sur un écran `1280 × 720`.
2. Alliés, signaux, pistes et ennemis identifiés sont distinguables par leur
   forme sans se fier uniquement à la couleur.
3. Une unité sélectionnée reste immédiatement reconnaissable à tous les zooms.
4. Les missiles hostiles sont visibles aux niveaux tactique et stratégique.
5. Les routes et portées restent spatialement exactes.
6. À `0,15`, les routes sélectionnées, waypoints, caps finaux et cercles de
   détection restent continus, contrastés et lisibles.
7. Les traits importants ne descendent pas sous un pixel apparent et les grands
   cercles ne présentent pas de facettes gênantes.
8. Le symbole agrandi n'altère ni position, ni collision, ni portée, ni résultat
   de simulation.
9. La grille ne masque pas les contacts au zoom minimal.
10. Les contacts cachés ne sont jamais révélés par un changement de niveau de
   détail.
11. Les tests existants de simulation continuent de réussir.
12. Des tests automatisés valident les seuils de niveau, les tailles minimales,
    les épaisseurs compensées, la tessellation des arcs et la conservation des
    coordonnées monde.

## 15. Matrice de vérification visuelle

Chaque livraison est contrôlée avec la matrice suivante :

| Zoom | Unités | Contacts | Missiles | Routes et cercles | Sélection | Grille |
| --- | --- | --- | --- | --- | --- | --- |
| `0,15` | visibles | formes lisibles | menace visible | simplifiés et nets | très visible | stratégique |
| `0,28` | visibles | formes lisibles | visible | nets | très visible | tactique |
| `0,42` | simplifiées | lisibles | visible | nets | visible | tactique |
| `1,0` | détaillées | détaillés | détaillés | détaillés | visible | fine |
| `2,2` | détaillées | détaillés | détaillés | détaillés et lisses | visible | fine |

Les contrôles sont effectués au minimum avec une unité alliée sélectionnée, une
unité alliée non sélectionnée, un signal, une piste, un ennemi identifié, un
missile allié et un missile hostile.
