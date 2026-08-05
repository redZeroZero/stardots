# Équilibrage du prototype

Les valeurs de combat modifiables sont regroupées dans `data/balance/`. Les fichiers `.tres` peuvent être sélectionnés dans Godot puis modifiés dans l'Inspecteur.

## Profils disponibles

- `default_unit.tres` : équipage, vitesse tactique, doctrine et capacités de propulsion, accélérations linéaire et angulaire, portée des capteurs, portée et puissance PDC, coque, délai entre deux missiles et capacité du magasin.
- `default_missile.tres` : vitesse, autonomie, guidage terminal, fusée de proximité, dégâts, fragmentation et résistance au PDC.
- `match_rules.tres` : capture du relais, capteur du relais, durée de contrôle nécessaire et cadence de décision de l'IA.

Ces valeurs conservent volontairement les réglages du premier prototype. Leur regroupement ne constitue pas encore un équilibrage réaliste.

## Télémétrie

L'interface affiche pour chaque camp :

- les bâtiments encore opérationnels ;
- les missiles tirés ;
- les missiles ayant atteint la zone de leur cible ;
- les missiles ennemis interceptés par le réseau PDC.

Chaque bâtiment possède désormais un stock limité, des tubes et un nombre de
chargeurs. Un lancement vide un tube ; un chargeur lui transfère ensuite une
munition de la réserve pendant la durée définie dans le profil. L'intervalle de
lancement, plus court, limite séparément la cadence d'une salve.

Les petits anneaux au-dessus du bâtiment représentent les tubes : vert pour un
missile prêt, orange avec une progression pour un chargement en cours et rouge
sombre pour un tube vide. L'inspecteur détaille tubes, chargements, réserve et
stock total ; la télémétrie indique les munitions restantes de chaque flotte.

## Défense ponctuelle cinétique

Le PDC standard est un autocanon et non plus un faisceau à dégâts continus. Il
tire des paquets de projectiles vers une solution d'interception calculée à
partir de la vélocité du missile. Chaque paquet possède une vitesse, une durée
de vie, une dispersion, un rayon de collision et des dégâts. Une rafale ratée
continue donc visiblement dans le vide jusqu'à la fin de sa portée.

Le PDC consomme un stock distinct de munitions. Sa portée, sa cadence, sa
dispersion et ses projectiles sont configurés dans `default_unit.tres`. Un futur
PDC laser utilisera plutôt une puissance continue limitée par la chaleur.

## Profil de vol des missiles

Un missile quitte maintenant son tube à faible vitesse, accélère jusqu'à sa
vitesse d'approche, puis déclenche une poussée plus forte lorsqu'il entre dans
la portée de son autodirecteur terminal. Sa vitesse de rotation est également
plus élevée pendant cette dernière phase, mais reste limitée : une cible qui
change brutalement de vecteur peut donc provoquer un dépassement.

Le profil standard utilise provisoirement une vitesse de lancement de `45`, une
vitesse d'approche de `120` et une vitesse terminale de `250`. Les accélérations,
vitesses de rotation et seuil de phase terminale sont tous modifiables dans
`default_missile.tres`.

## Scénario de test actuel

Le mode de test est temporairement une mission sans relais : `EYE-01`, AWACS
bleu, accompagne les frégates `A-01` et `A-02` contre trois frégates rouges
`BANDIT-01` à `BANDIT-03`. Il sert à observer la veille déportée, les salves de
formation, la défense cinétique mutualisée et l'épuisement des munitions.

## Chaleur et signature passive

Chaque bâtiment possède une capacité thermique. La propulsion, le lancement et
le chargement des missiles ainsi que les tirs PDC produisent de la chaleur. Le
refroidissement passif la réduit en permanence. À partir de 95 % de la capacité,
une sécurité bloque temporairement les armes jusqu'au refroidissement.

La barre fine sous la barre de coque représente la chaleur, du bleu vers le
rouge. L'inspecteur affiche également la valeur et la signature infrarouge.
Cette signature augmente avec la chaleur stockée et connaît un pic pendant une
poussée. Pour une coque ordinaire, elle ne réduit jamais la détection sous la
portée passive nominale : entrer dans cette enveloppe garantit donc la
détection. Une manœuvre propulsée ou une coque chaude reste visible au-delà. Un
futur mécanisme de furtivité explicite pourra abaisser ce plancher profil par
profil sans rendre les bâtiments normaux intermittents.

La démo `--thermal-demo` matérialise cette relation avec deux coques identiques
placées au-delà de la portée nominale. Le bandeau affiche `portée = portée
nominale × signature IR` ; après passage du veilleur en passif avec `S`, seule
la coque chaude reste observée, puis elle disparaît naturellement en
refroidissant.

L'essai du `5 août 2026` amplifie uniquement cette contribution. Une coque froide
ou au régime initial reste à `×1,0`, une coque à pleine chaleur atteint `×2,0`
en régime normal et environ `×2,3` avec ses radiateurs de combat. La combinaison
d'une forte poussée et de la chaleur est plafonnée à `×2,5`. Pour une frégate à
`630`, cela produit des portées de `630`, `1260`, environ `1449` et au maximum
`1575`, soit une avance théorique d'environ `3 à 5 s` à une vitesse de fermeture
de `190 unités/s`. Ces valeurs restent un prototype d'équilibrage ; les vitesses,
portées nominales, radars, armes et dimensions du théâtre n'ont pas changé.

## Contrôle des systèmes

- `X` ou le bouton moteurs coupe immédiatement le plan de poussée sans annuler la vélocité ;
- `S` alterne entre capteur passif et actif ;
- la gestion thermique est automatique.

Le capteur actif porte plus loin et produit directement une piste exploitable,
mais son émission peut être détectée à plus grande distance et génère de la
chaleur. À l'arrêt et en veille passive, le calculateur adopte le régime
silencieux afin de réduire le rayonnement. Un radar actif, un ordre de poussée
ou une dérive significative impose le régime normal. Un lancement de missile,
une menace missile entrante, un tir PDC ou un impact déclenche immédiatement le
régime combat : le refroidissement est maximal, au prix d'une forte signature
de radiateur. Après `6 s` sans menace pour une frégate (`7 s` pour l'AWACS), le
régime adapté aux systèmes et au mouvement revient seul.

## Carte stratégique et minimap

La molette permet maintenant de dézoomer jusqu'à une vue presque complète du
théâtre de `12288 × 12288`. La caméra reste bornée à cette zone. La minimap en haut
à droite affiche les bâtiments amis, le cadre de caméra et uniquement les
contacts ennemis connus, avec une couleur dépendant de leur niveau de
renseignement. Un clic gauche sur la minimap déplace la caméra.

### Hypothèse de prochain agrandissement

Le prochain essai de taille de théâtre visera `24576 × 24576`, soit deux fois la
largeur actuelle et quatre fois sa surface. Avec un radar AWACS actif de `6000`,
son diamètre de couverture représentera alors environ la moitié de la largeur au
lieu de presque tout le théâtre. Les capteurs généralistes, les armes et la
signature thermique resteront ainsi locaux, tandis que les contournements et les
réseaux de groupes disposeront d'une profondeur réellement exploitable.

À `95` unités/s, une traversée complète demanderait environ `4 min 20 s` et un
déplacement tactique de `4000–6000` unités environ `40–65 s`. Le premier test
devra donc conserver des forces initialement séparées de `8000–12000` unités et
essayer un zoom minimal proche de `0,05`. Aucun changement de portée ou de vitesse
ne devra accompagner cet agrandissement. Une carte de `32768 × 32768` restera une
option ultérieure, mais seulement avec des objectifs spatiaux capables d'éviter
de longues périodes de recherche sans décision.

Approcher le pointeur à moins de `18 px` d'un bord de l'écran déplace aussi la
caméra dans cette direction, comme dans un RTS classique. Les coins combinent
les deux axes pour un déplacement diagonal. La vitesse reste adaptée au niveau
de zoom et les flèches du clavier restent disponibles.

Sans unité sélectionnée, maintenir le clic droit et glisser déplace directement
la carte. Avec une sélection, maintenir `Ctrl` pendant le même geste force ce
déplacement sans créer d'ordre. Le déplacement est compensé par le niveau de zoom. Sur la minimap,
le glisser continu fonctionne avec le bouton gauche ou droit. Les contrôles de
l'interface neutralisent le défilement par contact avec le bord afin d'éviter
que les deux gestes se cumulent.

Le rectangle de `12288 × 12288` est maintenant bordé d'un liseré cyan et d'une
bande intérieure translucide : il représente la limite opérationnelle du
théâtre, pas une paroi physique pour les vaisseaux. La caméra y est strictement
bornée. Lorsqu'un bâtiment franchit la limite, son calculateur remplace sa route
par un ordre automatique vers le point le plus proche situé `180` unités à
l'intérieur. Sa position et sa vélocité ne sont pas modifiées : il doit freiner,
tourner et revenir avec sa cinématique normale. Sa fiche signale alors
`HORS SECTEUR • RETOUR AUTO` jusqu'à son arrivée dans la zone sûre.

Cette première télémétrie permettra de comparer des variantes de profils sans se fier uniquement à l'impression visuelle.

## Interface tactique

L'interface est répartie en trois zones compactes : état général en haut, minimap
de `162 × 162` en haut à droite et fiche de la sélection en bas à gauche. La
télémétrie détaillée et le rappel des commandes sont masqués par défaut ; le
bouton `INFOS` ou la touche `I` les affiche. Les commandes principales du
vaisseau sélectionné restent accessibles dans le dock inférieur.

## Veille avancée et solution de tir déportée

Le scénario de test oppose désormais `EYE-01` et deux frégates bleues à trois
bandits rouges, avec environ `2600` unités entre l'AWACS et les contacts initiaux.
`EYE-01` est un bâtiment AWACS sans tube ni munition missile : il conserve
seulement une défense PDC cinétique de courte portée. Ses portées de détection
sont de `2520` en passif, `6000` en actif et `5000` contre une émission active.

Une piste détectée par l'AWACS devient une solution de tir pour un lanceur allié
si celui-ci se trouve dans sa bulle de liaison de `1800`. La piste tactique peut
rester visible en dehors de cette bulle, mais la frégate ne peut alors plus tirer
en s'appuyant uniquement sur l'AWACS. Elle conserve la possibilité de produire
sa propre solution avec ses capteurs. L'anneau vert de l'AWACS représente la
portée de partage ; la fiche affiche l'état de la liaison.

La frégate possède désormais une portée maximale de lancement de `900`, affichée
par un anneau orange lorsqu'elle est sélectionnée. Une solution de tir lointaine
ne suffit donc plus à lancer un missile. Les anneaux de capteurs, de liaison et
d'armement de la sélection sont également reportés sur la minimap.

## Ordres de navigation et d'attaque

Le clic droit est réservé à la navigation et ne déclenche plus jamais un tir.
La touche `A` arme un ordre d'attaque, puis le clic gauche place une zone de tir
de `180` unités. Cette mission reste mémorisée tant qu'aucune cible ne satisfait
ses conditions. Elle capture les unités affectées, l'arme `W` et la doctrine
`D`, puis les réévalue à chaque passe capteur. Le premier engagement valide
consomme la mission après avoir appliqué la doctrine ; aucun mouvement ou
retournement automatique n'est créé.

Le cercle reste cyan sans contact, devient orange lorsqu'un contact est présent
mais attend une piste, une liaison, une portée, un arc, un pointage, des
munitions ou un refroidissement, puis pulse en vert après le tir. Son libellé
indique le blocage. Un nouvel ordre remplace la mission des seules unités
sélectionnées, ce qui permet à plusieurs groupes de conserver des zones
distinctes. `Échap` annule le placement en cours ou, hors placement, les missions
de la sélection. Le changement de mode capteur utilise `S`.

Lors de son exécution, l'ordre fonctionne sur une sélection multiple : chaque bâtiment armé tire au
plus un missile sur le meilleur contact de la zone, tandis que les bâtiments non
armés restent dans le groupe sans générer de tir. Les ordres de déplacement
répartissent une sélection de trois unités en triangle centré autour du point
demandé. Les trois bandits conservent eux aussi des axes d'approche distincts.

## Cinématique des bâtiments

Un bâtiment possède une vélocité et une orientation distinctes. Il doit faire
pivoter sa coque avant d'appliquer efficacement sa poussée principale, conserve
son mouvement pendant la rotation et anticipe son freinage à l'approche d'une
destination. La ligne verte affichée sur une unité sélectionnée représente son
vecteur de vélocité.

Pour un profil habité, l'accélération réellement appliquée est la plus faible
entre la capacité de la propulsion et la limite de sécurité de l'équipage. Un
profil autonome utilise uniquement la limite mécanique de sa propulsion.

## Ordres de navigation

- clic droit : remplace la route, rejoint le point, freine et reprend le cap d'approche ;
- Maj + clic droit : ajoute un waypoint, les points intermédiaires étant traversés sans arrêt ;
- Alt + clic droit : traverse le point sans annuler la vélocité ;
- clic droit puis glisser : l'origine du geste fixe la destination et la flèche fixe le cap final.

Une route sélectionnée est dessinée en cyan. Les waypoints verts sont traversés
et leur cap est automatiquement celui du segment suivant. Une orientation
explicitement demandée ne subsiste donc que sur le dernier waypoint de la route.

Le calculateur effectue une passe arrière sur la route. Il attribue une vitesse
de passage à chaque waypoint selon l'angle du virage, le rayon préféré,
l'accélération disponible et la longueur du segment suivant. Le pilote commence
ensuite sa transition vers le vecteur de sortie avant d'atteindre le point. La
vitesse planifiée du prochain waypoint apparaît dans l'inspecteur de sélection.

Le cap de coque suit la tangente de la route et reste stable sur un segment
rectiligne. L'accélération, le freinage et l'annulation de dérive utilisent les
propulseurs de manœuvre dans la limite d'accélération du profil, sans retourner
le bâtiment à chaque correction de vitesse. À un waypoint, la coque anticipe
progressivement le cap du segment sortant. Ce cap simulé pourra servir
directement de référence aux futurs arcs de tir.

## Propulsion et doctrines technologiques

Les capacités sont stockées dans des ressources `PropulsionProfile` réutilisables
par plusieurs classes de bâtiment. Les profils actuellement disponibles sont
`main_drive`, `vector_drive`, `hybrid_drive` et `awacs_vector_drive`. Chaque
profil sépare les capacités matérielles de la doctrine du pilote. Les
coefficients de poussée avant, rétrograde et latérale décrivent le matériel sans
l'associer encore à une faction. Trois doctrines sont disponibles :

- `FLIP_AND_BURN` aligne la coque sur les accélérations importantes et effectue
  un retournement stable pour exploiter le moteur principal au freinage ;
- `HOLD_ATTITUDE` maintient le cap de route et s'appuie sur les propulseurs
  rétrogrades et latéraux ;
- `HYBRID` commence par rétrofreiner en maintenant son cap, puis effectue un
  retournement plus tardif si le moteur principal reste nécessaire. Le ratio de
  vitesse au retournement est réglé par `hybrid_turn_speed_ratio`.

Le profil standard conserve provisoirement `HOLD_ATTITUDE` avec une poussée
vectorielle complète. Ces valeurs servent de socle technique et ne définissent
aucune technologie ou identité de faction définitive.

Chaque segment de route possède désormais un plan de vol mis en cache. Il
calcule à la réception de l'ordre les phases `ACCÉLÉRATION`, `CROISIÈRE`,
`RÉTROFREINAGE`, `RETOURNEMENT` et `FREINAGE`. Pour un flip-and-burn, le début du retournement
inclut la durée nécessaire pour faire pivoter la coque avant le point de
freinage. Pour un hybride, le plan réserve d'abord la distance nécessaire au
rétrofreinage, puis calcule le flip à vitesse réduite. Le plan n'est recalculé
que lorsqu'une route ou un segment change.

Le benchmark headless de navigation sur 400 ticks mesure environ `0,44 ms` par
tick pour 100 unités, `1,30 ms` pour 250 et `2,92 ms` pour 500 sur la machine de
développement. Après branchement du pilote tactique, le benchmark de bataille
complète mesure environ `42,4 ms` par tick pour 500 unités et 50 missiles,
capteurs, IA et PDC inclus. Les missiles sont indexés spatialement pour la
défense proche et la signature thermique d'une cible n'est calculée qu'une fois
par passe capteur.

## Pistes capteurs fusionnées

Chaque camp conserve désormais une seule `SensorTrack` par contact. Une
observation proche fournit position et vecteur précis ; après perte du capteur,
le calculateur propage ce dernier vecteur, réduit progressivement la confiance
et augmente l'incertitude selon l'accélération possible de la cible. Le contact
rétrograde d'identification à piste, puis signal, avant de disparaître. Une
incertitude supérieure à `45` unités ne constitue plus une solution de tir.

Les symboles de piste et de signal sont placés sur la position estimée plutôt
que sur la position réelle. Un signal utilise uniquement son blip pulsant et une
piste uniquement son losange orange : aucun halo ou crochet orange supplémentaire
ne se superpose. Railguns et missiles reçoivent également cette position estimée ;
un missile conserve la dernière information partagée jusqu'à son éventuelle
acquisition terminale. Le scénario `--sensor-demo` permet de comparer ces états
sur une formation fixe puis de provoquer une solution de tir par rapprochement.

La passe à `5 Hz` traite les deux camps simultanément : la distance d'une paire
bleu/rouge n'est calculée qu'une fois, puis sert aux deux directions de
détection. Le vieillissement entre deux passes reste linéaire dans le nombre de
pistes existantes.

Les capteurs passifs exploitent maintenant deux signatures distinctes : la
chaleur et les émissions radio. Un radar actif, un partage de pistes AWACS et
une liaison de conduite de tir rendent automatiquement leur porteur détectable,
avec une intensité propre au profil du bâtiment. L'AWACS reste silencieux sans
allié relié, partage ses pistes dès qu'il possède un contact et passe au flux de
conduite de tir lorsqu'une arme alliée peut exploiter une solution précise.

Deux observateurs passifs qui voient le même contact combinent leurs
relèvements. Un angle de croisement suffisant transforme un signal lointain en
piste, avec une incertitude qui diminue lorsque la géométrie s'améliore. Le
bandeau résume ces origines par `TRI` et `EM`, sans ajouter de nouveaux anneaux ;
la fiche d'une unité sélectionnée affiche son niveau et son régime d'émission.

La frégate généraliste utilise désormais une veille passive garantie de `630`,
un radar actif de `1800` et une détection d'émissions de `1400`. Avec les seuils
actuels, son radar produit une piste jusqu'à `1224` et une identification jusqu'à `648` :
elle peut donc opérer seule à portée réduite sans exploiter automatiquement les
`900` unités de ses missiles moyens. Sa liaison standard est un transceiver de
`1200` sans capacité de relais ni conduite de tir dédiée. Deux frégates reliées
peuvent partager la piste précise produite par l'une d'elles, mais ne peuvent pas
propager une piste reçue vers un troisième saut.

Le porte-missiles longue portée constitue l'exception volontairement dépendante
du réseau. Il conserve `378` en passif, `1008` en actif, `720` contre les émissions
et une liaison de réception seule. L'AWACS utilise `2520/6000/5000` et
demeure nécessaire pour exploiter les engagements profonds et relayer la flotte.

### Piste de conception — classification et illumination directionnelle

Décision à prototyper lors de la prochaine session : séparer explicitement la
qualité cinématique d'une piste de la connaissance du type de cible. Une
détection passive devrait révéler rapidement le rôle ou la classe du contact,
tout en conservant une position incertaine. Le joueur pourrait ainsi reconnaître
un AWACS ou un arsenal sans disposer immédiatement d'une solution de tir.

Le premier socle est implémenté : chaque piste de commandement reçoit une
désignation `BANDIT-XX` stable pendant sa durée de vie. La classification possède
désormais ses propres états `INCONNU`, `ESTIMÉ` et `CONFIRMÉ`, transmis dans les
rapports de groupe sans modifier la confiance cinématique ni l'incertitude. Un
simple signal radio reste non classifié ou estimé selon sa qualité. Une cible
dans la portée thermique passive effective est directement identifiée et
affichée comme vaisseau ; l'observation active rapprochée produit le même niveau
de connaissance. Les profils d'unité exposent séparément leur classe capteur.

La visualisation utilise trois représentations exclusives : blip jaune-orangé
pour un signal, losange orange stable pour une piste et silhouette complète pour
une identification. Les crochets verts de conduite de tir restent temporairement
affichés en permanence afin d'évaluer leur utilité. Leur marge demeure constante
en pixels autour du symbole à tous les zooms, y compris lorsque la coque grandit
en vue rapprochée.

Pour un bâtiment non spécialisé, le radar actif devrait probablement être
directionnel. Son secteur suivrait l'orientation du bâtiment ou une direction
d'illumination ordonnée, ce qui permettrait de rechercher et confirmer un
contact inconnu sans éclairer tout l'espace autour de la formation. Un AWACS ou
un bâtiment de veille dédié pourrait conserver une couverture omnidirectionnelle
ou beaucoup plus large. Aucun angle, temps de balayage ou coût thermique n'est
encore fixé.

Afin d'éviter le micromanagement, cette capacité devrait être pilotée au niveau
du groupe par une doctrine (`SILENCE`, `DISCRET`, `IDENTIFICATION`, `COMBAT`) ou
par un ordre ponctuel « identifier ce contact ». Le groupe choisirait alors
automatiquement le capteur, l'orientation et la durée d'émission appropriés.

## Systèmes d'armes et emplacements

Un angle de `0°` regarde la proue, `-90°` bâbord, `90°` tribord et `180°` la
poupe. Cinq ressources de montage servent de choix initiaux :

- batterie avant fixe : secteur de `60°` ;
- bordées bâbord et tribord : secteurs de `120°` ;
- batterie arrière fixe : secteur de `60°` ;
- tourelle : couverture `360°` et vitesse de rotation configurable.

Chaque profil peut devenir `CUSTOM` en réglant son centre, sa largeur, son
caractère fixe ou traversable et sa vitesse de rotation. Les arcs tournent avec
la coque et bloquent réellement un tir hors secteur ; la distance minimale est
également appliquée. L'interface indique si un ordre échoue faute d'arc, de
portée, de piste ou de disponibilité.

### Enveloppe d'engagement agrégée

En sélection multiple, chaque groupe partageant le même fournisseur de conduite
de tir affiche trois contours : la veille passive garantie en cyan, l'extension
des radars actuellement actifs en magenta et l'engagement orange. Chaque
enveloppe capteur réunit uniquement les bâtiments capables de transmettre leurs
propres observations au groupe. L'engagement exclut PDC et intercepteurs, puis
suit le filtre `W` : toutes les armes offensives en `AUTO`, antinavires, railgun
ou antirayonnement. Une perte de liaison sépare immédiatement les îlots.

Une sélection unique restaure automatiquement le détail technique : capteur
passif, radar actif, liaison, portée minimale, secteur de montage et cap de
tourelle. `V` force ce diagnostic sur une sélection multiple. Au-delà de 32
bâtiments dans un même groupe, l'affichage normal utilise une coque convexe
simplifiée afin de borner le coût géométrique. Les munitions épuisées sont
exclues de l'enveloppe ; un réticule vert n'apparaît sur une cible que si une
vraie piste de qualité conduite de tir est accessible.

Les surfaces utilisent les secteurs convexes d'origine, avec une opacité qui
augmente dans les recouvrements. Seuls leurs contours booléens sont fusionnés :
cela évite les erreurs de triangulation des unions concaves tout en laissant
lire la redondance de couverture.

Le catalogue initial contient huit `WeaponSystemProfile` : PDC cinétique
fragmentant, PDC laser, missile intercepteur court, tubes antinavires moyens,
cellules antinavires fixes, cellules longue portée, cellules antirayonnement et
railgun axial moyen. Les tubes utilisent un magasin ; les cellules offrent une
forte cadence initiale,
mais chaque départ consomme définitivement une cellule. Le laser consomme de la
chaleur plutôt que des munitions. Les défenses attaquent automatiquement les
menaces entrantes ; railgun et missiles antinavires répondent à l'ordre de zone.

La sélection offensive utilise `W` pour autoriser automatiquement toutes les
armes, uniquement les missiles antinavires, uniquement les railguns ou
uniquement les missiles antirayonnement. La doctrine utilise
`D` : `ÉCONOMIE` arrête l'ordre après le premier tir de la formation, `SALVE`
autorise un tir par bâtiment, et `SATURATION` déclenche toutes les armes et
cellules prêtes. Une batterie fixe suit toujours la coque. Une tourelle conserve
un cap relatif indépendant, poursuit son point de visée à la vitesse configurée
et ne tire qu'une fois dans sa tolérance angulaire. Sa direction instantanée est
dessinée à l'intérieur de son enveloppe de rotation.

Le projectile railgun reste visible jusque dans la vue stratégique : sa traînée
conserve au moins `8 px` et sa tête `3,5 px` à l'écran. Le dézoom renforce
légèrement son contraste sans modifier sa trajectoire ni sa collision.

Une saturation n'empile plus les projectiles sur une trajectoire unique. Le
calculateur attribue des couloirs latéraux espacés de `52` unités et distribue
les missiles à tour de rôle entre toutes les cibles valides de la zone. Les
couloirs convergent au passage en guidage terminal. La fusée de proximité reste
désarmée pendant les `55` premières unités de vol, ce qui protège le lanceur et
la formation au départ de la salve.

Le missile antirayonnement exige un relèvement radio récent plutôt qu'une
solution de tir conventionnelle. Son autodirecteur passif acquiert une source
selon sa puissance et sa portée de réception, puis met à jour sa route tant que
l'émission persiste. Une extinction lui retire l'accès à la position réelle :
il poursuit vers le dernier relèvement et peut reprendre la cible si elle
recommence à émettre. `--radiation-demo` fournit un chasseur `ARM-01` et un radar
fixe, actif et indestructible pour vérifier ce comportement.

## Réseau de données tactique

Une plateforme physique reste une unité indépendamment de sa connectivité. Son
`UnitProfile` peut référencer un `DataLinkProfile` optionnel qui décrit quatre
capacités composables : recevoir, transmettre, relayer et fournir une conduite
de tir. Sans profil, l'unité est isolée mais reste sélectionnable, mobile et
armée ; elle n'exploite que ses propres observations.

La frégate standard reçoit et transmet ses observations, sans les relayer.
L'AWACS reçoit, émet,
relaie sur plusieurs sauts et certifie les solutions de tir dans une portée de
`1800` unités. Les liens sont directionnels : la portée appartient à l'émetteur
et un transceiver sans capacité de relais ne propage pas un paquet reçu. Les
armes et le pilote IA consultent le tableau de pistes de leur groupe tactique.
La vue générale du joueur reste une synthèse de commandement, mais elle ne
fournit plus implicitement une solution de tir à tous les bâtiments.

Les groupes tactiques forment des domaines de fusion disjoints : deux capteurs
de groupes différents ne triangulent donc pas directement leurs relèvements.
Un profil de liaison doté de `can_bridge_groups` — actuellement l'AWACS — peut
faire circuler des `TrackReport` synthétiques entre ces domaines. Le rapport
conserve l'état, la position estimée, le vecteur et la provenance, avec une
petite pénalité d'incertitude ; il ne transporte pas les observations brutes.

Les missiles restent des munitions non sélectionnables, mais mémorisent le
groupe de leur lanceur comme domaine de guidage. Ils ne peuvent plus exploiter
une piste globale inaccessible à ce groupe.

La passe capteur utilise maintenant la topologie locale avant le détail des
plateformes. Elle compare d'abord les rectangles occupés par les groupes,
élargis par leur plus grande portée effective. Seules les paires de groupes dont
les régions peuvent se détecter descendent au niveau bâtiment contre bâtiment.
Chaque observation est immédiatement ajoutée à un accumulateur `(groupe,
cible)` qui ne conserve que les meilleurs rapports et la géométrie utile à la
triangulation.

Avec 500 bâtiments répartis en 20 groupes de 25, le benchmark mesure environ
`59 ms` par passe capteur sans commandement et `99 ms` avec quatre AWACS, soit
environ `15` et `25 ms` amortis par tick physique. Le cas artificiel où tous les
groupes sont superposés reste un stress test coûteux, pas la topologie de
référence du jeu.

`--network-demo` aligne un émetteur, un AWACS relais, un récepteur et une
plateforme isolée face à un contact fixe. La fiche de sélection affiche le rôle
du nœud et le nombre de pistes réellement accessibles.

## Task Forces et formations physiques

Une Task Force regroupe normalement de `2` à `10` bâtiments. Une TF réduite à
un seul survivant continue d'exister jusqu'à sa dissolution ou sa fusion, mais
une nouvelle TF demande au moins deux unités. Le plafond compte les bâtiments
de combat, de commandement et d'appui, y compris ceux temporairement détachés.
Un centre de commandement fixe reste en revanche un actif du théâtre et non un
membre d'une formation mobile.

Le choix de formation sépare deux axes : la forme `LIGNE` ou `ESSAIM`, puis
l'espacement `SERRÉ` ou `LÂCHE`. La ligne attribue des emplacements ordonnés par
rapport à un front et un cap. L'essaim organise les bâtiments autour d'un centre
sans leur imposer un rang rigide. L'espacement modifie les distances physiques,
pas les caractéristiques des unités.

La formation n'accorde aucun bonus abstrait. Ses conséquences proviennent
uniquement de la géométrie et des systèmes existants : arcs de tir, recouvrement
des défenses, portée des capteurs et des liaisons, exposition, inertie et temps
nécessaire pour changer de place. Une ligne serrée, une ligne lâche, un essaim
serré et un essaim lâche doivent donc produire des situations différentes sans
modificateur caché.

Chaque unité possède également un statut physique dans sa TF :

- `INTÉGRÉE` : occupe un emplacement dans la forme principale ;
- `EN APPUI` : suit le centre avec un décalage et une distance de sécurité,
  notamment pour un AWACS, un arsenal ou un bâtiment de commandement ;
- `DÉTACHÉE` : conserve son appartenance, sa doctrine et son réseau, mais reçoit
  ses propres ordres de mouvement.

Un AWACS mobile appartient à une seule TF pour son déplacement et sa protection,
mais peut relayer plusieurs TF accessibles sans en devenir membre. Un ordre
individuel peut temporairement libérer une unité intégrée de son emplacement ;
un ordre explicite de retour la fait rejoindre la formation.

La formation est élastique. Son centre suit la route collective et chaque
bâtiment poursuit un emplacement mobile avec sa propulsion réelle. Aucun
bâtiment n'est téléporté, collé à son voisin ou déplacé par transformation de
groupe. La formation peut se déformer pendant une accélération, un freinage ou
un virage, puis se reconstituer. Si sa cohésion se dégrade, le mouvement collectif
peut ralentir par des ordres de propulsion ordinaires, jamais par une correction
magique de position ou de vitesse.

L'implémentation devra rester incrémentale : modèle de TF et statuts, calcul pur
des géométries, poursuite élastique respectant la cinématique, puis interface de
création, changement de formation, détachement et retour. Chaque étape devra
conserver la possibilité de sélectionner et commander un bâtiment individuellement.

Le premier incrément est implémenté dans `TaskForce`. Il porte les limites de
composition, la forme, l'espacement, l'appartenance et les trois statuts physiques,
sans encore produire d'ordre de mouvement. Il reste séparé de `TacticalGroup`,
qui représente aujourd'hui un domaine technique de fusion capteur et peut dépasser
dix unités dans les scénarios de charge. Leur raccord devra donc être explicite
plutôt que confondre prématurément commandement et traitement des capteurs.

Le deuxième incrément calcule les emplacements sans commander les unités. Les
distances provisoires sont externalisées dans
`data/balance/default_task_force_formation.tres` : `48` unités en serré, `120` en
lâche, avec une ligne d'appui respectivement à `180` ou `320` unités derrière
l'ancre. Une ligne répartit les intégrés symétriquement sur son front. Un essaim
de deux à six bâtiments forme un anneau régulier ; de sept à dix, un élément
occupe le centre et les autres forment l'anneau. Les distances entre voisins ne
descendent jamais sous l'espacement choisi. Les unités en appui reçoivent une
ligne arrière orientée avec la TF et les unités détachées ne reçoivent aucun
emplacement collectif. Ces nombres règlent uniquement la géométrie et restent
provisoires jusqu'à un essai en mouvement.

Le troisième incrément rend cette géométrie jouable dans `--task-force-demo`.
Une ancre cinématique suit l'ordre collectif avec la vitesse, l'accélération et
la rotation du membre commandé le moins mobile. Elle ralentit progressivement
quand l'écart maximal aux emplacements augmente. Les cibles de formation ne sont
republiées qu'après un déplacement de `8` unités ; chaque bâtiment les rejoint
ensuite avec sa navigation, sa propulsion et son inertie réelles. La formation
se déforme donc pendant la manœuvre puis se reconstitue sans téléportation.

Les touches `1–4` choisissent ligne/essaim et serré/lâche. `T` détache ou rattache
l'éclaireur de démonstration et `R` rappelle tous les détachés. Un ordre donné à
une sélection individuelle la détache avant d'exécuter sa micro. Les emplacements,
l'ancre et les erreurs de cohésion sont visibles dans la démo. Ce banc d'essai
ne raccorde pas encore les TF à l'interface générale de l'escarmouche.

La route appartient à l'ancre de la TF et non aux corrections de chaque membre.
`Shift` ajoute des waypoints, les points intermédiaires deviennent traversants et
`Alt` conserve l'ordre de traversée sans arrêt. Le tracé collectif affiche les
waypoints et un unique vecteur de cap final stable. Les routes courtes et mobiles
utilisées pour poursuivre les emplacements sont masquées tant que l'unité reste
intégrée ou en appui ; une unité détachée retrouve immédiatement sa propre route
et son propre vecteur. Cette séparation évite que l'automatisation de formation
efface le langage visuel de navigation existant.

La sélection suit la même frontière que le commandement : un clic ou un cadre
touchant au moins un membre sélectionne la TF entière. `Ctrl` est l'exception
explicite pour sélectionner une ou plusieurs unités individuellement. Les
touches `1–4`, rangée principale ou pavé numérique, changent réellement la
géométrie. Après l'arrêt de l'ancre, tous les intégrés et appuis convergent vers
le même cap collectif ; cette orientation commune est obtenue par leur rotation
physique, sans téléportation ni bonus abstrait.

Un emplacement en mouvement transporte une position et une vitesse, et non un
ordre implicite d'arrêt. La vitesse demandée combine translation de l'ancre,
rotation de la formation et correction proportionnelle de l'écart. Cela permet
aux coques flip-and-burn de retourner leur moteur principal pour corriger ou
freiner sans replanifier continuellement un faux waypoint. Pendant une manœuvre,
les orientations individuelles peuvent donc diverger et modifier réellement les
arcs d'armes et de capteurs. Le cap commun ne redevient une contrainte qu'après
stabilisation physique de toute la formation.

L'union orange des zones d'armes d'une sélection multiple reste la représentation
collective de l'engagement. Les réticules cyan restent visibles autour de chaque
unité sélectionnée, y compris pour une TF entière ; ils ne sont pas responsables
des halos d'enveloppe. Les arcs physiques continuent de contraindre le tir.

L'enveloppe collective d'armes est dessinée uniquement par son contour orange.
Les surfaces de chaque source ne sont pas remplies, car leurs transparences
cumulées formaient un halo intérieur sans information supplémentaire.

La même convention s'applique aux enveloppes de capteurs collectives : contours
bleu ou magenta conservés, surfaces individuelles non remplies. Aucune opacité
ne doit donc s'accumuler au centre d'une formation dense.

La prise du cap final est individuelle une fois l'ancre stabilisée. Un membre
déjà arrivé n'attend pas la cohésion complète de la TF pour tourner sa coque ;
seuls les retardataires conservent leur guidage de rattrapage. Cela ne donne
aucun avantage abstrait : chacun doit toujours être réellement à son emplacement
et sous la vitesse d'arrêt avant d'entamer sa rotation.

## Pilote tactique adverse

Le planificateur de combat est indépendant du camp, mais seul l'adversaire
l'appelle actuellement. Le joueur conserve donc le contrôle intégral de ses
routes, caps et ordres de feu. Pour chaque cible suivie, le pilote IA choisit un
système antinavire disponible, calcule une bande autour de sa portée préférée,
rejoint cette bande et aligne la coque si l'arme possède un secteur fixe. Un VLS
omnidirectionnel n'impose aucun changement de cap.

Les réglages sont externalisés dans `data/ai/default_tactical_pilot.tres` :
priorité railgun/missile, ratio de portée préférée, largeur de bande et seuil de
saturation des cellules fixes. Le scénario `--ai-demo` oppose ce groupe à une
frégate missile, un railgun et un AWACS bleus. Les bâtiments bleus sont mobiles,
indestructibles, armés et exclusivement commandés par le joueur.

### Scénario de bataille automatique

`--fleet-battle-demo` active exceptionnellement le pilote pour les deux camps,
avec deux profils distincts. `blue_network_missiles.tres` commande douze Bleus :
un AWACS, quatre escorteurs mixtes, trois frégates, deux arsenaux longue portée
et deux chasseurs antirayonnement. Ils maintiennent une bande de portée haute,
priorisent les railguns et se replient sous 30 % de coque.

`red_silent_raiders.tres` commande dix Rouges : un relais passif, trois
railguns axiaux, deux frégates, deux escorteurs et deux chasseurs
antirayonnement. Deux groupes cohérents réunissent chacun railgun, frégate,
escorteur et chasseur sur un axe ; leurs espacements restent dans la bulle de
défense rapprochée. Le troisième railgun attend la première diversion missile
avant de quitter la réserve.

Le relais n'allume pas son radar et commence par quatre secondes de silence. Il
partage ensuite ses pistes pendant `24` ticks (`1,2 s`) toutes les `160` ticks
(`8 s`). Le silence coupe effectivement l'accès distant aux pistes, au lieu de
masquer uniquement l'icône d'émission. Les groupes donnent une forte priorité à
la conduite de tir adverse et se replient sous 15 % de coque. Avant la première
fenêtre, ils suivent des points d'approche préplanifiés : le plan de mission ne
dépend pas d'une liaison permanente, contrairement à sa révision en vol.

Le déploiement reçoit un bruit déterministe. La graine affichée peut être
rejouée avec `--fleet-seed=<nombre>`. La partie se termine à l'annihilation, y
compris par destruction mutuelle. Ce scénario sert à observer et mesurer les
interactions, pas encore à valider l'équilibrage en points.

### Réservation des salves et niveau d'automatisation

L'IA estime les dégâts requis à partir de la coque connue, d'une marge doctrinale
et de la défense rapprochée présente dans un rayon de `280` unités. Chaque
missile en vol réserve ses dégâts attendus sur sa cible, pondérés par sa chance
estimée de traverser PDC et intercepteurs. Les lanceurs suivants réduisent leur
salve ou changent de cible lorsque cette réservation suffit. La doctrine bleue
conserve 25 % de ses munitions et la rouge 15 %.

La frontière visée pour le joueur est une commande par intention : cible ou
zone, famille d'arme, économie/salve/saturation et réserve souhaitée. Le jeu
assume l'allocation entre lanceurs, les missiles déjà engagés et la coordination
temporelle. `SATURATION` reste un choix volontaire qui peut ignorer l'économie ;
elle ne doit pas devenir un comportement automatique caché.
