extends CanvasLayer
class_name LegalConsent

const LEGAL_VERSION: int = 1
const CONSENT_PATH := "user://legal_consent.cfg"

const TERMS_TEXT := """LAGOS GTA — TERMS & CONDITIONS

1. About this game
Lagos GTA is an original, fictional open-world game inspired by Lagos, Nigeria. It is not affiliated with, endorsed by, or connected to Rockstar Games or any other game publisher.

2. Acceptable use
You may use this game for personal entertainment. You must not reverse engineer, redistribute, exploit, cheat in online services, or use the game to violate another person's rights or applicable law, except where such restrictions are prohibited by law.

3. Intellectual property
The game code, original artwork, names, audio and other content are owned by the developer or used under licence. Third-party marks, geographic data and assets remain subject to their respective owners' rights and licence terms. Do not assume that real-world people, businesses or locations depicted in fictional form endorse this game.

4. Availability and updates
Features, content and compatibility may change as the game is developed. We do not promise uninterrupted availability or compatibility with every device. Updates may be required for security, compatibility or new features.

5. Purchases
The current prototype does not offer in-app purchases, subscriptions or paid virtual currency. If monetisation is introduced, pricing, billing, refunds and cancellation terms will be disclosed before purchase and handled through the relevant store rules.

6. Disclaimers and liability
The game is provided for entertainment. To the extent permitted by applicable law, it is provided without warranties beyond those that cannot legally be excluded. Nothing in these terms removes consumer rights that apply in your country.

7. Changes and contact
These terms may be updated as the game develops. A material change must be presented for acceptance where required. A public support/contact address and the legal publisher identity must be added before public release.

By selecting the agreement checkbox and choosing “Accept and continue”, you confirm that you have read and agree to these Terms & Conditions and have been shown the Privacy Notice.
"""

const PRIVACY_TEXT := """LAGOS GTA — PRIVACY NOTICE

Current prototype data practices
This prototype does not require an account and is designed not to transmit personal information, precise location, contacts, microphone recordings, photos or payment information to a game server. The current build does not include advertising, analytics or third-party tracking SDKs.

Local storage
The game stores the version of the Terms & Conditions accepted on this device using Godot's application data storage. This local consent record is used only to avoid showing the same first-run notice on every launch. It is not uploaded by this prototype.

Network access
No gameplay account or online multiplayer service is currently implemented. If online features, crash reporting, analytics, advertising, cloud saves or purchases are introduced, this notice must be updated before those features are released. The data types, purposes, service providers, retention periods and user controls must be disclosed accurately.

Children
The intended age rating and audience have not yet been finalised. The public release must set an accurate age rating and comply with the child-safety and family policies that apply in each store and territory.

Your choices
You can review this notice at any time using the LEGAL button in the game. You can reset the local consent record by clearing the game's app data. This prototype has no remote account or server-side personal data to delete.

Publisher and contact
The legal publisher name, public privacy-policy URL and privacy contact address must be completed before store submission. Do not treat this development notice as the final legally reviewed policy.

Last updated: 1 November 2026.
"""

var _panel: PanelContainer
var _agreement: CheckBox
var _accept_button: Button

static func is_current_consent(stored_version: int) -> bool:
	return stored_version == LEGAL_VERSION

func _ready() -> void:
	_build_interface()
	_panel.visible = not _has_current_consent()

func _has_current_consent() -> bool:
	var config := ConfigFile.new()
	if config.load(CONSENT_PATH) != OK:
		return false
	return is_current_consent(int(config.get_value("legal", "accepted_version", 0)))

func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var legal_button := Button.new()
	legal_button.text = "LEGAL"
	legal_button.anchor_left = 1.0
	legal_button.anchor_right = 1.0
	legal_button.offset_left = -104.0
	legal_button.offset_top = 18.0
	legal_button.offset_right = -18.0
	legal_button.offset_bottom = 58.0
	legal_button.pressed.connect(_open_legal)
	root.add_child(legal_button)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.035
	_panel.anchor_top = 0.07
	_panel.anchor_right = 0.965
	_panel.anchor_bottom = 0.93
	_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_panel.add_child(layout)

	var heading := Label.new()
	heading.text = "BEFORE YOU ENTER LAGOS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	var intro := Label.new()
	intro.text = "Review the game terms and privacy notice. You must agree to continue."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(intro)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	tabs.add_child(_make_document_tab("Terms & Conditions", TERMS_TEXT))
	tabs.add_child(_make_document_tab("Privacy Notice", PRIVACY_TEXT))

	_agreement = CheckBox.new()
	_agreement.text = "I agree to the Terms & Conditions and acknowledge the Privacy Notice."
	_agreement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_agreement.toggled.connect(_on_agreement_toggled)
	layout.add_child(_agreement)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(actions)

	var decline_button := Button.new()
	decline_button.text = "Decline and exit"
	decline_button.pressed.connect(func(): get_tree().quit())
	actions.add_child(decline_button)

	_accept_button = Button.new()
	_accept_button.text = "Accept and continue"
	_accept_button.disabled = true
	_accept_button.pressed.connect(_accept_terms)
	actions.add_child(_accept_button)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.085, 0.98)
	style.border_color = Color(0.72, 0.52, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _make_document_tab(tab_title: String, document_text: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := RichTextLabel.new()
	body.text = document_text
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 15)
	scroll.add_child(body)
	return scroll

func _on_agreement_toggled(checked: bool) -> void:
	_accept_button.disabled = not checked

func _accept_terms() -> void:
	if not _agreement.button_pressed:
		return
	var config := ConfigFile.new()
	config.set_value("legal", "accepted_version", LEGAL_VERSION)
	config.set_value("legal", "accepted_at_unix", Time.get_unix_time_from_system())
	var save_result := config.save(CONSENT_PATH)
	if save_result != OK:
		push_error("Could not save legal consent. The game will remain on this screen.")
		return
	_panel.visible = false

func _open_legal() -> void:
	_agreement.button_pressed = false
	_accept_button.disabled = true
	_panel.visible = true
