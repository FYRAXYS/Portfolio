extends Control

@onready var exit_button: Button = %Exit
@onready var project_card: PanelContainer = $MarginContainer/ScrollContainer/VBoxContainer/ProjectCard


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	project_card.project_title = "Recueil des besoins et création d'un site pour une entreprise"
	project_card.project_summary = "Ce projet se découpe en deux temps : un recueil des besoins pour une ESN fictive, puis la création du site web correspondant. Le format en carte permet de séparer clairement l'image, les métadonnées et le texte descriptif sans utiliser de BBCode pour la mise en page."
	project_card.project_group = "4 personnes"
	project_card.project_date = "Fin 2024"
	project_card.project_tech = "HTML5, CSS"
	project_card.project_image = preload("res://ressources/images/projet3-1.png")
	project_card.refresh()


func _on_exit_pressed() -> void:
	hide()
	get_tree().paused = false
