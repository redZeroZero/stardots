# RETEX — Intégration IHM alpha et Task Forces — 8 août 2026

## 1. Objet

Ce document synthétise les constats issus de la séance d'implémentation du 8 août
2026 autour de `docs/spec-ihm-alpha.md`, de l'intégration des Task Forces dans
l'escarmouche normale et du commit :

`6e4c8007c8d755306f7667bca6f6820546c18bee`

Il ne remplace pas la spécification IHM. Il sert de **point de reprise pour la
prochaine session d'implémentation**.

Le but est de distinguer :

- les décisions désormais considérées comme acquises ;
- les comportements à corriger avant d'étendre davantage l'IHM ;
- les invariants d'architecture à préserver ;
- la dette technique volontairement reportée ;
- l'ordre de traitement recommandé.

---

## 2. Conclusion générale

La séance a confirmé une évolution importante du projet :

> La Task Force n'est plus une fonctionnalité de démonstration. Elle devient
> l'unité normale de commandement du joueur dans Stardots.

Le modèle cible pour l'alpha est désormais :

- **clic normal sur un membre d'une TF** → sélection collective de la TF ;
- **cadre ne couvrant qu'une TF** → sélection collective de la TF ;
- **Ctrl + clic / Ctrl + cadre** → micro-sélection d'un ou plusieurs bâtiments ;
- **inspection individuelle seule** → ne détache pas le bâtiment ;
- **ordre individuel donné à une micro-sélection** → détachement physique ;
- **rattachement explicite** → retour du bâtiment dans la formation ;
- **ordres collectifs** → passent par l'ancre, les slots et la cinématique réelle
  de `TaskForceMotion`.

Cette direction est conservée.

---

## 3. Éléments validés et à conserver

### 3.1 Task Forces dans l'escarmouche normale

L'intégration des Task Forces dans le jeu normal est validée.

Les composants suivants sont considérés comme de bonnes bases :

- `TaskForceRegistry` ;
- `TaskForceMotion` ;
- `TacticalSelectionState` ;
- `TacticalUiContract` ;
- `TacticalEventLog` ;
- `TacticalWindowModeController`.

Le mouvement collectif de l'escarmouche doit continuer à utiliser les mêmes
principes physiques que la démo :

- ancre ;
- slots ;
- vitesse de slot ;
- route collective ;
- waypoints ;
- heading final ;
- déformation élastique ;
- statuts `INTEGRATED`, `SUPPORT`, `DETACHED`.

La démo TF ne doit plus devenir une seconde implémentation divergente du jeu
normal.

### 3.2 Sélection partagée

Le fait d'avoir une source commune pour la sélection carte / roster / barre TF est
validé.

La sélection visuelle du monde et la sélection affichée dans le roster doivent
toujours représenter le même état.

### 3.3 IHM compacte

Les changements de densité sont conservés :

- barre supérieure sans tick visible ;
- dock inférieur fortement réduit ;
- police plus petite ;
- contrôles fusionnés ;
- bande opaque pleine largeur en bas ;
- minimap conservée comme élément principal ;
- barre de Task Forces ;
- roster ;
- journal tactique repliable ;
- alertes compactes ;
- mode plein écran fenêtré par défaut ;
- `F11` pour parcourir les modes d'affichage.

### 3.4 Railgun

La modification actuelle est conservée pour test :

- portée maximale : `650 -> 1300` ;
- arc : `60° -> 45°` ;
- mount dédié `railgun_fixed.tres`.

Cette décision est considérée comme une hypothèse d'équilibrage séparée de
l'IHM. Elle devra être validée en bataille, mais ne doit pas être annulée pendant
la prochaine session IHM sans raison de gameplay explicite.

---

## 4. Priorité critique — connaissance joueur et absence de fuite d'information

C'est le point le plus important à corriger avant d'ajouter davantage de
présentation tactique.

### 4.1 Invariant

> L'IHM ne doit jamais déduire ou afficher directement une information ennemie à
> partir de l'état réel de la simulation lorsqu'elle n'est pas connue du joueur.

Cela concerne au minimum :

- minimap ;
- alertes ;
- journal tactique ;
- compteurs ;
- télémétrie ;
- pertes ennemies ;
- impacts ;
- interceptions ;
- missiles entrants ;
- disparition d'un contact ;
- identité exacte d'une cible ;
- état des systèmes ennemis.

### 4.2 Problème actuel

Le commit commence correctement à filtrer les contacts hostiles et les missiles,
mais plusieurs chemins restent susceptibles de lire directement l'état réel.

Exemples à traiter :

- un impact peut actuellement générer un événement avec le `callsign` réel de la
  cible ;
- une interception peut être journalisée même si le joueur ne peut pas
  l'observer ;
- un ennemi réellement détruit peut disparaître immédiatement d'un compteur de
  contacts sans BDA confirmée ;
- `is_hostile_missile_known_to_player()` réimplémente localement une règle de
  détection simplifiée, distincte du système de pistes principal.

### 4.3 Décision

Ne pas multiplier les `if known_to_player` dans chaque widget.

Introduire une frontière claire entre :

1. **événement de simulation brut** ;
2. **connaissance du camp joueur** ;
3. **présentation**.

Une forme possible :

```text
Simulation event
      ↓
PlayerKnowledge / presentation filter
      ↓
Player-visible event
      ↓
HUD / minimap / journal / alertes
```

Le nom exact des classes reste libre.

Le principe est obligatoire : **la couche Presentation consomme une vue filtrée,
pas la vérité complète du monde ennemi**.

### 4.4 Missiles hostiles

Éviter à terme que l'IHM recalcule elle-même :

```text
distance <= portée capteur
```

pour savoir si un missile est connu.

La simulation ou une couche de connaissance doit produire cet état de
connaissance. La minimap et les alertes ne font que le consommer.

### 4.5 Tests requis

Ajouter des régressions pour au moins les cas suivants :

- missile hostile hors détection → aucune alerte ;
- missile détecté → alerte possible ;
- impact ennemi non observé → aucun `callsign` ou résultat exact dans le journal ;
- destruction ennemie sans confirmation → aucune diminution omnisciente d'un
  compteur présenté comme certain ;
- perte confirmée → événement et compteur autorisés.

---

## 5. Priorité haute — sémantique des commandes de Task Force

### 5.1 `R` ne doit plus être global

Comportement actuel à corriger :

`R` rattache tous les éléments détachés de toutes les Task Forces du joueur.

Comportement cible :

```text
TF sélectionnée
R → rattache les éléments détachés de cette TF

micro-sélection contenant un ou plusieurs DETACHED de la même TF
R → rattache ces éléments

aucune sélection pertinente
R → aucune action
```

Ne pas créer pour l'instant de commande globale de rattachement.

`Maj+R` pourra être envisagé plus tard si un vrai besoin apparaît.

### 5.2 Formation uniquement sur TF explicitement commandée

Comportement actuel à corriger :

si aucune TF n'est sélectionnée, `Maj+1–4` peut modifier toutes les TF.

Comportement cible :

```text
TF commandée
Maj+1 → ligne serrée
Maj+2 → ligne lâche
Maj+3 → essaim serré
Maj+4 → essaim lâche

aucune TF commandée
→ raccourci ignoré
→ boutons de formation désactivés ou inactifs
```

Aucune commande de formation globale implicite.

---

## 6. Priorité haute — distinguer contexte de TF et sélection de commandement

### 6.1 Problème

La micro-sélection conserve actuellement une référence à la TF parente pour
maintenir le roster visible.

C'est une bonne décision d'UX, mais cette TF parente peut ensuite être interprétée
comme une TF réellement sélectionnée pour recevoir des commandes collectives.

Exemple indésirable :

```text
Ctrl+clic FRIG-03
→ roster de TF1 reste affiché
→ Maj+3
→ toute TF1 change de formation
```

alors que le joueur voulait seulement inspecter `FRIG-03`.

### 6.2 Décision conceptuelle

Séparer au minimum les notions suivantes :

- **Task Force de contexte** : celle dont le roster reste visible ;
- **sélection de commandement** : unités ou TF recevant effectivement la prochaine
  commande.

Le nom exact des champs est libre, par exemple :

```text
context_task_force
command_selection
```

ou toute abstraction équivalente.

### 6.3 Contrat cible

```text
clic TF / raccourci 1–4
→ TF commandée
→ roster de la TF visible

Ctrl+clic membre
→ bâtiment commandé individuellement
→ roster de la TF parente reste visible
→ la TF elle-même ne reçoit pas les commandes collectives
```

Un clic ultérieur sur la tuile TF ou son raccourci rétablit la sélection
collective.

---

## 7. Priorité haute — cadre couvrant plusieurs Task Forces

### 7.1 Problème actuel

Lorsqu'un cadre normal intersecte des membres de plusieurs TF, le code peut
sélectionner la première TF rencontrée.

Ce comportement n'est pas acceptable comme contrat final car l'ordre dépend de
l'itération plutôt que de l'intention du joueur.

### 7.2 Décision cible recommandée

À terme :

```text
cadre touche une seule TF
→ sélectionner cette TF entière

cadre touche plusieurs TF
→ sélectionner les TF touchées comme ensemble de commandement multi-TF
```

Un ordre de déplacement envoyé à plusieurs TF doit être transmis à chaque
`TaskForceMotion`, chaque TF conservant sa formation propre.

### 7.3 Fallback alpha acceptable

Si la sélection multi-TF demande trop de refonte pour la prochaine session, le
fallback temporaire autorisé est :

```text
cadre multi-TF
→ sélectionner individuellement les bâtiments réellement contenus dans le cadre
```

mais **ne jamais choisir arbitrairement la première TF rencontrée**.

Documenter explicitement le fallback s'il est retenu.

---

## 8. Relation provisoire TacticalGroup / TaskForce

### 8.1 Situation actuelle

Pour l'escarmouche alpha :

```text
1 tactical_group_id = 1 Task Force
```

Le `TaskForceRegistry` est reconstruit à partir des groupes tactiques du
déploiement.

### 8.2 Décision

Cette relation est acceptée comme **bootstrap alpha temporaire**.

Ne pas refondre le déploiement maintenant uniquement pour la supprimer.

En revanche, conserver l'invariant architectural :

> `TacticalGroup` et `TaskForce` sont deux concepts distincts.

- `TacticalGroup` : partage de pistes / architecture réseau ;
- `TaskForce` : commandement / mouvement / formation.

À terme, le déploiement pourra porter deux identifiants indépendants :

```text
network_group_id
task_force_id
```

Une même architecture réseau pourra ainsi éventuellement couvrir plusieurs TF.

La limite de 10 bâtiments de `TaskForce` ne doit pas devenir par accident une
limite fondamentale des groupes de capteurs.

---

## 9. Touche `T`

La touche `T` de l'ancienne démo ne doit pas être réintroduite telle quelle.

Elle ciblait historiquement un éclaireur explicitement identifié. Le modèle normal
ne possède plus ce rôle unique codé en dur.

Le nouveau contrat couvre déjà le besoin :

```text
Ctrl + sélection
→ micro-sélection

ordre individuel
→ détachement

R
→ rattachement
```

Si une commande explicite `DÉTACHER` est ajoutée plus tard, elle doit agir sur
n'importe quel membre sélectionné et non sur un scout spécial.

Pour l'alpha actuelle : **`T` reste sans fonction**.

---

## 10. Roster — conserver la fonction, alléger progressivement la présentation

Le roster actuel est fonctionnel et doit être conservé.

Les abréviations utilisées pour la validation sont utiles :

- `COQ` : coque ;
- `CH` : chaleur ;
- `INT` : intégré ;
- `APP` : appui ;
- `DÉT` : détaché ;
- `LIÉ` : réseau disponible ;
- `ISO` : isolé.

Cependant, une TF de 8 à 10 bâtiments risque de saturer horizontalement en
1280 × 720.

### Décision

Ne pas bloquer la prochaine session sur un redesign graphique complet.

Conserver les tuiles textuelles pour la validation fonctionnelle, mais préparer
une évolution vers :

- callsign / rôle court ;
- barre ou contour d'intégrité ;
- indicateur thermique ;
- état réseau ;
- état TF ;
- alerte missile / critique ;
- tooltip et inspecteur pour les détails.

Le détail ne doit pas être répété intégralement dans chaque tuile.

---

## 11. Dette technique — `main.gd`

Le commit a ajouté une quantité importante d'orchestration dans `src/main.gd`.

Cela reste acceptable pour valider rapidement le lot, mais devient une dette à
traiter avant de poursuivre plusieurs lots IHM supplémentaires.

### 11.1 Ne pas faire

Ne pas lancer une refonte massive de `main.gd` sans objectif fonctionnel.

### 11.2 Extraction recommandée

Avant ou pendant le prochain gros lot IHM, extraire au minimum deux
responsabilités :

#### `TacticalHudController` ou équivalent

Responsabilités possibles :

- barre TF ;
- roster ;
- inspecteur ;
- alertes ;
- journal ;
- labels de commandes ;
- refresh/signatures UI ;
- window mode si pertinent.

#### `TaskForceCommandController` ou équivalent

Responsabilités possibles :

- sélection TF par raccourci ;
- commandes de formation ;
- détachement/rattachement ;
- routage des ordres collectifs ;
- accès au `TaskForceRegistry` et aux `TaskForceMotion`.

Le but n'est pas d'ajouter des couches abstraites inutiles mais de réduire le
couplage de `main.gd` et de rendre les prochaines modifications plus ciblées.

Cette extraction doit conserver les tests existants.

---

## 12. Tests à ajouter ou modifier

### 12.1 Sélection / commandement

- clic normal sur membre → TF complète ;
- Ctrl+clic → unité seule, roster parent visible ;
- Ctrl+clic sans ordre → membre reste intégré ;
- ordre micro → membre devient détaché ;
- `R` sur micro détachée → rattache uniquement la sélection pertinente ;
- `R` sur TF → rattache uniquement cette TF ;
- `R` sans contexte → aucun effet ;
- Maj+1–4 sans TF commandée → aucun effet ;
- Maj+1–4 sur TF commandée → modifie uniquement cette TF ;
- cadre mono-TF → TF complète ;
- cadre multi-TF → comportement déterministe selon la décision retenue.

### 12.2 Connaissance joueur

- aucun contact inconnu sur minimap ;
- aucun missile hostile inconnu dans les alertes ;
- aucun appel nominal ennemi sans identification ;
- aucun impact/interception non observé dans le journal ;
- aucune perte ennemie non confirmée exposée comme certaine ;
- disparition ou dégradation d'une piste suit le système de connaissance plutôt
  que l'état réel de l'unité.

### 12.3 Layout

Conserver les tests 1280 × 720 et 1920 × 1080 :

- minimap accessible ;
- dock inférieur compact ;
- bande opaque distincte ;
- barre TF hors chevauchement ;
- roster exploitable à 10 membres ;
- aucun bouton principal hors écran.

---

## 13. Ordre recommandé pour la prochaine session

### Étape 1 — fermer les invariants de connaissance

1. identifier toutes les sorties HUD qui lisent directement l'état ennemi ;
2. introduire ou renforcer une vue filtrée côté joueur ;
3. corriger journal, alertes, minimap et télémétrie ;
4. ajouter les tests de non-fuite.

**Ne pas ajouter de nouvelle télémétrie avant cette étape.**

### Étape 2 — corriger les commandes TF ambiguës

1. `R` limité au contexte/sélection ;
2. formation limitée à une TF explicitement commandée ;
3. supprimer tout comportement collectif implicite lié à l'absence de sélection.

### Étape 3 — séparer contexte et commande

1. garder le roster de la TF parent pendant une micro-sélection ;
2. empêcher qu'une micro-sélection ne transforme implicitement la TF parent en
   destinataire des commandes collectives ;
3. adapter les tests de sélection.

### Étape 4 — résoudre le cadre multi-TF

Implémenter la sélection multi-TF recommandée ou le fallback alpha déterministe.

### Étape 5 — réduire la dette `main.gd`

Extraire les responsabilités HUD / commande TF avant de poursuivre des ajouts IHM
significatifs.

### Étape 6 — reprendre le polish fonctionnel de l'IHM

Seulement ensuite :

- densité du roster ;
- icônes d'état ;
- inspecteur plus lisible ;
- alertes ;
- rapport de bataille ;
- onboarding alpha.

---

## 14. Critère de sortie de la prochaine session

La prochaine session peut être considérée comme réussie si :

1. aucune information ennemie certaine n'est affichée sans passer par la
   connaissance joueur ;
2. `R` et les formations n'agissent jamais sur des TF non explicitement visées ;
3. une micro-sélection conserve son roster sans recevoir accidentellement les
   commandes collectives de la TF parent ;
4. le cadre multi-TF possède un comportement déterministe documenté ;
5. les tests couvrent ces quatre invariants ;
6. aucune régression n'est introduite dans les mouvements physiques des TF ;
7. `main.gd` n'absorbe pas un nouveau gros bloc de logique IHM sans extraction
   ciblée.

---

## 15. Phrase de reprise pour Codex

Prompt de reprise recommandé :

> Lis `docs/retex-ihm-task-forces-2026-08-08.md` et
> `docs/spec-ihm-alpha.md`. Traite les actions dans l'ordre du RETEX, en
> commençant par l'invariant de connaissance joueur et les tests de non-fuite.
> Préserve le comportement physique actuel des Task Forces et ne poursuis pas le
> polish visuel tant que les priorités critiques et hautes du RETEX ne sont pas
> fermées.
