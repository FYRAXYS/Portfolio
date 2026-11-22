# Contenu du portfolio

Les documents de ce dossier sont lus au lancement du jeu et affichés dans le
livre du chalet (`DetailViewer`). Ils ne sont pas des ressources Godot : le
preset d'export les conserve grâce au filtre de fichiers non-ressources
`*.md` (champ *Filters to export non-resource files/folders*).

## Organisation

| Dossier     | Contenu                                                              |
|-------------|----------------------------------------------------------------------|
| `projects/` | un fichier par projet, un livre par fichier sur l'étagère            |
| `pages/`    | documents ouverts depuis un seul élément (compétences, parcours, ...) |

Les fichiers de `projects/` sont triés par nom : le préfixe numérique
(`01-`, `02-`, ...) fixe l'ordre des livres sur l'étagère. Ajouter un projet
ne demande donc que d'ajouter un fichier.

## En-tête (front matter)

```
---
title: Titre affiché sur la première page
subtitle: Ligne de description optionnelle
date: Janvier / Juin 2025
team: 6 personnes
tech: Java, JavaFX
color: "#3f6ea8"
cover: res://ressources/images/projet2-1.png
---
```

- `title`, `subtitle`, `color` (couleur de la tranche du livre) et `cover`
  (image de la première page) ont un rôle particulier ;
- toute autre clé est affichée comme métadonnée sous le titre. `date`, `team`
  et `tech` ont une icône, les autres clés sont affichées avec leur nom ;
- sans `title`, le premier titre `#` du document est utilisé.

## Corps du document

La mise en forme suivante est convertie en BBCode :

- titres `#`, `##`, `###`
- listes `-`, `*`, `+` et listes numérotées `1.`
- `**gras**`, `*italique*`, `` `code` `` et blocs de code ```` ``` ````
- citations `>` et séparateurs `---`
- images `![texte](res://ressources/images/image.png)`
- liens `[texte](https://exemple.com)`

Les chemins d'images relatifs sont résolus depuis le dossier du document.
