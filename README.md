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

Les décisions de périmètre sont consignées dans `docs/mvp.md`.
Le point de reprise complet de la session du 1er août 2026 est consigné dans
`docs/session-2026-08-01.md`.
