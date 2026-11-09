# Personalized weather planning

User approved the AI suggestions, explicitly choosing AI improvements first.
Build on the free forecast-based approach and existing Tips interface. Add activity
selection (commuting, walking, exercise, outdoor work), a chosen hourly start and
1/2/3-hour duration, explainable assessment, precautions and better-time suggestions.
Optional daily routines are stored per city on this device and highlight assessment
changes on subsequent checks. Feedback accepts an optional reason and can be cleared.
No paid provider, chatbot, automatic learning or trained-model claims. A trained
suitability model remains a future research project requiring labeled data and
comparison against this deterministic baseline.

Approach: extend the current optional Open-Meteo hourly request with apparent
temperature, wind and weather code. Keep validated hourly samples for 72 hours;
plan within the next 36 hours. This reuses existing caching and avoids another
API request. A generative provider would add cost and cannot improve the underlying
forecast; a trained model is premature without data. Use deterministic rules now.

All planning times are Philippine time; stored routine hours are PHT regardless of
device timezone. Assess every consecutive hour, using the worst value. Missing
required fields or stale data prevent favorable assessments. Thunderstorms, wind
at least 15 m/s, or feels-like at least 41 C mean postpone exposed activity. Other
activity thresholds produce precautions: commute rain 60%, temp 35 C, feels 38 C,
UV 8, wind 10 m/s; walk/work rain 40%, temp 32 C, feels 35 C, UV 6, wind 10 m/s;
exercise rain 30%, temp 30 C, feels 32 C, UV 6, wind 8 m/s. These are app planning
heuristics, not clinical thresholds or official warnings. Known storm/wind risks
remain visible even if other inputs are missing. Never label a window safe.

Alternatives must have full fresh data, no triggered thresholds, fit daytime
06:00–18:00 PHT and be strictly better than the selected window. If none qualifies,
say so. The existing outdoor card must also reject storms, strong wind and missing
hazard data. Keep existing general guidance and Figma sections.

UI: a collapsible Plan My Activity card near the top of Tips, preserving the
existing featured card and filters. Controls wrap at narrow widths and large text.
A saved routine is optional, editable and removable. A previous assessment is only
compared for the same city/activity/start/duration; no false change notice for a
new plan. Feedback remains local, with optional reason chips and a clear action.
