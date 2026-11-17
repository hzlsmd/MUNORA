# Ask MUNORA computed summaries

Implement the user-selected backend calculation improvement. From the existing validated next 36 hourly readings, calculate today and tomorrow in PHT separately. Supply a bounded coverage fact and separate maximum rain probability, temperature, and feels-like facts for each date. Use raw values to select maxima; display the existing rounded units and both time formats. For ties select the earliest matching hour and label that choice explicitly. No remaining hours means an explicit unavailable coverage fact and no invented maxima. Describe coverage as available upcoming hours, never a whole-day forecast.

## Approaches
The selected approach adds computed facts before AI generation; it preserves conversational answers and existing citation rendering. Letting AI compare raw hours caused the observed peak mistake. Replacing conversation with fixed templates is outside this request.

## Constraints
Keep the 36-hour validated source, existing six-citation and 180-character fact limits, request schema, quotas, APIs, AI model and UI. No new dependencies, automatic retries, or paid services. Prompt must prefer computed facts for daily maxima, and distinguish temperature from feels-like temperature. This improves grounding, but does not implement semantic enforcement of all AI claims.
