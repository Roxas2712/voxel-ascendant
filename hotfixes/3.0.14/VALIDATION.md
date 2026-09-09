Low Kick previously completed the custom animation after 18 ticks, before the native SHOW_MON_PIC event at tick 55. Both timelines now finish before returning control to BattleState (tick 58). No blanket visibility reset is used.

The extracted release passes 2,640 assertions, including exact native effect/sound timing across 214 move/side combinations per player copy, subsequent starts, Dig/Fly/native-only sequences and native-start failures. PETAL_DANCE already fails in the unmodified engine 0.2.56 animation emitter; its custom fallback completion is tested separately. This is native LÖVE fixture testing, not a physical Android playthrough.

Only the two animation players, version manifest and runtime receipt differ from public 3.0.13. All runtime receipt hashes were verified. New Cards retain KASC 6.7.3, identity, save scope and artwork. Rollback: reinstall VASC 3.0.13 and the previous Cards v1.3.0-rc.20. No save migration.
