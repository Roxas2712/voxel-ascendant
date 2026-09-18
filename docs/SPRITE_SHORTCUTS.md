# Sprite-Schnellwechsel (Gen 1)

- **0 im Kampf:** verfügbare Pokémon-Darstellungen durchschalten. Dieselbe Aktion liegt in der VASC-Steuerung als Maus-/Touch-Schaltfläche. Funktioniert in MAP, ARENA, DISCS, Terrarium und der normalen 2D-Kampfansicht, während das Hauptkampfmenü offen ist. Während Attacken/Untermenüs bleibt deren Eingabe aktiv.
- **0 außerhalb des Kampfes:** vorhandene VASC-Sprite-Auswahl öffnen. Dort bleiben die Quellen für Dex, Oberwelt und weitere unterstützte Bereiche getrennt einstellbar.
- **F6:** HD-Personen / Original-2D sofort wechseln; auch die stehenden Personen in VASC-Kämpfen folgen dieser Auswahl.
- **F7:** nur Begleiter wechseln: Original-2D, automatische Quelle sowie installierte und verfügbare Modelle/Sprite-Pakete. Fehlende Downloads werden beim Schnellwechsel übersprungen. Sie sind über die Sprite-/Download-Auswahl erreichbar.
- **F4:** FPS-/Framezeit-Anzeige ein- oder ausblenden. Beim Einschalten wird FPS aktiviert; die übrigen gewählten Diagnosewerte bleiben erhalten.
- **F3:** VASC-Steuerung öffnen/schließen. F1 und F2 bleiben Schnellspeichern und Schnellladen.

**Controller:** R1/RB halten + Steuerkreuz oben: Pokémon, links: Personen, rechts: Begleiter, unten: FPS. R1/RB + Start öffnet die VASC-Steuerung. Dort wählen oben/unten die Aktion, links/rechts wechseln die Seite, A bestätigt und B schließt. Auch Kamera, Kampfansicht, Raster, Tiefenunschärfe, Weltkrümmung, Wasser und Zoom sind dort erreichbar. R2 bleibt der direkte Kamerawechsel. R1 allein behält seine bestehende Funktion beim Loslassen; eine R1-Kombination verändert das Spieltempo nicht.

**Handy:** Ein kleiner halbtransparenter VASC-Hinweis erscheint nach Kartenwechseln und zu Kampfbeginn einmal für 2,5 Sekunden. Die Stelle oben links (unter der Meldungs-/FPS-Zeile) bleibt auch nach dem Ausblenden antippbar und öffnet dieselbe Steuerung mit mindestens 48 Pixel hohen Touch-Flächen und seitenweiser Auswahl. Die Platzierung berücksichtigt den sicheren Displaybereich und passt sich Hoch-/Querformat an. Die Szene pausiert während der Auswahl. Das Schließen oder Antippen einer Aktion löst keine darunterliegende Spieltaste aus.

**Dezente Anzeige auf allen Geräten:** Der Hinweis blendet kurz ein und nach 2,5 Sekunden vollständig aus. Keine dauerhaft sichtbaren Hilfe-/Sprite-Knöpfe, kein erneutes Aufblitzen beim Schließen des Menüs, bei Kampfrunden oder am Kampfende. F3, R1 + Start und die Touch-Stelle bleiben erreichbar. Texteingaben und Controller-Belegungsdialoge behalten ihre Eingabe. Personen, Begleiter und FPS verwenden dieselben gespeicherten Optionen wie das Einstellungsmenü. Der Pokémon-Schnellwechsel im Kampf gilt nur für die aktuelle Begegnung. Verfügbarkeit und Sicherheitsgrenzen der jeweiligen Aktion bleiben erhalten (z.B. Pokémon-Wechsel im Hauptkampfmenü).

Benötigt die beim Spielstart aktive Overworld-Card für Personen/Begleiter. HD- und Modelloptionen benötigen ihre vorhandenen Inhalte; die Tasten laden keine Pakete selbst herunter. Gen-2-Einbindung dieser neuen Tastengruppe ist noch nicht Teil dieses Schnitts.

Prüfung: Lua-Eingabetests und echte Gen-1-Laufzeit mit simulierten Controller-/Touch-Ereignissen; Hochformat 390×844 und Querformat 844×390 sowie weitere Safe-Area-Grenztests. Noch keine physische Android-/iOS- oder Controller-Geräteabnahme. Enthalten ab VASC 3.0.24-rc.9; der frühere Zwischen-RC7 bleibt unverändert.
