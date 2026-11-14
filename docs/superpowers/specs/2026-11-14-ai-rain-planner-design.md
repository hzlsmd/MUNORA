# AI rain context for activity planning

The user approved rain outlook plus activity advice, with clearer context and
unavailable states, before adding AI-triggered notifications. Keep the existing
bundled logistic model, experimental label, trained weights and three-hour target.

Use a shared, typed outlook evaluator and async widget builder for Home/Tips and
the activity planner. Both use the same memoized model asset and fresh live weather;
there are no additional provider calls, telemetry, model training or dependencies.
Explain saved-only weather, stale/future observations, unsupported source/inputs,
and unavailable model separately. Display the selected city and observation time.

After checking a plan, show supplementary AI rain context only when the entire
future plan is inside the current observation-anchored three-hour outlook. Clearly
label the probability as covering the full outlook, not the selected subinterval.
At >=60%, give activity-specific preparedness advice. At lower probabilities,
ask the user to keep checking the forecast without implying an all-clear. Outside
or partly outside the window, explain the coverage limit and use hourly forecasts.
Retain forecast-derived storm/heat/wind precautions and planner severity unchanged.

Approach: reuse one evaluator/builder rather than duplicating model validation in
two widgets or running the model on hypothetical future weather. The model does
not support future-start rolling inference, precise rain onset or flood forecasts.
No notification behavior changes. Live accuracy still needs prospective validation.
