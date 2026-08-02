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
poussée. La portée effective des capteurs passifs dépend désormais de la
signature de leur cible : une dérive froide est discrète, une manœuvre propulsée
est beaucoup plus facile à suivre.

## Contrôle des systèmes

- `X` ou le bouton moteurs coupe immédiatement le plan de poussée sans annuler la vélocité ;
- `S` alterne entre capteur passif et actif ;
- la gestion thermique est automatique.

Le capteur actif porte plus loin et produit directement une piste exploitable,
mais son émission peut être détectée à plus grande distance et génère de la
chaleur. À l'arrêt, le calculateur adopte le régime silencieux afin de réduire le
rayonnement. Un ordre de poussée ou une dérive significative impose le régime
normal. Un lancement de missile, une menace missile entrante, un tir PDC ou un
impact déclenche immédiatement le régime combat : le refroidissement est maximal,
au prix d'une forte signature de radiateur. Après `6 s` sans menace pour une
frégate (`7 s` pour l'AWACS), le régime adapté au mouvement revient seul.

## Carte stratégique et minimap

La molette permet maintenant de dézoomer jusqu'à une vue presque complète du
théâtre de `8192 × 8192`. La caméra reste bornée à cette zone. La minimap en haut
à droite affiche les bâtiments amis, le cadre de caméra et uniquement les
contacts ennemis connus, avec une couleur dépendant de leur niveau de
renseignement. Un clic gauche sur la minimap déplace la caméra.

Approcher le pointeur à moins de `18 px` d'un bord de l'écran déplace aussi la
caméra dans cette direction, comme dans un RTS classique. Les coins combinent
les deux axes pour un déplacement diagonal. La vitesse reste adaptée au niveau
de zoom et les flèches du clavier restent disponibles.

Sans unité sélectionnée, maintenir le clic droit et glisser déplace directement
la carte ; le déplacement est compensé par le niveau de zoom. Sur la minimap,
le glisser continu fonctionne avec le bouton gauche ou droit. Les contrôles de
l'interface neutralisent le défilement par contact avec le bord afin d'éviter
que les deux gestes se cumulent.

Le rectangle de `8192 × 8192` est maintenant bordé d'un liseré cyan et d'une
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
sont de `2800` en passif, `4000` en actif et `5000` contre une émission active.

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
de `180` unités. Chaque lanceur sélectionné tire une salve sur le contact valide
le plus proche du centre, s'il possède à la fois une solution de tir et la
portée nécessaire. Une zone vide ou un clic imprécis ne crée aucun mouvement.
Le cercle devient vert si au moins un missile est parti, orange sinon. `Échap`
annule l'ordre armé. Le changement de mode capteur utilise désormais `S`.

L'ordre fonctionne sur une sélection multiple : chaque bâtiment armé tire au
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
- Ctrl + clic droit : traverse le point sans annuler la vélocité ;
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
complète mesure environ `45 ms` par tick pour 500 unités et 50 missiles,
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
que sur la position réelle. Quatre crochets orange indiquent sobrement
l'incertitude croissante. Railguns et missiles reçoivent également cette
position estimée ; un missile conserve la dernière information partagée jusqu'à
son éventuelle acquisition terminale. Le scénario `--sensor-demo` permet
d'observer toute la dégradation sur un contact sortant.

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
également appliquée. L'interface dessine chaque secteur et indique si un ordre
échoue faute d'arc, de portée, de piste ou de disponibilité.

Le catalogue initial contient sept `WeaponSystemProfile` : PDC cinétique
fragmentant, PDC laser, missile intercepteur court, tubes antinavires moyens,
cellules antinavires fixes, cellules longue portée et railgun axial moyen. Les
tubes utilisent un magasin ; les cellules offrent une forte cadence initiale,
mais chaque départ consomme définitivement une cellule. Le laser consomme de la
chaleur plutôt que des munitions. Les défenses attaquent automatiquement les
menaces entrantes ; railgun et missiles antinavires répondent à l'ordre de zone.

La sélection offensive utilise `W` pour autoriser automatiquement toutes les
armes, uniquement les missiles ou uniquement les railguns. La doctrine utilise
`D` : `ÉCONOMIE` arrête l'ordre après le premier tir de la formation, `SALVE`
autorise un tir par bâtiment, et `SATURATION` déclenche toutes les armes et
cellules prêtes. Une batterie fixe suit toujours la coque. Une tourelle conserve
un cap relatif indépendant, poursuit son point de visée à la vitesse configurée
et ne tire qu'une fois dans sa tolérance angulaire. Sa direction instantanée est
dessinée à l'intérieur de son enveloppe de rotation.

Une saturation n'empile plus les projectiles sur une trajectoire unique. Le
calculateur attribue des couloirs latéraux espacés de `52` unités et distribue
les missiles à tour de rôle entre toutes les cibles valides de la zone. Les
couloirs convergent au passage en guidage terminal. La fusée de proximité reste
désarmée pendant les `55` premières unités de vol, ce qui protège le lanceur et
la formation au départ de la salve.

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
