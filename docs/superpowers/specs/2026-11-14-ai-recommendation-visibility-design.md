# Discoverable rain recommendations

The user approved clearer recommendation visibility and separation of AI versus
forecast guidance. Keep the existing model, coverage limits and warning policies.

Show a concise preparedness summary beside the AI prediction on Home/Tips, clearly
labelled experimental. A Plan an activity button opens Tips, expands the planner
and scrolls to it; the same button on Tips opens the existing planner without
resetting activity selections. Label the planner supplement AI rain recommendation.
Label the non-AI activity assessment and ensemble comparison as forecast guidance
and forecast model agreement. Preparedness advice remains explicitly rule-derived
from the AI estimate, with no plan-specific or future rolling probability claim.

For unavailable weather inputs, expose the existing WeatherView refresh action
beside the explanation, preserving force-refresh and loading behavior. Model-only
loading failures retain their explanation rather than suggesting weather refresh
will replace a model. No notification, provider, model-weight or training changes.

Use existing screen callbacks, a widget-owned expansion controller and a keyed
planner state rather than a new navigation framework or resetting the planner on
every shortcut click. Keep selected-city reset behavior and async navigation safe.
