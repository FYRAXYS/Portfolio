---
title: Application de gestion d'évènements sportifs
subtitle: Projet universitaire, du cadrage au développement
date: Janvier / Juin 2025
team: 6 personnes
tech: Java, JavaFX, R Studio
color: "#3f6ea8"
cover: res://ressources/images/projet2-1.png
---

Ce projet se divise en trois étapes : le cadrage, la conception et le développement.

## Étape 1 — Cadrage du projet

Le projet a commencé par la formation d'une équipe de 6 personnes. Une fois le groupe créé, nous avons initié la phase de cadrage : les différents rôles au sein de l'équipe, les fonctionnalités de l'application, les utilisateurs concernés.

Tout le travail préparatoire a été condensé dans un document de gestion de projet d'une dizaine de pages, composé des sections suivantes :

- une introduction brève rappelant les attendus du projet
- une spécification des besoins fonctionnels et non-fonctionnels
- les contraintes du projet (temporelles, de qualité, de ressources)
- une liste des risques, divisés en catégories (humain, matériel, technologique)
- une matrice de criticité de ces risques et la stratégie de mitigation associée
- une présentation des différents *personnæ* de l'application

## Étape 2 — Conception et modélisation

Une fois ce document validé, nous avons repris les différents besoins (créer une compétition, ajouter un participant, …) et attribué à chacun un degré de priorité pour l'implémentation.

Pour justifier nos choix, nous avons modélisé des diagrammes de cas d'utilisation, des diagrammes de séquence ainsi que des diagrammes de classes métier.

![Diagramme de cas d'utilisation](res://ressources/images/projet2-2.png)

En parallèle, nous avons commencé à réfléchir au design de l'application, de ses différentes pages et de la façon dont elles interagissent entre elles.

![Maquette de l'application](res://ressources/images/projet2-4.png)

## Étape 3 — Développement

La dernière étape concerne le développement de l'application, une fois les composants techniques et graphiques déterminés. Nous avons choisi une architecture **MVC** (Modèle — Vue — Contrôleur), chaque page étant représentée par une vue.

Pour implémenter ce système, nous avons utilisé Java avec **JavaFX** pour construire les éléments des pages. Pour travailler plus efficacement, l'équipe s'appuyait sur un dépôt GitLab.
