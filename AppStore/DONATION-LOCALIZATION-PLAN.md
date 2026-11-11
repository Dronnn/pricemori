# Proposed donation localization update

Prepared metadata: [iap-localizations.json](iap-localizations.json), 18 supported App Store locales for each of six existing consumable tips.

The current six metadata versions contain only English. They are locked because the six donation items are already attached to the older unresolved review draft as READY_FOR_REVIEW. Apple rejected both editing those versions and creating a second in-flight version.

Proposed operation, one donation at a time:
1. Read and save its current version, localized metadata, image IDs and draft review link.
2. Detach only that unsubmitted donation item from the draft. Do not cancel the submission or touch the rejected app item or other five tips.
3. Confirm its version is editable, save and re-read the prepared translations.
4. Reattach that same metadata version to the same review draft, including when a translation step fails. Confirm READY_FOR_REVIEW, original image IDs and unchanged parent submission state.
5. Proceed to the next tip only after restoration is confirmed.

No product deletion, product-ID change, price or availability change, purchase transaction, review submission or cancellation. Existing metadata and images remain on the product. A failed network request during reattachment could require retrying the saved draft-link creation; this is the remaining risk.

Automatic approval review rejected an earlier script because it detached all six items without including restoration. That script was not executed. This narrower operation requires explicit user approval before execution.
