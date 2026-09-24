# VASC 3.0.43 — Legacy Bank box navigation

The Legacy Bank can now change boxes without shoulder buttons or a keyboard. From the top Pokémon row, press UP to focus the numbered Legacy Box heading, LEFT/RIGHT to change boxes, and DOWN, A or B to return to the grid. This uses the normal controller and touch D-pad.

The heading displays the current box number, visible arrows and a highlighted focus state. Footer hints explain how to reach the heading and return to the Pokémon. Cross-box selections and carried Pokémon are preserved; first/last box wrapping follows the existing Bank contract. Ordinary PC box navigation remains unchanged. The shared Gen-2 provider receives the same fix.

This update changes presentation and navigation only. Bank data, withdrawal eligibility and the KASC NG+ recovery safeguards remain owned by KASC. It retains all VASC 3.0.42 changes.

Validation: regression failed on 3.0.42 and passes on the fix; controller and touch input paths tested, including a native combined KASC/VASC session with the affected Yellow Bank fixture. Screenshot review verified the numbered heading, arrows and help. Physical controller hardware and Android/iOS device testing remain pending.

Install the complete ZIP using the launcher and restart the game. Keep Kanto Ascendant installed and updated (current integration baseline: 6.7.24). No manual Bank import or new NG+ run is required.
