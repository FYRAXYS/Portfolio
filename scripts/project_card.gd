extends PanelContainer

@export var project_title: String = "Project title"
@export_multiline var project_summary: String = "Short project summary goes here."
@export var project_image: Texture2D
@export var project_date: String = "2026"
@export var project_group: String = "1 person"
@export var project_tech: String = "Godot"

@onready var title_label: Label = %TitleLabel
@onready var summary_label: RichTextLabel = %SummaryLabel
@onready var date_label: Label = %DateLabel
@onready var group_label: Label = %GroupLabel
@onready var tech_label: Label = %TechLabel
@onready var image_rect: TextureRect = %ImageRect


func _ready() -> void:
	_apply_content()


func refresh() -> void:
	_apply_content()


func _apply_content() -> void:
	title_label.text = project_title
	summary_label.text = project_summary
	date_label.text = project_date
	group_label.text = project_group
	tech_label.text = project_tech
	image_rect.texture = project_image