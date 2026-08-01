# Équilibrage du prototype

Les valeurs de combat modifiables sont regroupées dans `data/balance/`. Les fichiers `.tres` peuvent être sélectionnés dans Godot puis modifiés dans l'Inspecteur.

## Profils disponibles

- `default_unit.tres` : équipage, vitesse tactique, accélérations linéaire et angulaire, portée des capteurs, portée et puissance PDC, coque, délai entre deux missiles et capacité du magasin.
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
