## Temporary metadata bridge for the preserved local trajectory-predictor diff.
## Gameplay/world code uses PlayBoundsSpec directly; this class owns no bounds
## or geometry and can be removed after that unrelated file is reconciled.
class_name ContainmentSpec
extends RefCounted

const CONTACT_OWNER_META := PlayBoundsSpec.CONTACT_OWNER_META
const CONTACT_SHAPE_META := PlayBoundsSpec.CONTACT_SHAPE_META
